import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../core/utils/log/app_talker.dart';
import '../../providers/providers.dart';
import 'dialogs/app_dialog.dart';
import 'celebration_overlay.dart';

const String flyNarwhalProjectUrl = 'https://github.com/FNOSP/FlyNarwhal';

/// Shows the "支持作者" dialog: project star invite, donation QR code and an
/// "我已赞赏" action. When the user confirms a donation the dialog closes and
/// the window-wide confetti + "谢谢老板" celebration plays.
///
/// [context] must be below the root navigator (dialogs are mounted there so
/// they cover fullscreen player routes too).
Future<void> showSupportAuthorDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final container = ProviderScope.containerOf(context);
  await showAppDialog<void>(
    context: context,
    // Wide enough for the side-by-side QR and mascot images (260px each plus
    // the 16px gap) and for the English copy and three action buttons to fit
    // on one row without clipping.
    constraints: const BoxConstraints(
      minWidth: 640,
      maxWidth: 720,
      maxHeight: 760,
    ),
    title: l10n.supportAuthorTitle,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${l10n.supportAuthorBody}\n\n${l10n.supportAuthorIssues}'),
        const SizedBox(height: 14),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/donate_qr.jpg',
                  width: 260,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                // Same footprint as the QR, but the landscape mascot keeps
                // its full composition instead of being centre-cropped.
                width: 260,
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/donate_mascot.gif',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    tertiaryButtonText: l10n.supportAuthorLater,
    onTertiaryPressed: () => _closeFromRoot(context),
    secondaryButtonText: l10n.supportAuthorOpenRepo,
    onSecondaryPressed: () {
      _closeFromRoot(context);
      launchUrl(
        Uri.parse(flyNarwhalProjectUrl),
        mode: LaunchMode.externalApplication,
      );
    },
    primaryButtonText: l10n.supportAuthorDonated,
    onPrimaryPressed: () {
      final userGuid = container.read(currentUserGuidProvider);
      // Permanent opt-out: once the user says they donated, the prompt never
      // auto-shows again.
      unawaited(
        container
            .read(preferencesManagerProvider)
            .markDonationSupportDonated(userGuid: userGuid),
      );
      container
          .read(celebrationTriggerProvider.notifier)
          .update((value) => value + 1);
      AppTalker.info('SupportAuthor', 'user confirmed donation, celebration on');
      _closeFromRoot(context);
    },
  );
}

// showDialog 默认挂在根 Navigator 上,必须从根 Navigator 弹出,
// 否则会误弹 GoRouter 内部 Navigator 上的设置页路由。
void _closeFromRoot(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}
