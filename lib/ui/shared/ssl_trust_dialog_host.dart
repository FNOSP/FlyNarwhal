import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/ssl/ssl_trust_manager.dart';
import 'dialogs/app_dialog.dart';

/// Shows the certificate-trust prompt whenever a request fails verification.
///
/// Mounted once near the app root, beside `ToastHost`. It observes
/// [SslTrustManager.pendingPrompt] rather than being called from the failing
/// request, because the failure happens inside an interceptor with no
/// `BuildContext`.
///
/// `FluentApp.builder` wraps its `child` *above* the Navigator, so a widget
/// placed there has no Navigator ancestor and cannot push a dialog. This host
/// therefore owns a [Navigator] of its own and renders the prompt as a route
/// inside it, which works from any screen including the login page.
class SslTrustDialogHost extends ConsumerStatefulWidget {
  const SslTrustDialogHost({super.key});

  @override
  ConsumerState<SslTrustDialogHost> createState() => _SslTrustDialogHostState();
}

class _SslTrustDialogHostState extends ConsumerState<SslTrustDialogHost> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Guards against pushing a second prompt while one is still open, which
  /// would happen if a prompt for another host arrived mid-answer.
  bool _showing = false;

  /// Whether a prompt is currently pending. While false the host renders
  /// nothing at all, so it cannot intercept pointer events destined for the
  /// app underneath.
  bool _active = false;

  @override
  void initState() {
    super.initState();
    SslTrustManager.instance.pendingPrompt.addListener(_onPromptChanged);
    _onPromptChanged();
  }

  @override
  void dispose() {
    SslTrustManager.instance.pendingPrompt.removeListener(_onPromptChanged);
    super.dispose();
  }

  void _onPromptChanged() {
    final prompt = SslTrustManager.instance.pendingPrompt.value;
    if (prompt == null || _showing) return;
    // Adopt the prompt and build the Navigator, then push on the next frame so
    // the navigator exists by the time it is used.
    setState(() => _active = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showPrompt(prompt));
    });
  }

  Future<void> _showPrompt(SslTrustPrompt prompt) async {
    if (!mounted || _showing) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      // The Navigator should exist by now; if it does not, do not leave the
      // request waiting on a prompt that will never appear.
      SslTrustManager.instance.resolvePrompt(SslTrustDecision.reject);
      return;
    }

    _showing = true;
    try {
      final decision = await navigator.push<SslTrustDecision>(
        FluentDialogRoute<SslTrustDecision>(
          builder: (dialogContext) => AppDialog<SslTrustDecision>(
            title: '证书校验失败',
            type: AppDialogType.danger,
            // Three actions, one of them a long label, need more room than the
            // default 460px before the action row overflows.
            constraints: const BoxConstraints(
              minWidth: 420,
              maxWidth: 560,
              maxHeight: 720,
            ),
            content: Column(
              key: const ValueKey('ssl-trust-dialog'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '「${prompt.host}」的证书校验不通过，可能是证书过期、域名不匹配或自签名证书。'
                  '继续访问将绕过安全保护，是否继续访问？',
                ),
                const SizedBox(height: 12),
                Text(
                  '证书指纹 SHA-256：${shortFingerprint(prompt.fingerprintSha256)}',
                  key: const ValueKey('ssl-trust-dialog-fingerprint'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            tertiaryButtonText: '信任此证书',
            primaryButtonText: '仅本次信任',
            secondaryButtonText: '取消访问',
            tertiaryResult: SslTrustDecision.allowPersist,
            primaryResult: SslTrustDecision.allowTemporary,
            secondaryResult: SslTrustDecision.reject,
            autoDismiss: true,
          ),
          barrierDismissible: false,
        ),
      );

      // A dialog dismissed without an answer counts as a refusal rather than
      // leaving the request hanging forever.
      SslTrustManager.instance.resolvePrompt(
        decision ?? SslTrustDecision.reject,
      );
    } finally {
      _showing = false;
      if (mounted) setState(() => _active = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Render nothing unless a prompt is pending. A Navigator laid out inside
    // `Stack(fit: StackFit.expand)` fills the window and its Overlay is
    // hit-test opaque, so keeping one mounted would swallow every click meant
    // for the app underneath.
    if (!_active) return const SizedBox.shrink();

    return HeroControllerScope.none(
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// A dialog route matching the behaviour [showAppDialog] gives when it is
/// handed a context that already has a Navigator.
class FluentDialogRoute<T> extends PageRouteBuilder<T> {
  FluentDialogRoute({
    required WidgetBuilder builder,
    super.barrierDismissible = true,
  }) : super(
          opaque: false,
          barrierColor: appDialogBarrierColor,
          barrierLabel: 'Dismiss',
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 150),
          reverseTransitionDuration: const Duration(milliseconds: 100),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
}
