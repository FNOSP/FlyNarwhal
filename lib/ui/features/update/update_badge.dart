import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../providers/update_providers.dart';
import 'update_dialog.dart';
import 'update_state.dart';

final updateBadgeStateProvider = Provider<UpdateState>((ref) {
  return ref.watch(updateControllerProvider);
});

class SharedUpdateBadge extends ConsumerWidget {
  const SharedUpdateBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateBadgeStateProvider);
    final candidate = updateState.candidate;
    if (!updateState.hasUpdateBadge || candidate == null) {
      return const SizedBox.shrink(key: ValueKey('update-badge-hidden'));
    }
    return UpdateBadge(
      version: candidate.version.toString(),
      onPressed: () => showUpdateDialog(context),
    );
  }
}

/// Compact, keyboard-accessible update entry point shared by desktop surfaces.
class UpdateBadge extends StatelessWidget {
  const UpdateBadge({
    super.key,
    required this.version,
    required this.onPressed,
  });

  final String version;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accentColor = FluentTheme.of(context).accentColor;
    final semanticLabel = '发现新版本 $version，打开更新详情';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: IconButton(
          key: const ValueKey('update-badge'),
          autofocus: false,
          icon: SvgPicture.asset(
            'assets/images/update.svg',
            key: const ValueKey('update-badge-icon'),
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
