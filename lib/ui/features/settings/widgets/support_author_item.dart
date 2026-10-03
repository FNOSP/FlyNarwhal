import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/dialogs/app_dialog.dart';
import 'card_expander_item.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';

const _projectUrl = 'https://github.com/FNOSP/FlyNarwhal';

class SupportAuthorItem extends StatelessWidget {
  const SupportAuthorItem({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CardExpanderItem(
      key: const ValueKey('settings-support-author'),
      icon: Builder(
        builder: (context) {
          final iconColor = IconTheme.of(context).color;
          return SvgPicture.asset(
            'assets/images/github_logo.svg',
            width: 16,
            height: 16,
            colorFilter: iconColor == null
                ? null
                : ColorFilter.mode(iconColor, BlendMode.srcIn),
          );
        },
      ),
      heading: const Text('FlyNarwhal'),
      caption: const Text(_projectUrl),
      trailing: AppButton(
        key: const ValueKey('settings-support-author-button'),
        onPressed: () => _showSupportAuthorDialog(context),
        child: Text(l10n.supportAuthorTitle),
      ),
    );
  }
}

void _showSupportAuthorDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showAppDialog<void>(
    context: context,
    title: l10n.supportAuthorTitle,
    content: Text(
      '${l10n.supportAuthorBody}\n\n${l10n.supportAuthorIssues}',
    ),
    secondaryButtonText: l10n.supportAuthorLater,
    primaryButtonText: l10n.supportAuthorOpenRepo,
    onPrimaryPressed: () {
      // showDialog 默认挂在根 Navigator 上,必须从根 Navigator 弹出,
      // 否则会误弹 GoRouter 内部 Navigator 上的设置页路由。
      Navigator.of(context, rootNavigator: true).pop();
      launchUrl(Uri.parse(_projectUrl), mode: LaunchMode.externalApplication);
    },
  );
}
