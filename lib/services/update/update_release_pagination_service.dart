import '../../core/utils/log/app_talker.dart';
import '../../core/version/semantic_version.dart';
import '../../domain/update/entities/update_models.dart';
import '../../domain/update/repositories/cancellation_token.dart';
import '../../domain/update/repositories/update_repository.dart';
import '../../domain/update/repositories/update_repository_error.dart';

/// Traverses release pages until the natural end of the release list.
///
/// Publication dates are not guaranteed to follow version order (an older
/// version can be republished after a newer one), so every release is
/// collected and version filtering is left to the update policy.
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
      releases.addAll(page.releases);

      AppTalker.info(
        'UpdateCheck',
        'Fetched GitHub release page $pageNumber: received=${page.releases.length}, total=${releases.length}.',
      );

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
}
