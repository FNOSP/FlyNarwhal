import '../../domain/update/entities/update_models.dart';
import '../../domain/update/repositories/cancellation_token.dart';
import '../../domain/update/repositories/update_repository.dart';
import '../../domain/update/repositories/update_repository_error.dart';

/// Traverses release pages with explicit termination and safety bounds.
final class UpdateReleasePaginationService {
  const UpdateReleasePaginationService({
    this.pageSize = 20,
    this.maximumPages = 10,
  });

  final int pageSize;
  final int maximumPages;

  Future<List<UpdateRelease>> fetchAll({
    required UpdateRepository repository,
    required CancellationToken cancellationToken,
  }) async {
    final releases = <UpdateRelease>[];
    for (var pageNumber = 1; pageNumber <= maximumPages; pageNumber++) {
      cancellationToken.throwIfCancelled();
      final page = await repository.fetchReleasePage(
        page: pageNumber,
        pageSize: pageSize,
        cancellationToken: cancellationToken,
      );
      releases.addAll(page.releases);

      final reachedNaturalEnd = page.releases.isEmpty ||
          page.releases.length < pageSize ||
          !page.hasNextPage;
      if (reachedNaturalEnd) {
        return List<UpdateRelease>.unmodifiable(releases);
      }
    }

    throw const UpdateRepositoryException(
      code: UpdateRepositoryErrorCode.releasePaginationLimitExceeded,
      technicalDetails:
          'GitHub release pagination remained open after the maximum pages.',
      retryable: false,
    );
  }
}
