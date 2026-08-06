import 'package:fluent_ui/fluent_ui.dart';

// Colors sampled from the supplied reference dialogs.
const appDialogPrimaryColor = Color(0xFF0A6CFF);
const appDialogDangerColor = Color(0xFFE9362D);
const appDialogSecondaryBorderColor = Color(0xFF3A3A3C);
const appDialogSurfaceColor = Color(0xFF202022);
const appDialogTextColor = Color(0xFFF2F2F7);

enum AppDialogType { information, confirmation, danger, custom }

class AppDialog<T> extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.type = AppDialogType.information,
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
      maxWidth: 640,
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
    final actions = <Widget>[
      if (_visible(secondaryButtonText))
        _secondary(context, secondaryButtonText!, onSecondaryPressed,
            secondaryResult, 'secondary'),
      if (_visible(tertiaryButtonText))
        _secondary(context, tertiaryButtonText!, onTertiaryPressed,
            tertiaryResult, 'tertiary'),
      if (_visible(primaryButtonText))
        _primary(context, primaryButtonText!, onPrimaryPressed, primaryResult),
    ];

    return ContentDialog(
      constraints: constraints,
      style: ContentDialogThemeData(
        decoration: BoxDecoration(
          color: appDialogSurfaceColor,
          border: Border.all(color: appDialogSecondaryBorderColor),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66000000), blurRadius: 24, spreadRadius: 2),
          ],
        ),
        barrierColor: const Color(0xB3000000),
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        titlePadding: const EdgeInsets.only(bottom: 18),
        bodyPadding: EdgeInsets.zero,
        actionsSpacing: 10,
        actionsDecoration: const BoxDecoration(color: Colors.transparent),
        actionsPadding: const EdgeInsets.only(top: 28),
        titleStyle: FluentTheme.of(context).typography.title?.copyWith(
              color: appDialogTextColor,
              fontWeight: FontWeight.w600,
            ),
        bodyStyle: FluentTheme.of(context).typography.body?.copyWith(
              color: appDialogTextColor,
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
        style: const TextStyle(color: appDialogTextColor),
        child: content,
      ),
      actions: actions.isEmpty
          ? null
          : [
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: actions,
                ),
              ),
            ],
    );
  }

  Widget _primary(
    BuildContext context,
    String text,
    VoidCallback? callback,
    T? result,
  ) {
    final color = type == AppDialogType.danger
        ? appDialogDangerColor
        : appDialogPrimaryColor;
    return FilledButton(
      key: const ValueKey('app-dialog-primary'),
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(color),
        foregroundColor: const WidgetStatePropertyAll(appDialogTextColor),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        ),
      ),
      onPressed: () => _invoke(context, callback, result),
      child: Text(text),
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
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: const WidgetStatePropertyAll(appDialogTextColor),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: appDialogSecondaryBorderColor),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        ),
      ),
      onPressed: () => _invoke(context, callback, result),
      child: Text(text),
    );
  }

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
  AppDialogType type = AppDialogType.information,
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
    maxWidth: 640,
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
