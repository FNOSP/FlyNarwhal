import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/file_models.dart';
import '../../../data/utils/fn_data_convertor.dart';
import '../../../providers/file_providers.dart';
import '../common/app_loading_progress_ring.dart';
import '../toast.dart';
import 'nas_breadcrumb_bar.dart';
import 'nas_file_browser.dart';

const Color _nasBorderColor = Color(0x1AFDFDFD);
const Color _nasSidebarSelectedColor = Color(0xB3002570);
const Color _nasSidebarHoverColor = Color(0x0DFFFFFF);
const Color _nasSidebarTextColor = Color(0xCCFFFFFF);

/// Maximum number of subtitle files that can be marked at once, matching the
/// web player's limit.
const int _maxMarkableSubtitles = 20;

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
  ConsumerState<AddNasSubtitleDialog> createState() =>
      _AddNasSubtitleDialogState();
}

class SidebarItem {
  final List<NasBrowserRoot> roots;
  final String title;

  SidebarItem(this.roots, this.title);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SidebarItem &&
          runtimeType == other.runtimeType &&
          title == other.title;

  @override
  int get hashCode => title.hashCode;
}

class _AddNasSubtitleDialogState extends ConsumerState<AddNasSubtitleDialog> {
  SidebarItem? _selectedSidebarItem;
  Set<String> _selectedFilePaths = {};
  List<String> _breadcrumbSegments = [];

  @override
  void initState() {
    super.initState();
    // Breadcrumb starts empty — only populated when user clicks a tree row.
    _breadcrumbSegments = [];
  }

  /// Derive breadcrumb segments from [activePath] and the current sidebar item.
  /// Strips the matched root's path prefix so the volume name appears once.
  List<String> _deriveSegments(String activePath, SidebarItem? item) {
    if (activePath.isEmpty) {
      return [item?.title ?? ''];
    }
    final itemToUse = item ?? _selectedSidebarItem;
    if (itemToUse == null) {
      return activePath.split('/').where((s) => s.isNotEmpty).toList();
    }

    // Find the root whose path is a prefix of activePath (longest match).
    NasBrowserRoot? matched;
    for (final root in itemToUse.roots) {
      final rootPath = root.path.endsWith('/')
          ? root.path
          : '${root.path}/';
      if (activePath == root.path || activePath.startsWith(rootPath)) {
        if (matched == null || root.path.length > matched.path.length) {
          matched = root;
        }
      }
    }

    final rootLabel = matched?.displayName?.trim().isNotEmpty == true
        ? matched!.displayName!.trim()
        : itemToUse.title;

    String remainder;
    if (matched != null) {
      final prefix = matched.path.endsWith('/')
          ? matched.path
          : '${matched.path}/';
      remainder = activePath == matched.path
          ? ''
          : activePath.startsWith(prefix)
              ? activePath.substring(prefix.length)
              : activePath;
    } else {
      remainder = activePath;
    }

    final parts = remainder.split('/').where((s) => s.isNotEmpty).toList();
    return [rootLabel, ...parts];
  }

  @override
  Widget build(BuildContext context) {
    final authDirsAsync = ref.watch(authorizedDirsProvider);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 672),
      title: Row(
        children: [
          Text(widget.title),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(FluentIcons.chrome_close, size: 14),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 630,
        child: authDirsAsync.when(
          data: (authDirs) {
            final sidebarItems = _buildSidebarItems(authDirs);
            if (_selectedSidebarItem == null && sidebarItems.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedSidebarItem = sidebarItems.first;
                    _breadcrumbSegments = [sidebarItems.first.title];
                  });
                }
              });
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBrowserContainer(sidebarItems),
                const SizedBox(height: 16),
                _buildFooterActions(),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 360,
            child: Center(child: AppLoadingProgressRing()),
          ),
          error: (err, stack) => SizedBox(
            height: 360,
            child: Center(child: Text('Error: $err')),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 80,
          child: Button(
            key: const ValueKey('nas-subtitle-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: FilledButton(
            key: const ValueKey('nas-subtitle-confirm'),
            onPressed: _selectedFilePaths.isNotEmpty
                ? () {
                    if (_selectedFilePaths.length > _maxMarkableSubtitles) {
                      ref.read(toastManagerProvider.notifier).showToast(
                            '最多选择 $_maxMarkableSubtitles 个文件',
                            type: ToastType.warning,
                            category: 'nas-subtitle-limit',
                          );
                      return;
                    }
                    widget.onConfirm(_selectedFilePaths.toList());
                    Navigator.of(context).pop();
                  }
                : null,
            child: const Text('选择'),
          ),
        ),
      ],
    );
  }

  Widget _buildBrowserContainer(List<SidebarItem> sidebarItems) {
    return Container(
      height: 408,
      decoration: BoxDecoration(
        border: Border.all(color: _nasBorderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Top bar showing selected sidebar item title
            _buildTopBar(),
            Container(height: 1, color: _nasBorderColor),
            // Main content: sidebar + tree view
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 170,
                    child: _buildSidebar(sidebarItems),
                  ),
                  Container(width: 1, color: _nasBorderColor),
                  Expanded(child: _buildMainContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: NasBreadcrumbBar(
          segments: _breadcrumbSegments,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
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
          key: ValueKey('nas-sidebar-${item.title}'),
          title: item.title,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedSidebarItem = item;
              _selectedFilePaths = {};
              _breadcrumbSegments = [item.title];
            });
          },
        );
      },
    );
  }

  Widget _buildMainContent() {
    final sidebarItem = _selectedSidebarItem;
    if (sidebarItem == null) {
      return const Center(child: Text('请选择存储空间'));
    }
    return NasFileBrowser(
      key: ValueKey(sidebarItem.title),
      roots: sidebarItem.roots,
      sidebarTitle: sidebarItem.title,
      hideRoot: sidebarItem.title == '视频所在位置',
      allowedExtensions: const ['ass', 'srt', 'vtt', 'sub', 'ssa', 'sup'],
      onSelectionChanged: (paths) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedFilePaths = paths;
            });
          }
        });
      },
      onRowActivated: (path) {
        if (!mounted) return;
        setState(() {
          _breadcrumbSegments = _deriveSegments(path, sidebarItem);
        });
      },
    );
  }

  List<SidebarItem> _buildSidebarItems(List<AuthDir> authDirs) {
    final items = <SidebarItem>[];

    String dir = widget.currentPath;
    if (dir.contains('/')) {
      dir = dir.substring(0, dir.lastIndexOf('/'));
    }
    items.add(
      SidebarItem(
        [NasBrowserRoot(path: dir)],
        '视频所在位置',
      ),
    );

    for (final dir in authDirs) {
      final name =
          FnDataConvertor.getAuthDirSidebarLabel(dir.path, dir.storageType);
      final existingIndex = items.indexWhere((i) => i.title == name);
      if (existingIndex != -1) {
        items[existingIndex].roots.add(
              NasBrowserRoot(
                path: dir.path,
                displayName: FnDataConvertor.getAuthDirRootLabel(dir),
              ),
            );
      } else {
        items.add(
          SidebarItem(
            [
              NasBrowserRoot(
                path: dir.path,
                displayName: FnDataConvertor.getAuthDirRootLabel(dir),
              ),
            ],
            name,
          ),
        );
      }
    }
    return items;
  }
}

class _NasSidebarItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _NasSidebarItem({
    super.key,
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? _nasSidebarSelectedColor
                : _isHovered
                    ? _nasSidebarHoverColor
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 14,
              color: _nasSidebarTextColor,
            ),
          ),
        ),
      ),
    );
  }
}
