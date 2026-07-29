import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/file_models.dart';
import '../../../data/utils/fn_data_convertor.dart';
import '../../../providers/file_providers.dart';
import 'file_tree_picker.dart';
import '../common/app_loading_progress_ring.dart';

const Color _nasBorderColor = Color(0x80808080);
const Color _nasSidebarHighlightColor = Color(0x0DFFFFFF);
const Color _nasSidebarSecondaryTextColor = Color(0xC8FFFFFF);

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

            return _buildBrowserContainer(sidebarItems);
          },
          loading: () => const SizedBox(
            height: 300,
            child: Center(child: AppLoadingProgressRing()),
          ),
          error: (err, stack) => SizedBox(
            height: 300,
            child: Center(child: Text('Error: $err')),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _selectedFilePaths.isNotEmpty
              ? () {
                  widget.onConfirm(_selectedFilePaths.toList());
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('添加'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  // Bordered rounded container hosting the top bar, sidebar and file tree.
  Widget _buildBrowserContainer(List<SidebarItem> sidebarItems) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: _nasBorderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _TopBar(title: _selectedSidebarItem?.title ?? '视频所在位置'),
          Container(height: 1, color: _nasBorderColor),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 150,
                  child: _buildSidebar(sidebarItems),
                ),
                Container(width: 1, color: _nasBorderColor),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(List<SidebarItem> sidebarItems) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sidebarItems.length,
      itemBuilder: (context, index) {
        final item = sidebarItems[index];
        final isSelected = item == _selectedSidebarItem;
        return _NasSidebarItem(
          title: item.title,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedSidebarItem = item;
              _selectedFilePaths.clear();
            });
          },
        );
      },
    );
  }

  Widget _buildMainContent() {
    if (_selectedSidebarItem == null) {
      return const Center(child: Text('请选择存储空间'));
    }
    return FileTreePicker(
      key: ValueKey(_selectedSidebarItem!.title),
      rootPaths: _selectedSidebarItem!.path,
      hideRoot: _selectedSidebarItem!.title == '视频所在位置',
      allowedExtensions: const ['ass', 'srt', 'vtt', 'sub', 'ssa'],
      onSelectionChanged: (paths) {
        // Defer state update to avoid build error if called during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedFilePaths = paths;
            });
          }
        });
      },
    );
  }

  List<SidebarItem> _buildSidebarItems(List<AuthDir> authDirs) {
    final items = <SidebarItem>[];

    // Always expose the current video location entry, even when path is empty.
    String dir = widget.currentPath;
    if (dir.contains('/')) {
      dir = dir.substring(0, dir.lastIndexOf('/'));
    }
    items.add(SidebarItem([dir], '视频所在位置'));

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

// Top bar showing the currently selected storage location title.
class _TopBar extends StatelessWidget {
  final String title;

  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

// Sidebar entry with hover/selected highlight, mirroring the KMP design.
class _NasSidebarItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _NasSidebarItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NasSidebarItem> createState() => _NasSidebarItemState();
}

class _NasSidebarItemState extends State<_NasSidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.isSelected || _isHovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: highlighted ? _nasSidebarHighlightColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 14,
              color: widget.isSelected
                  ? Colors.white
                  : _nasSidebarSecondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }
}
