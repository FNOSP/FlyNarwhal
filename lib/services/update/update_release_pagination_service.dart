import '../../core/utils/log/app_talker.dart';
import '../../core/version/semantic_version.dart';
import '../../core/version/version_parser.dart';
import '../../domain/update/entities/update_models.dart';
import '../../domain/update/repositories/cancellation_token.dart';
import '../../domain/update/repositories/update_repository.dart';
import '../../domain/update/repositories/update_repository_error.dart';

/// Traverses date-descending release pages until the current version is reached.
final class UpdateReleasePaginationService {
  const UpdateReleasePaginationService({
    this.pageSize = 10,
    this.maximumPages = 20,
  });

  final int pageSize;
  final int maximumPages;

  Future<List<UpdateRelease>> fetchAll({
    required UpdateRepository repository,
    required SemanticVersion currentVersion,
    required CancellationToken cancellationToken,
  }) async {
    final releases = <UpdateRelease>[];
    AppTalker.info(
      'UpdateCheck',
      'Starting GitHub release pagination: currentVersion=${currentVersion.skipKey}, pageSize=$pageSize.',
    );

    for (var pageNumber = 1; pageNumber <= maximumPages; pageNumber++) {
      cancellationToken.throwIfCancelled();
      AppTalker.info(
        'UpdateCheck',
        'Fetching GitHub release page $pageNumber.',
      );
      final page = await repository.fetchReleasePage(
        page: pageNumber,
        pageSize: pageSize,
        cancellationToken: cancellationToken,
      );
      final dateDescendingReleases = page.releases.toList(growable: false)
        ..sort(_compareByPublishedDateDescending);
      final firstCurrentOrOlderIndex =
          _findFirstCurrentOrOlderIndex(dateDescendingReleases, currentVersion);
      final relevantReleases = firstCurrentOrOlderIndex == null
          ? dateDescendingReleases
          : dateDescendingReleases.take(firstCurrentOrOlderIndex);
      releases.addAll(relevantReleases);

      AppTalker.info(
        'UpdateCheck',
        'Fetched GitHub release page $pageNumber: received=${page.releases.length}, relevant=${relevantReleases.length}, totalRelevant=${releases.length}.',
      );

      if (firstCurrentOrOlderIndex != null) {
        final boundaryRelease = dateDescendingReleases[firstCurrentOrOlderIndex];
        AppTalker.info(
          'UpdateCheck',
          'Stopping release pagination at ${boundaryRelease.tagName} because it is not newer than ${currentVersion.skipKey}.',
        );
        return List<UpdateRelease>.unmodifiable(releases);
      }

      final reachedNaturalEnd = page.releases.isEmpty ||
          page.releases.length < pageSize ||
          !page.hasNextPage;
      if (reachedNaturalEnd) {
        AppTalker.info(
          'UpdateCheck',
          'GitHub release pagination reached the final page.',
        );
        return List<UpdateRelease>.unmodifiable(releases);
      }
    }

    AppTalker.warning(
      'UpdateCheck',
      'GitHub release pagination exceeded the safety limit of $maximumPages pages.',
    );
    throw const UpdateRepositoryException(
      code: UpdateRepositoryErrorCode.releasePaginationLimitExceeded,
      technicalDetails:
          'GitHub release pagination remained open after the maximum pages.',
      retryable: false,
    );
  }

  static int? _findFirstCurrentOrOlderIndex(
    List<UpdateRelease> releases,
    SemanticVersion currentVersion,
  ) {
    for (var releaseIndex = 0;
        releaseIndex < releases.length;
        releaseIndex++) {
      final release = releases[releaseIndex];
      final version = VersionParser.parseReleaseVersion(
        tagName: release.tagName,
        displayName: release.displayName,
      );
      if (version != null && version.compareTo(currentVersion) <= 0) {
        return releaseIndex;
      }
    }
    return null;
  }

  static int _compareByPublishedDateDescending(
    UpdateRelease left,
    UpdateRelease right,
  ) {
    final leftPublishedAt = left.publishedAt;
    final rightPublishedAt = right.publishedAt;
    if (leftPublishedAt == null && rightPublishedAt == null) return 0;
    if (leftPublishedAt == null) return 1;
    if (rightPublishedAt == null) return -1;
    return rightPublishedAt.compareTo(leftPublishedAt);
  }
}
