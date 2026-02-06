import 'package:fluent_ui/fluent_ui.dart';
import '../../data/models/home_models.dart';

class MediaLibCardRow extends StatelessWidget {
  final List<MediaDbListResponse> items;
  final ValueChanged<MediaDbListResponse> onItemClick;

  const MediaLibCardRow({
    super.key,
    required this.items,
    required this.onItemClick,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Text("媒体库", style: FluentTheme.of(context).typography.subtitle),
        ),
        SizedBox(
          height: 100, // Adjust height
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              return HoverButton(
                onPressed: () => onItemClick(item),
                builder: (context, states) {
                  return Container(
                    width: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: states.contains(WidgetState.hovered)
                          ? FluentTheme.of(context).cardColor.withValues(alpha: 0.8) 
                          : FluentTheme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(FluentIcons.library), // Replace with poster if available
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item.title,
                            style: FluentTheme.of(context).typography.bodyStrong,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
