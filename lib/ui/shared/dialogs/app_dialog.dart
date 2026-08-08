import 'package:fluent_ui/fluent_ui.dart';

// Colors sampled from the reference web app (飞牛影视, Semi Design dark theme).
// Modal chrome
const appDialogSurfaceColor = Color(0xFF202021);
const appDialogBarrierColor = Color(0xB3101011);
const appDialogTextColor = Color(0xFFFFFFFF);
const appDialogBodyTextColor = Color(0xFFFFFFFF);

// Secondary/cancel (ghost, tertiary-outline) — identical across dialog types.
const appDialogSecondaryTextColor = Color(0xCCFFFFFF);
const appDialogSecondaryBorderColor = Color(0x1AFFFFFF);
const appDialogSecondaryHoverColor = Color(0x0AFFFFFF);
const appDialogSecondaryPressedColor = Color(0x17FFFFFF);

// Primary — normal/confirmation dialogs (blue).
const appDialogPrimaryColor = Color(0xFF0066FF);
const appDialogPrimaryHoverColor = Color(0xFF3388FF);
const appDialogPrimaryPressedColor = Color(0xFF0054DB);

// Danger dialogs (red).
const appDialogDangerColor = Color(0xFFDB382C);
const appDialogDangerHoverColor = Color(0xFFE56C5E);
const appDialogDangerPressedColor = Color(0xFFBA312C);

enum AppDialogType { confirmation, danger }

class AppDialog<T> extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.type = AppDialogType.confirmation,
    this.primaryButtonText,
    this.secondaryButtonText,
    this.tertiaryButtonText,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
    this.onTertiaryPressed,
    this.primaryResult,
    this.secondaryResult,
    this.tertiaryResult,
    this.constraints = const BoxConstraints(
      minWidth: 420,
      maxWidth: 460,
      maxHeight: 720,
    ),
    this.titleIcon,
  });

  final String title;
  final Widget content;
  final AppDialogType type;
  final String? primaryButtonText;
  final String? secondaryButtonText;
  final String? tertiaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final VoidCallback? onTertiaryPressed;
  final T? primaryResult;
  final T? secondaryResult;
  final T? tertiaryResult;
  final BoxConstraints constraints;
  final Widget? titleIcon;

  @override
  Widget build(BuildContext context) {
    // tertiary 通常为附加/破坏性操作(如「删除」),靠左;
    // secondary(取消)+ primary(确定)为常规确认操作,靠右。
    final tertiary = _visible(tertiaryButtonText)
        ? _secondary(context, tertiaryButtonText!, onTertiaryPressed,
            tertiaryResult, 'tertiary')
        : null;
    final secondary = _visible(secondaryButtonText)
        ? _secondary(context, secondaryButtonText!, onSecondaryPressed,
            secondaryResult, 'secondary')
        : null;
    final primary = _visible(primaryButtonText)
        ? _primary(context, primaryButtonText!, onPrimaryPressed, primaryResult)
        : null;

    final hasActions =
        tertiary != null || secondary != null || primary != null;

    return ContentDialog(
      constraints: constraints,
      style: ContentDialogThemeData(
        decoration: BoxDecoration(
          color: appDialogSurfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        barrierColor: appDialogBarrierColor,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        titlePadding: const EdgeInsets.only(bottom: 24),
        bodyPadding: EdgeInsets.zero,
        actionsSpacing: 12,
        actionsDecoration: const BoxDecoration(color: Colors.transparent),
        actionsPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        titleStyle: const TextStyle(
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w600,
          color: appDialogTextColor,
        ),
        bodyStyle: const TextStyle(
          fontSize: 14,
          height: 20 / 14,
          color: appDialogBodyTextColor,
        ),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (titleIcon != null) ...[titleIcon!, const SizedBox(width: 12)],
          Expanded(child: Text(title)),
        ],
      ),
      content: DefaultTextStyle.merge(
        style: const TextStyle(color: appDialogBodyTextColor),
        child: content,
      ),
      actions: hasActions
          ? [
              Row(
                children: [
                  if (tertiary != null) tertiary,
                  const Spacer(),
                  if (secondary != null) secondary,
                  if (secondary != null && primary != null)
                    const SizedBox(width: 12),
                  if (primary != null) primary,
                ],
              ),
            ]
          : null,
    );
  }

  Widget _primary(
    BuildContext context,
    String text,
    VoidCallback? callback,
    T? result,
  ) {
    final isDanger = type == AppDialogType.danger;
    final base = isDanger ? appDialogDangerColor : appDialogPrimaryColor;
    final hover =
        isDanger ? appDialogDangerHoverColor : appDialogPrimaryHoverColor;
    final pressed =
        isDanger ? appDialogDangerPressedColor : appDialogPrimaryPressedColor;

    return FilledButton(
      key: const ValueKey('app-dialog-primary'),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) return pressed;
          if (states.contains(WidgetState.hovered)) return hover;
          return base;
        }),
        foregroundColor: const WidgetStatePropertyAll(appDialogTextColor),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      onPressed: () => _invoke(context, callback, result),
      child: _label(text),
    );
  }

  Widget _secondary(
    BuildContext context,
    String text,
    VoidCallback? callback,
    T? result,
    String name,
  ) {
    return Button(
      key: ValueKey('app-dialog-$name'),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return appDialogSecondaryPressedColor;
          }
          if (states.contains(WidgetState.hovered)) {
            return appDialogSecondaryHoverColor;
          }
          return Colors.transparent;
        }),
        foregroundColor: const WidgetStatePropertyAll(
          appDialogSecondaryTextColor,
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: appDialogSecondaryBorderColor),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      onPressed: () => _invoke(context, callback, result),
      child: _label(text),
    );
  }

  Widget _label(String text) => ConstrainedBox(
        // Buttons are content-sized but never narrower than the reference
        // (88px total = 56px label + 16px padding each side).
        constraints: const BoxConstraints(minWidth: 56),
        child: SizedBox(
          height: 36,
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1.0,
            child: Text(text),
          ),
        ),
      );

  void _invoke(BuildContext context, VoidCallback? callback, T? result) {
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).pop(result);
    }
  }

  bool _visible(String? text) => text != null && text.trim().isNotEmpty;
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  AppDialogType type = AppDialogType.confirmation,
  String? primaryButtonText,
  String? secondaryButtonText,
  String? tertiaryButtonText,
  VoidCallback? onPrimaryPressed,
  VoidCallback? onSecondaryPressed,
  VoidCallback? onTertiaryPressed,
  T? primaryResult,
  T? secondaryResult,
  T? tertiaryResult,
  bool barrierDismissible = true,
  BoxConstraints constraints = const BoxConstraints(
    minWidth: 420,
    maxWidth: 460,
    maxHeight: 720,
  ),
  Widget? titleIcon,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => AppDialog<T>(
      title: title,
      content: content,
      type: type,
      primaryButtonText: primaryButtonText,
      secondaryButtonText: secondaryButtonText,
      tertiaryButtonText: tertiaryButtonText,
      onPrimaryPressed: onPrimaryPressed,
      onSecondaryPressed: onSecondaryPressed,
      onTertiaryPressed: onTertiaryPressed,
      primaryResult: primaryResult,
      secondaryResult: secondaryResult,
      tertiaryResult: tertiaryResult,
      constraints: constraints,
      titleIcon: titleIcon,
    ),
  );
}
