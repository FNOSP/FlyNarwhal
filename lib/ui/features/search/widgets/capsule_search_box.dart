import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/entities/search_result_type.dart';

import '../../../../data/models/home_models.dart';
import '../../../../data/storage/shortcut_settings_store.dart';
import '../../../../providers/providers.dart';
import '../search_view_model.dart';
import 'search_result_dropdown.dart';

/// Capsule-shaped search box placed in the title bar center.
/// Replicates Compose CapsuleSearchBox: expands on focus, shows a dropdown
/// of results with category tabs, supports keyboard navigation, and navigates
/// to the matching detail page on selection.
class CapsuleSearchBox extends ConsumerStatefulWidget {
  final double collapsedWidth;
  final double expandedWidth;
  final double height;
  final String placeholder;
  final FocusNode? focusNode;
  final VoidCallback? onDismissed;

  const CapsuleSearchBox({
    super.key,
    this.collapsedWidth = 130,
    this.expandedWidth = 480,
    this.height = 32,
    this.placeholder = '搜索片名、演员',
    this.focusNode,
    this.onDismissed,
  });

  @override
  ConsumerState<CapsuleSearchBox> createState() => _CapsuleSearchBoxState();
}

class _CapsuleSearchBoxState extends ConsumerState<CapsuleSearchBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _internalFocusNode = FocusNode();
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  bool _isFocused = false;
  bool _isHovered = false;
  bool _isInteractingWithDropdown = false;
  // Category tabs mirroring Compose tabs
  static const List<String> _tabs = ['全部', '电影', '电视剧', '电视直播', '人物', '其他'];
  String _selectedTab = '全部';
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant CapsuleSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    (oldWidget.focusNode ?? _internalFocusNode).removeListener(_onFocusChange);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _internalFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _focusNode.hasFocus;
    if (focused == _isFocused) return;
    if (!focused && _isInteractingWithDropdown) {
      _focusNode.requestFocus();
      return;
    }
    setState(() => _isFocused = focused);
    if (focused) {
      _showDropdownIfNeeded();
    } else {
      // Collapse and clear on blur, like Compose collapseOnBlur
      _controller.clear();
      ref.read(searchProvider.notifier).clearSearch();
      _selectedTab = '全部';
      _selectedIndex = -1;
      _overlayController.hide();
    }
  }

  void _onTextChanged(String value) {
    ref.read(searchProvider.notifier).search(value);
    _selectedIndex = value.trim().isEmpty ? -1 : 0;
    _showDropdownIfNeeded();
    setState(() {});
  }

  void _showDropdownIfNeeded() {
    if (_isFocused && _controller.text.trim().isNotEmpty) {
      if (!_overlayController.isShowing) {
        _overlayController.show();
      }
    } else {
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
    }
  }

  List<MediaItem> _filterItems(List<MediaItem> all) {
    if (_selectedTab == '全部') return all;
    return all.where((item) {
      final resultType = SearchResultType.tryParse(item.type);
      switch (_selectedTab) {
        case '电影':
          return resultType == SearchResultType.movie;
        case '电视剧':
          return resultType == SearchResultType.tv;
        case '电视直播':
          return resultType == SearchResultType.liveChannel;
        case '人物':
          return resultType == SearchResultType.person;
        case '其他':
          return resultType != SearchResultType.movie &&
              resultType != SearchResultType.tv &&
              resultType != SearchResultType.liveChannel &&
              resultType != SearchResultType.person;
        default:
          return true;
      }
    }).toList();
  }

  void _endDropdownPointerInteraction() {
    _isInteractingWithDropdown = false;
  }

  void _beginDropdownPointerInteraction() {
    _isInteractingWithDropdown = true;
  }

  void _dismiss() {
    _isInteractingWithDropdown = false;
    _controller.clear();
    ref.read(searchProvider.notifier).clearSearch();
    _selectedTab = '全部';
    _selectedIndex = -1;
    _overlayController.hide();
    _focusNode.unfocus();
    widget.onDismissed?.call();
  }

  // Navigate to the detail page matching the item type, like Compose navigateToSearchItem.
  void _navigateToSearchItem(MediaItem item) {
    final guid = item.guid.trim();
    if (guid.isEmpty) return;
    final currentPath = GoRouterState.of(context).uri.toString();
    String? target;
    switch (SearchResultType.tryParse(item.type)) {
      case SearchResultType.movie:
      case SearchResultType.video:
        target = '/movie/$guid';
        break;
      case SearchResultType.tv:
        target = '/tv/$guid';
        break;
      case SearchResultType.person:
        target = '/person/$guid';
        break;
      case SearchResultType.liveChannel:
        target = '/live/$guid';
        break;
      default:
        target = null;
    }
    if (target == null) return;
    _dismiss();
    ref.read(navigationStackProvider.notifier).pushPath(currentPath);
    if (SearchResultType.tryParse(item.type) == SearchResultType.liveChannel) {
      ref.read(navigationStackProvider.notifier).playerSourcePath = currentPath;
    }
    // Push (instead of go) so the source page stays mounted under the detail
    // or live player page and keeps its scroll position on return.
    context.push(target);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final searchState = ref.read(searchProvider);
    final items = _filterItems(searchState.results);
    final dropdownVisible = _isFocused && _controller.text.trim().isNotEmpty;

    final shortcutStore = ref.read(shortcutSettingsStoreProvider);

    if (shortcutStore.matches(event, ShortcutActionId.searchExit)) {
      _dismiss();
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.searchSwitchTab)) {
      final currentIndex = _tabs.indexOf(_selectedTab);
      setState(() {
        _selectedTab = _tabs[(currentIndex + 1) % _tabs.length];
        final filteredItemsAfterTabSwitch = _filterItems(searchState.results);
        _selectedIndex = filteredItemsAfterTabSwitch.isEmpty ? -1 : 0;
      });
      return KeyEventResult.handled;
    }
    if (!dropdownVisible || items.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (shortcutStore.matches(event, ShortcutActionId.searchNext)) {
      setState(() {
        _selectedIndex =
            _selectedIndex < 0 ? 0 : (_selectedIndex + 1) % items.length;
      });
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.searchPrev)) {
      setState(() {
        _selectedIndex = _selectedIndex < 0
            ? items.length - 1
            : (_selectedIndex - 1 + items.length) % items.length;
      });
      return KeyEventResult.handled;
    }
    if (shortcutStore.matches(event, ShortcutActionId.searchSelect)) {
      final item = items.length > _selectedIndex && _selectedIndex >= 0
          ? items[_selectedIndex]
          : null;
      if (item != null) {
        _navigateToSearchItem(item);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final searchState = ref.watch(searchProvider);

    final width = _isFocused ? widget.expandedWidth : widget.collapsedWidth;
    final showBackground = _isHovered || _isFocused;
    final backgroundColor = showBackground
        ? theme.resources.controlFillColorDefault
        : Colors.transparent;
    final borderColor = Colors.grey.withValues(alpha: 0.4);

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) {
        final items = _filterItems(searchState.results);
        return Positioned(
          width: widget.expandedWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 6),
            child: Align(
              alignment: Alignment.topCenter,
              child: SearchResultDropdown(
                width: widget.expandedWidth,
                isLoading: searchState.isLoading,
                hasSearched: searchState.hasSearched,
                tabs: _tabs,
                selectedTab: _selectedTab,
                onTabSelected: (tab) {
                  setState(() {
                    _selectedTab = tab;
                    final filtered = _filterItems(searchState.results);
                    _selectedIndex = filtered.isEmpty ? -1 : 0;
                  });
                },
                items: items,
                selectedIndex: _selectedIndex,
                onPointerInteractionStart: _beginDropdownPointerInteraction,
                onPointerInteractionEnd: _endDropdownPointerInteraction,
                onItemSelected: _navigateToSearchItem,
              ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Focus(
          onKeyEvent: _onKeyEvent,
          child: MouseRegion(
            cursor: SystemMouseCursors.text,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  border: Border.all(color: borderColor, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.search,
                      size: 14,
                      color: theme.resources.textFillColorTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          if (_controller.text.isEmpty)
                            IgnorePointer(
                              child: Text(
                                widget.placeholder,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: theme.typography.caption?.copyWith(
                                  color: theme.resources.textFillColorSecondary,
                                ),
                              ),
                            ),
                          EditableText(
                            key: const ValueKey('search-capsule-input'),
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: _onTextChanged,
                            maxLines: 1,
                            style: theme.typography.caption?.copyWith(
                                  color: theme.resources.textFillColorPrimary,
                                ) ??
                                TextStyle(
                                  color: theme.resources.textFillColorPrimary,
                                  fontSize: 12,
                                ),
                            cursorColor: theme.resources.textFillColorPrimary,
                            backgroundCursorColor:
                                theme.resources.textFillColorTertiary,
                            selectionColor:
                                const Color(0xFF2173DF).withValues(alpha: 0.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
