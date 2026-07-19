import '../../domain/update/entities/update_models.dart';
import '../../domain/update/repositories/cancellation_token.dart';
import '../../domain/update/repositories/update_repository.dart';
import '../../domain/update/repositories/update_repository_error.dart';
import '../datasources/remote/github_release_data_source.dart';

/// Repository implementation backed by the GitHub Releases API.
final class UpdateRepositoryImpl implements UpdateRepository {
  const UpdateRepositoryImpl(this._dataSource);

  final GitHubReleaseDataSourceContract _dataSource;

  @override
  Future<UpdateReleasePage> fetchReleasePage({
    required int page,
    required int pageSize,
    required CancellationToken cancellationToken,
  }) async {
    try {
      final releases = await _dataSource.fetchReleases(
        page: page,
        pageSize: pageSize,
        cancellationToken: cancellationToken,
      );
      return UpdateReleasePage(
        releases: releases,
        page: page,
        hasNextPage: releases.length >= pageSize,
      );
    } on UpdateRepositoryException {
      rethrow;
    } on UpdateOperationCancelledException {
      throw const UpdateRepositoryException(
        code: UpdateRepositoryErrorCode.cancelled,
        technicalDetails: 'Release page request was cancelled.',
        retryable: false,
      );
    } catch (error) {
      throw UpdateRepositoryException(
        code: UpdateRepositoryErrorCode.domainMapping,
        technicalDetails: 'Unexpected release mapping failure: $error',
        retryable: false,
      );
    }
  }

  @override
  Future<List<UpdateRelease>> fetchReleases({
    required int page,
    required int pageSize,
  }) async {
    final result = await fetchReleasePage(
      page: page,
      pageSize: pageSize,
      cancellationToken: const NonCancellableToken(),
    );
    return result.releases;
  }
}
