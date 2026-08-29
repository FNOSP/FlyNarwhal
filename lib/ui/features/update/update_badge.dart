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
class UpdateBadge extends StatefulWidget {
  const UpdateBadge({
    super.key,
    required this.version,
    required this.onPressed,
  });

  final String version;
  final VoidCallback onPressed;

  @override
  State<UpdateBadge> createState() => _UpdateBadgeState();
}

class _UpdateBadgeState extends State<UpdateBadge> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = FluentTheme.of(context).accentColor;
    final semanticLabel = '发现新版本 ${widget.version}，打开更新详情';

    // Match the 20px compact caption buttons (back / pin / refresh) in the
    // macOS title bar: same size, same circular hover background, same
    // vertical axis, so the badge reads as one of the row.
    const double buttonSize = 20.0;
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final hoverBackground = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isHovered ? hoverBackground : Colors.transparent,
                // Radius 14 exceeds half the 20px box, yielding a full circle
                // like the neighbouring caption buttons.
                borderRadius: BorderRadius.circular(14),
              ),
              child: SvgPicture.asset(
                'assets/images/version_update.svg',
                key: const ValueKey('update-badge-icon'),
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
