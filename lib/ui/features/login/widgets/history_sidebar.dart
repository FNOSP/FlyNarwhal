import 'dart:io' show Platform;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../../../data/models/login_history.dart';

class HistorySidebar extends StatelessWidget {
  static const Color _textPrimary = Color(0xFFE6E8EC);
  static const Color _textSecondary = Color(0xFF9BA0A6);
  static const double _headerActionWidth = 40.0;
  static const Color _accentColor = Color(0xFF3A7BFF);

  final List<LoginHistory> historyList;
  final VoidCallback onDismiss;
  final ValueChanged<LoginHistory> onDelete;
  final ValueChanged<LoginHistory> onSelect;

  const HistorySidebar({
    super.key,
    required this.historyList,
    required this.onDismiss,
    required this.onDelete,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isMacOS = !kIsWeb && Platform.isMacOS;

    return GlassContainer(
      width: 300,
      shape: const LiquidRoundedSuperellipse(borderRadius: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header row
          if (isMacOS)
            Row(
              children: [
                const SizedBox(width: _headerActionWidth),
                const Expanded(
                  child: Center(
                    child: Text(
                      '登录历史',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 18),
                    onPressed: onDismiss,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '登录历史',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 18),
                    onPressed: onDismiss,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          // History list
          Expanded(
            child: historyList.isEmpty
                ? const Center(
                    child: Text(
                      '暂无历史记录',
                      style: TextStyle(color: _textSecondary, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: historyList.length,
                    itemBuilder: (context, index) {
                      final history = historyList[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GlassContainer(
                          shape: const LiquidRoundedSuperellipse(
                            borderRadius: 8,
                          ),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ListTile(
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      history.username,
                                      style: const TextStyle(color: _textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (history.isNasLogin) ...[
                                    const SizedBox(width: 8),
                                    const GlassContainer(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      shape: LiquidRoundedSuperellipse(
                                        borderRadius: 50,
                                      ),
                                      // Keep the badge label visually centered.
                                      child: SizedBox(
                                        height: 18,
                                        child: Center(
                                          child: Text(
                                            'NAS',
                                            textAlign: TextAlign.center,
                                            strutStyle: StrutStyle(
                                              fontSize: 11,
                                              height: 1,
                                              forceStrutHeight: true,
                                            ),
                                            style: TextStyle(
                                              color: _accentColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                history.getEndpoint(),
                                style: const TextStyle(color: _textSecondary),
                              ),
                              trailing: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: IconButton(
                                  icon: const Icon(
                                    FluentIcons.delete,
                                    size: 16,
                                  ),
                                  onPressed: () => onDelete(history),
                                ),
                              ),
                              onPressed: () => onSelect(history),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
