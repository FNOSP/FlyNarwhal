import 'package:fluent_ui/fluent_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../../../data/models/login_history.dart';

class HistorySidebar extends StatelessWidget {
  static const Color _textPrimary = Color(0xFFE6E8EC);
  static const Color _textSecondary = Color(0xFF9BA0A6);

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
    return GlassContainer(
      width: 300,
      shape: const LiquidRoundedSuperellipse(borderRadius: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header row
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
                              title: Text(
                                history.username,
                                style: const TextStyle(color: _textPrimary),
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
