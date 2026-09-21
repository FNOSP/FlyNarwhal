import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/cdn_proxy/cdn_http_transport.dart';
import '../core/network/cdn_proxy/cdn_proxy.dart';
import '../core/network/cdn_proxy/cdn_proxy_service.dart';
import '../data/datasources/remote/cdn_range_remote_data_source.dart';

typedef CdnRangeSourceFactory = CdnRangeSource Function();
typedef QuarkCdnRangeServiceFactory = CdnProxy Function({
  void Function(Object)? onError,
});

/// Creates a dedicated external client for each playback source.
final cdnRangeRemoteDataSourceFactoryProvider = Provider<CdnRangeSourceFactory>(
  (ref) => () => CdnRangeRemoteDataSource(transport: CdnHttpTransport()),
);

/// The caller owns each service and closes it before replacing the source.
final quarkCdnRangeServiceFactoryProvider =
    Provider<QuarkCdnRangeServiceFactory>((ref) {
  final createSource = ref.watch(cdnRangeRemoteDataSourceFactoryProvider);
  // Omit a local budget so all playback sources retain the shared quota.
  return ({onError}) => CdnProxyService(
        source: createSource(),
        onError: onError,
      );
});
