import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/file_models.dart';
import '../../../data/utils/fn_data_convertor.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../providers/file_providers.dart';
import '../common/app_loading_progress_ring.dart';
import '../dialogs/app_dialog.dart';
import '../toast.dart';
import 'add_nas_subtitle_dialog.dart' show SidebarItem;
import 'nas_breadcrumb_bar.dart';
import 'nas_file_browser.dart';

const Color _nasBorderColor = Color(0x1AFDFDFD);
const Color _nasSidebarSelectedColor = Color(0xB3002570);
const Color _nasSidebarHoverColor = Color(0x0DFFFFFF);
const Color _nasSidebarTextColor = Color(0xCCFFFFFF);

/// Maximum number of directories one scan config may hold (guards the
/// server-side SCAN_DIRS column and keeps a scan bounded).
const int _maxScanDirs = 20;

/// Directory picker for the scheduled thumbnail scan: same sidebar + tree
/// layout as [AddNasSubtitleDialog], but directories are the checkable nodes
/// and the selection persists across storage switches. Pops the chosen
/// directory paths (`List<String>`), or null on cancel.
class NasDirectoryPickerDialog extends ConsumerStatefulWidget {
  const NasDirectoryPickerDialog({
    super.key,
    this.initialSelection = const {},
  });

  /// Directories already saved in the config, pre-checked in the tree.
  final Set<String> initialSelection;

  @override
  ConsumerState<NasDirectoryPickerDialog> createState() =>
      _NasDirectoryPickerDialogState();
}

class _NasDirectoryPickerDialogState
    extends ConsumerState<NasDirectoryPickerDialog> {
  SidebarItem? _selectedSidebarItem;
  late Set<String> _selectedDirs = Set<String>.of(widget.initialSelection);
  List<String> _breadcrumbSegments = [];

  void _confirm() {
    final l10n = AppLocalizations.of(context);
    if (_selectedDirs.length > _maxScanDirs) {
      ref.read(toastManagerProvider.notifier).showToast(
            l10n.nasDirPickerLimitReached('$_maxScanDirs'),
            style: ToastStyle.fluent,
            type: ToastType.warning,
            category: 'nas-dir-picker-limit',
          );
      return;
    }
    Navigator.of(context).pop(_selectedDirs.toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authDirsAsync = ref.watch(authorizedDirsProvider);

    return AppDialog<List<String>>(
      constraints: const BoxConstraints(
        minWidth: 672,
        maxWidth: 672,
        maxHeight: 720,
      ),
      title: l10n.nasDirPickerTitle,
      autoDismiss: false,
      onClose: () {
        if (mounted) Navigator.of(context).pop();
      },
      primaryButtonText: l10n.commonConfirm,
      onPrimaryPressed: _confirm,
      secondaryButtonText: l10n.commonCancel,
      onSecondaryPressed: () {
        if (mounted) Navigator.of(context).pop();
      },
      content: SizedBox(
        width: 624,
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

  Widget _buildBrowserContainer(List<SidebarItem> sidebarItems) {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        border: Border.all(color: _nasBorderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            _buildTopBar(),
            Container(height: 1, color: _nasBorderColor),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 170, child: _buildSidebar(sidebarItems)),
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
        return _PickerSidebarItem(
          key: ValueKey('nas-dir-sidebar-${item.title}'),
          title: item.title,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedSidebarItem = item;
              _breadcrumbSegments = [item.title];
              // The selection deliberately survives the storage switch.
            });
          },
        );
      },
    );
  }

  Widget _buildMainContent() {
    final sidebarItem = _selectedSidebarItem;
    if (sidebarItem == null) {
      return Center(
        child: Text(AppLocalizations.of(context).nasSubtitleSelectStorage),
      );
    }
    return NasFileBrowser(
      key: ValueKey('nas-dir-browser-${sidebarItem.title}'),
      roots: sidebarItem.roots,
      sidebarTitle: sidebarItem.title,
      selectionMode: NasBrowserSelectionMode.directories,
      initialSelection: _selectedDirs,
      onSelectionChanged: (paths) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _selectedDirs = paths);
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

  /// Breadcrumb segments for [activePath] within [item] (same rule as the
  /// subtitle dialog: longest matching root prefix, volume label once).
  List<String> _deriveSegments(String activePath, SidebarItem item) {
    if (activePath.isEmpty) return [item.title];
    NasBrowserRoot? matched;
    for (final root in item.roots) {
      final rootPath = root.path.endsWith('/') ? root.path : '${root.path}/';
      if (activePath == root.path || activePath.startsWith(rootPath)) {
        if (matched == null || root.path.length > matched.path.length) {
          matched = root;
        }
      }
    }
    final rootLabel = matched?.displayName?.trim().isNotEmpty == true
        ? matched!.displayName!.trim()
        : item.title;
    String remainder;
    if (matched != null) {
      final prefix =
          matched.path.endsWith('/') ? matched.path : '${matched.path}/';
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

  /// Storage sidebar entries straight from the authorized dirs — there is no
  /// "current video location" here, this picker is not tied to one media item.
  List<SidebarItem> _buildSidebarItems(List<AuthDir> authDirs) {
    final items = <SidebarItem>[];
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

class _PickerSidebarItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerSidebarItem({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PickerSidebarItem> createState() => _PickerSidebarItemState();
}

class _PickerSidebarItemState extends State<_PickerSidebarItem> {
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
            style: const TextStyle(fontSize: 14, color: _nasSidebarTextColor),
          ),
        ),
      ),
    );
  }
}
