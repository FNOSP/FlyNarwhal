import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/quark_cdn_proxy/cdn_http_range_source.dart';
import '../core/network/quark_cdn_proxy/cdn_proxy.dart';
import '../core/network/quark_cdn_proxy/cdn_proxy_service.dart';
import '../core/network/quark_cdn_proxy/cdn_range_diagnostics.dart';
import '../core/utils/log/app_talker.dart';

typedef CdnRangeSourceFactory = CdnRangeSource Function();
typedef QuarkCdnRangeServiceFactory = CdnProxy Function({
  void Function(Object)? onError,
});

/// Creates a dedicated external client for each playback source.
final cdnRangeSourceFactoryProvider = Provider<CdnRangeSourceFactory>(
  (ref) => () => CdnHttpRangeSource(),
);

/// The caller owns each service and closes it before replacing the source.
final quarkCdnRangeServiceFactoryProvider =
    Provider<QuarkCdnRangeServiceFactory>((ref) {
  final createSource = ref.watch(cdnRangeSourceFactoryProvider);
  // Omit a local budget so all playback sources retain the shared quota.
  return ({onError}) => CdnProxyService(
        source: createSource(),
        onError: onError,
        diagnostics: cdnRangeDiagnosticsEnabled
            ? CdnRangeDiagnostics(writeLog: _writeDiagnosticLog)
            : null,
      );
});

void _writeDiagnosticLog(String message, {required bool failure}) {
  if (failure) {
    AppTalker.error('CdnDiagnostic',
        error: const CdnRangeFailure('CDN session failed'), message: message);
  } else {
    AppTalker.info('CdnDiagnostic', message);
  }
}
