import '../../core/version/semantic_version.dart';
import '../../core/version/version_parser.dart';
import '../../domain/update/entities/update_models.dart';
import '../../domain/update/repositories/cancellation_token.dart';
import '../../domain/update/repositories/update_repository.dart';
import 'update_release_pagination_service.dart';

/// Collects optional release notes without participating in candidate choice.
final class UpdateReleaseLogCollectionService {
  const UpdateReleaseLogCollectionService({
    this.paginationService = const UpdateReleasePaginationService(),
  });

  final UpdateReleasePaginationService paginationService;

  Future<List<UpdateReleaseNotesFragment>> collect({
    required UpdateRepository repository,
    required SemanticVersion currentVersion,
    required UpdateCandidate candidate,
    required bool includePrerelease,
    required CancellationToken cancellationToken,
  }) async {
    final releases = await paginationService.fetchAll(
      repository: repository,
      cancellationToken: cancellationToken,
    );
    final fragments = <UpdateReleaseNotesFragment>[];
    for (final release in releases) {
      if (release.isDraft || (!includePrerelease && release.isPrerelease)) {
        continue;
      }
      final version = VersionParser.parseReleaseVersion(
        tagName: release.tagName,
        displayName: release.displayName,
      );
      if (version == null) {
        continue;
      }
      final isAfterCurrentVersion = version.compareTo(currentVersion) > 0;
      final isAtOrBeforeTarget = version.compareTo(candidate.version) <= 0;
      if (!isAfterCurrentVersion || !isAtOrBeforeTarget) {
        continue;
      }
      fragments.add(
        UpdateReleaseNotesFragment(
          version: version,
          markdown: release.releaseNotes,
          releasePageUrl: release.htmlUrl,
          isTargetVersion: version.compareTo(candidate.version) == 0,
        ),
      );
    }
    fragments.sort((left, right) => right.version.compareTo(left.version));
    return List<UpdateReleaseNotesFragment>.unmodifiable(fragments);
  }
}
