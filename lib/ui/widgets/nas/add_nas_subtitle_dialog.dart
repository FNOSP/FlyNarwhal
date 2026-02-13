import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/file_models.dart';
import '../../../data/utils/fn_data_convertor.dart';
import '../../../providers/file_providers.dart';
import 'file_tree_picker.dart';

class AddNasSubtitleDialog extends ConsumerStatefulWidget {
  final String title;
  final String currentPath;
  final Function(List<String>) onConfirm;

  const AddNasSubtitleDialog({
    super.key,
    required this.title,
    required this.currentPath,
    required this.onConfirm,
  });

  @override
  ConsumerState<AddNasSubtitleDialog> createState() => _AddNasSubtitleDialogState();
}

class SidebarItem {
  final List<String> path;
  final String title;

  SidebarItem(this.path, this.title);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SidebarItem && runtimeType == other.runtimeType && title == other.title;

  @override
  int get hashCode => title.hashCode;
}

class _AddNasSubtitleDialogState extends ConsumerState<AddNasSubtitleDialog> {
  SidebarItem? _selectedSidebarItem;
  Set<String> _selectedFilePaths = {};

  @override
  Widget build(BuildContext context) {
    final authDirsAsync = ref.watch(authorizedDirsProvider);

    return ContentDialog(
      title: Text(widget.title),
      content: SizedBox(
        height: 400,
        width: 700,
        child: authDirsAsync.when(
          data: (authDirs) {
            final sidebarItems = _buildSidebarItems(authDirs);
            if (_selectedSidebarItem == null && sidebarItems.isNotEmpty) {
              // Defer state update
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedSidebarItem = sidebarItems.first;
                  });
                }
              });
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 200,
                  child: ListView.builder(
                    itemCount: sidebarItems.length,
                    itemBuilder: (context, index) {
                      final item = sidebarItems[index];
                      final isSelected = item == _selectedSidebarItem;
                      return ListTile.selectable(
                        title: Text(item.title),
                        selected: isSelected,
                        onSelectionChange: (v) {
                          if (v) {
                            setState(() {
                              _selectedSidebarItem = item;
                              _selectedFilePaths.clear();
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                const Divider(direction: Axis.vertical),
                Expanded(
                  child: _selectedSidebarItem != null
                      ? FileTreePicker(
                          key: ValueKey(_selectedSidebarItem!.title),
                          rootPaths: _selectedSidebarItem!.path,
                          hideRoot: _selectedSidebarItem!.title == "视频所在位置",
                          allowedExtensions: const ['ass', 'srt', 'vtt', 'sub', 'ssa'],
                          onSelectionChanged: (paths) {
                            // Defer state update to avoid build error if called during build
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                               if(mounted) {
                                  setState(() {
                                    _selectedFilePaths = paths;
                                  });
                               }
                            });
                          },
                        )
                      : const Center(child: Text("请选择存储空间")),
                ),
              ],
            );
          },
          loading: () => const Center(child: ProgressRing()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
      actions: [
        Button(
          onPressed: _selectedFilePaths.isNotEmpty
              ? () {
                  widget.onConfirm(_selectedFilePaths.toList());
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('选择'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  List<SidebarItem> _buildSidebarItems(List<AuthDir> authDirs) {
    final items = <SidebarItem>[];

    if (widget.currentPath.isNotEmpty) {
      String dir = widget.currentPath;
      if (dir.contains('/')) {
        dir = dir.substring(0, dir.lastIndexOf('/'));
      }
      items.add(SidebarItem([dir], "视频所在位置"));
    }

    for (final dir in authDirs) {
      final name = FnDataConvertor.getVolumeCNName(dir.path);
      final existingIndex = items.indexWhere((i) => i.title == name);
      if (existingIndex != -1) {
        items[existingIndex].path.add(dir.path);
      } else {
        items.add(SidebarItem([dir.path], name));
      }
    }
    return items;
  }
}
