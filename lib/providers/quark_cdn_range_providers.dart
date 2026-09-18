import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../data/datasources/remote/cdn_range_remote_data_source.dart';
import '../ui/features/player/services/quark_cdn_range_service.dart';

typedef CdnRangeSourceFactory = CdnRangeSource Function();
typedef QuarkCdnRangeServiceFactory = QuarkCdnRangeService Function({
  void Function(Object)? onError,
});

/// Creates a dedicated external client for each playback source.
final cdnRangeRemoteDataSourceFactoryProvider = Provider<CdnRangeSourceFactory>(
  (ref) => () => CdnRangeRemoteDataSource(dioClient: DioClient.external()),
);

/// The caller owns each service and closes it before replacing the source.
final quarkCdnRangeServiceFactoryProvider =
    Provider<QuarkCdnRangeServiceFactory>((ref) {
  final createSource = ref.watch(cdnRangeRemoteDataSourceFactoryProvider);
  // Omit a local budget so all playback sources retain the shared quota.
  return ({onError}) => QuarkCdnRangeService(
        source: createSource(),
        onError: onError,
      );
});
