import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/dialogs/app_dialog.dart';
import 'card_expander_item.dart';

const _projectUrl = 'https://github.com/FNOSP/FlyNarwhal';

class SupportAuthorItem extends StatelessWidget {
  const SupportAuthorItem({super.key});

  @override
  Widget build(BuildContext context) {
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
      trailing: Button(
        key: const ValueKey('settings-support-author-button'),
        onPressed: () => _showSupportAuthorDialog(context),
        child: const Text('支持作者'),
      ),
    );
  }
}

void _showSupportAuthorDialog(BuildContext context) {
  showAppDialog<void>(
    context: context,
    title: '支持作者',
    content: const Text(
      '您的支持就是我持续更新的动力，如果觉得好用的话，请给项目点一个 Star ⭐，谢谢！(^_−)☆'
      '\n\n'
      '项目诚然还有很多地方需要完善，如果遇到软件问题或者 Bug 欢迎提交 Issue 或者 PR。',
    ),
    secondaryButtonText: '稍后再说',
    primaryButtonText: '打开 Github 仓库',
    onPrimaryPressed: () {
      // showDialog 默认挂在根 Navigator 上,必须从根 Navigator 弹出,
      // 否则会误弹 GoRouter 内部 Navigator 上的设置页路由。
      Navigator.of(context, rootNavigator: true).pop();
      launchUrl(Uri.parse(_projectUrl), mode: LaunchMode.externalApplication);
    },
  );
}
