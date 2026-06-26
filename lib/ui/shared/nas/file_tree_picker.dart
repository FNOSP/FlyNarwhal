import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/log/app_talker.dart';
import '../../../data/models/file_models.dart';
import '../../../providers/file_providers.dart';
import '../common/app_loading_progress_ring.dart';

class FileTreePicker extends ConsumerStatefulWidget {
  final List<String> rootPaths;
  final Function(Set<String>) onSelectionChanged;
  final List<String> allowedExtensions;
  final bool hideRoot;

  const FileTreePicker({
    super.key,
    required this.rootPaths,
    required this.onSelectionChanged,
    this.allowedExtensions = const [],
    this.hideRoot = false,
  });

  @override
  ConsumerState<FileTreePicker> createState() => _FileTreePickerState();
}

class _FileTreePickerState extends ConsumerState<FileTreePicker> {
  List<TreeViewItem> items = [];

  @override
  void initState() {
    super.initState();
    _initializeRoots();
  }

  @override
  void didUpdateWidget(covariant FileTreePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPaths != widget.rootPaths) {
      _initializeRoots();
    }
  }

  void _initializeRoots() {
    if (widget.hideRoot) {
      _loadHiddenRoots();
    } else {
      items = widget.rootPaths.map((path) {
        return _createTreeViewItem(path, path.split('/').last, isDir: true);
      }).toList();
      setState(() {});
    }
  }

  Future<void> _loadHiddenRoots() async {
    final newItems = <TreeViewItem>[];
    for (final path in widget.rootPaths) {
      if (path.isEmpty) continue;
      try {
        final files = await ref.read(fileRepositoryProvider).getFilesByServerPath(path);
        for (final file in files) {
          if (_isAllowed(file)) {
            newItems.add(_createTreeViewItem(
              '$path/${file.filename}',
              file.filename,
              isDir: file.isDir,
            ));
          }
        }
      } catch (e) {
        AppTalker.warning('FileTreePicker', 'Error loading root $path: $e');
      }
    }
    if (mounted) {
      setState(() {
        items = newItems;
      });
    }
  }

  bool _isAllowed(ServerPathResponse file) {
    if (file.isDir) return true;
    if (widget.allowedExtensions.isEmpty) return true;
    final ext = file.filename.split('.').last.toLowerCase();
    return widget.allowedExtensions.contains(ext);
  }

  TreeViewItem _createTreeViewItem(String path, String name, {required bool isDir}) {
    return TreeViewItem(
      content: Text(name),
      value: path,
      lazy: isDir,
      children: [],
      onExpandToggle: (item, getsExpanded) async {
        if (getsExpanded && item.children.isEmpty && isDir) {
          try {
            final files = await ref.read(fileRepositoryProvider).getFilesByServerPath(path);
            final children = <TreeViewItem>[];
            for (final file in files) {
              if (_isAllowed(file)) {
                children.add(_createTreeViewItem(
                  '$path/${file.filename}',
                  file.filename,
                  isDir: file.isDir,
                ));
              }
            }
            item.children.addAll(children);
            if (mounted) setState(() {});
          } catch (e) {
            AppTalker.warning(
              'FileTreePicker',
              'Error loading children for $path: $e',
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && widget.rootPaths.isNotEmpty && widget.hideRoot) {
      return const Center(child: AppLoadingProgressRing());
    }
    
    return TreeView(
      items: items,
      selectionMode: TreeViewSelectionMode.multiple,
      onSelectionChanged: (selectedItems) async {
        final paths = <String>{};
        for (final item in selectedItems) {
          // If lazy is true, it is a directory.
          if (item.lazy == true) continue;
          paths.add(item.value as String);
        }
        widget.onSelectionChanged(paths);
      },
    );
  }
}
