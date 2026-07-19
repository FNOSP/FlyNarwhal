import '../entities/update_models.dart';
import 'cancellation_token.dart';

/// One page returned by the update release repository.
final class UpdateReleasePage {
  const UpdateReleasePage({
    required this.releases,
    required this.page,
    required this.hasNextPage,
  });

  final List<UpdateRelease> releases;
  final int page;
  final bool hasNextPage;
}

/// Reads GitHub Releases without applying platform or version policy.
abstract interface class UpdateRepository {
  Future<UpdateReleasePage> fetchReleasePage({
    required int page,
    required int pageSize,
    required CancellationToken cancellationToken,
  });

  /// Compatibility bridge for callers migrated by the controller module.
  Future<List<UpdateRelease>> fetchReleases({
    required int page,
    required int pageSize,
  });
}
