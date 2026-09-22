import 'package:media_kit/media_kit.dart';

import '../../utils/log/app_talker.dart';
import 'ssl_trust_manager.dart';

/// Disables TLS verification on [player] when the media host has been approved.
///
/// The video bytes are fetched by libmpv over its own native HTTP stack, so the
/// Dio-level trust work does not reach it. mpv verifies certificates strictly by
/// default, which would leave a user who whitelisted their NAS still unable to
/// play.
///
/// mpv's `tls-verify` is an instance option, not a per-host one, and mpv does
/// not expose the peer certificate back to Dart — so unlike the Dio path this
/// cannot be pinned to a fingerprint. It only asserts "the user approved this
/// host at some point". Callers must set it before opening media.
///
/// Must be applied before `open`; whether it takes effect otherwise is
/// unspecified.
Future<void> applySslTrustToPlayer(Player player, Uri mediaUri) async {
  if (!mediaUri.isScheme('https')) return;

  final host = mediaUri.host;
  if (host.isEmpty) return;
  if (!SslTrustManager.instance.isHostApproved(host)) return;

  final platform = player.platform;
  if (platform is! NativePlayer) return;

  try {
    await platform.setProperty('tls-verify', 'no');
    AppTalker.info(
      'SslTrust',
      'disabled mpv tls-verify for trusted host=$host',
    );
  } catch (error) {
    AppTalker.warning(
      'SslTrust',
      'failed to disable mpv tls-verify for host=$host: $error',
    );
  }
}
