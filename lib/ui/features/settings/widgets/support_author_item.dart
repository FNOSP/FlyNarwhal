import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/support_author_dialog.dart';
import '../../../shared/app_button.dart';
import 'card_expander_item.dart';

class SupportAuthorItem extends ConsumerWidget {
  const SupportAuthorItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      caption: const Text(flyNarwhalProjectUrl),
      trailing: AppButton(
        key: const ValueKey('settings-support-author-button'),
        onPressed: () => unawaited(showSupportAuthorDialog(context)),
        child: Text(l10n.supportAuthorTitle),
      ),
    );
  }
}
