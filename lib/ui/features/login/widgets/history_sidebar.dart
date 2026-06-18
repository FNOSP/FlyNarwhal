import 'package:fluent_ui/fluent_ui.dart';
import '../../../../data/models/login_history.dart';

class HistorySidebar extends StatelessWidget {
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
    return Container(
      width: 300,
      color: const Color(0xFF1A1D26), // CardBackgroundColor
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    icon: const Icon(FluentIcons.double_chevron_left, size: 15),
                    onPressed: onDismiss,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: historyList.isEmpty
                ? const Center(child: Text("暂无历史记录"))
                : ListView.builder(
                    itemCount: historyList.length,
                    itemBuilder: (context, index) {
                      final history = historyList[index];
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ListTile(
                          title: Text(history.username),
                          subtitle: Text(history.getEndpoint()),
                          trailing: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              icon: const Icon(FluentIcons.delete, size: 16),
                              onPressed: () => onDelete(history),
                            ),
                          ),
                          onPressed: () => onSelect(history),
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
