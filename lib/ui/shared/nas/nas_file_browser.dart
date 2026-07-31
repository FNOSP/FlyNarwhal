import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/log/app_talker.dart';
import '../../../providers/file_providers.dart';
import '../common/app_loading_progress_ring.dart';

const Color _browserTextColor = Color(0xC8FFFFFF);
const Color _browserHoverColor = Color(0x0DFFFFFF);

class NasBrowserRoot {
  final String path;
  final String? displayName;

  const NasBrowserRoot({
    required this.path,
    this.displayName,
  });
}

/// A tree node representing a file or directory in the NAS file browser.
class TreeNode {
  final String path;
  final String name;
  final bool isDir;
  List<TreeNode>? children;
  bool isExpanded;
  bool isLoading;

  TreeNode({
    required this.path,
    required this.name,
    required this.isDir,
    this.children,
    this.isExpanded = false,
    this.isLoading = false,
  });
}

/// A tree-view NAS file browser mirroring the web player's "添加 NAS 字幕文件"
/// picker: expandable/collapsible folders with checkboxes and lazy loading.
class NasFileBrowser extends ConsumerStatefulWidget {
  final List<NasBrowserRoot> roots;
  final String sidebarTitle;
  final bool hideRoot;
  final List<String> allowedExtensions;
  final ValueChanged<Set<String>> onSelectionChanged;

  const NasFileBrowser({
    super.key,
    required this.roots,
    required this.sidebarTitle,
    required this.onSelectionChanged,
    this.hideRoot = false,
    this.allowedExtensions = const [],
  });

  @override
  ConsumerState<NasFileBrowser> createState() => _NasFileBrowserState();
}

class _NasFileBrowserState extends ConsumerState<NasFileBrowser> {
  List<TreeNode> _roots = [];
  final Set<String> _selected = {};
  bool _initialLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeTree();
  }

  @override
  void didUpdateWidget(covariant NasFileBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roots != widget.roots ||
        oldWidget.hideRoot != widget.hideRoot) {
      _initializeTree();
    }
  }

  void _initializeTree() {
    _selected.clear();
    widget.onSelectionChanged({});

    _roots = widget.roots.map((root) {
      final segments = root.path.split('/').where((s) => s.isNotEmpty).toList();
      final name = root.displayName?.trim().isNotEmpty == true
          ? root.displayName!.trim()
          : (segments.isEmpty ? root.path : segments.last);
      return TreeNode(
        path: root.path,
        name: name,
        isDir: true,
        isExpanded: widget.hideRoot,
        isLoading: false,
        children: null,
      );
    }).toList();

    if (widget.hideRoot && _roots.isNotEmpty) {
      _loadRootContents();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadRootContents() async {
    if (_roots.isEmpty) return;
    if (mounted) setState(() => _initialLoading = true);

    for (final root in _roots) {
      if (root.children == null && !root.isLoading) {
        await _loadDirectory(root);
      }
    }

    if (mounted) setState(() => _initialLoading = false);
  }

  bool _isAllowedFile(String filename) {
    if (widget.allowedExtensions.isEmpty) return true;
    final dot = filename.lastIndexOf('.');
    if (dot < 0) return false;
    return widget.allowedExtensions.contains(
      filename.substring(dot + 1).toLowerCase(),
    );
  }

  Future<void> _loadDirectory(TreeNode node) async {
    if (!node.isDir) return;
    node.isLoading = true;
    if (mounted) setState(() {});

    try {
      final files = await ref
          .read(fileRepositoryProvider)
          .getFilesByServerPath(node.path);
      final children = <TreeNode>[];
      for (final file in files) {
        if (file.isDir) {
          children.add(TreeNode(
            path: '${node.path}/${file.filename}',
            name: file.filename,
            isDir: true,
            children: null,
          ));
        } else if (_isAllowedFile(file.filename)) {
          children.add(TreeNode(
            path: '${node.path}/${file.filename}',
            name: file.filename,
            isDir: false,
            children: const [],
          ));
        }
      }
      children.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      node.children = children;
      node.isExpanded = true;
      node.isLoading = false;
      if (mounted) setState(() {});
    } catch (e) {
      AppTalker.warning('NasFileBrowser', 'Error loading ${node.path}: $e');
      node.isLoading = false;
      if (mounted) setState(() {});
    }
  }

  void _toggleExpand(TreeNode node) {
    if (!node.isDir) return;
    if (node.isExpanded) {
      node.isExpanded = false;
      if (mounted) setState(() {});
    } else if (node.children == null) {
      _loadDirectory(node);
    } else {
      node.isExpanded = true;
      if (mounted) setState(() {});
    }
  }

  void _toggleSelection(TreeNode node) {
    if (node.isDir) return; // Only files are selectable.
    if (_selected.contains(node.path)) {
      _selected.remove(node.path);
    } else {
      _selected.add(node.path);
    }
    if (mounted) setState(() {});
    widget.onSelectionChanged(Set.of(_selected));
  }

  bool get _isEmptyView {
    if (_roots.isEmpty) return true;
    if (widget.hideRoot) {
      // Empty once every root has finished loading and none yielded a node.
      final allLoaded = _roots.every((r) => r.children != null && !r.isLoading);
      if (!allLoaded) return false;
      return _roots.every((r) => (r.children ?? const []).isEmpty);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: AppLoadingProgressRing());
    }

    if (_isEmptyView) {
      return const Center(
        child: Text(
          '空空如也',
          style: TextStyle(color: _browserTextColor, fontSize: 13),
        ),
      );
    }

    if (widget.hideRoot) {
      // Render the (auto-expanded) roots' children directly at depth 0.
      final visible = <Widget>[];
      for (final root in _roots) {
        visible.add(_buildTreeNodes(root.children ?? [], 0));
      }
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: visible,
      );
    }

    // Render each root volume as a collapsible folder row at depth 0.
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _roots.length,
      itemBuilder: (context, index) => _buildTreeNode(_roots[index], 0, index),
    );
  }

  Widget _buildTreeNodes(List<TreeNode> nodes, int depth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < nodes.length; i++)
          _buildTreeNode(nodes[i], depth, i),
      ],
    );
  }

  Widget _buildTreeNode(TreeNode node, int depth, int index) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TreeNodeRow(
          key: ValueKey('nas-tree-row-$depth-$index'),
          node: node,
          depth: depth,
          index: index,
          isSelected: _selected.contains(node.path),
          onToggleExpand: () => _toggleExpand(node),
          onToggleSelection: () => _toggleSelection(node),
        ),
        if (node.isExpanded && node.children != null)
          _buildTreeNodes(node.children!, depth + 1),
      ],
    );
  }
}

class _TreeNodeRow extends StatefulWidget {
  final TreeNode node;
  final int depth;
  final int index;
  final bool isSelected;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleSelection;

  const _TreeNodeRow({
    super.key,
    required this.node,
    required this.depth,
    required this.index,
    required this.isSelected,
    required this.onToggleExpand,
    required this.onToggleSelection,
  });

  @override
  State<_TreeNodeRow> createState() => _TreeNodeRowState();
}

class _TreeNodeRowState extends State<_TreeNodeRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDir = widget.node.isDir;
    final isSelectable = !isDir;
    final indent = widget.depth * 24.0 + 8.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isDir ? widget.onToggleExpand : widget.onToggleSelection,
        child: Container(
          height: 36,
          padding: EdgeInsets.only(left: indent, right: 12),
          color: _isHovered || widget.isSelected
              ? _browserHoverColor
              : Colors.transparent,
          child: Row(
            children: [
              // Expand/collapse arrow (directories) or spacer (files).
              SizedBox(
                width: 20,
                height: 20,
                child: isDir
                    ? widget.node.isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: AppLoadingProgressRing(),
                          )
                        : Icon(
                            widget.node.isExpanded
                                ? FluentIcons.chevron_down_small
                                : FluentIcons.chevron_right_small,
                            size: 12,
                            color: _browserTextColor,
                          )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 4),
              // Checkbox: enabled only for selectable files.
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  key: isSelectable
                      ? ValueKey(
                          'nas-tree-check-${widget.depth}-${widget.index}')
                      : null,
                  checked: isSelectable && widget.isSelected,
                  onChanged:
                      isSelectable ? (_) => widget.onToggleSelection() : null,
                ),
              ),
              const SizedBox(width: 8),
              // Folder / file icon.
              Image.asset(
                isDir
                    ? 'assets/images/folder.png'
                    : 'assets/images/text.png',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 8),
              // Name.
              Expanded(
                child: Text(
                  widget.node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
