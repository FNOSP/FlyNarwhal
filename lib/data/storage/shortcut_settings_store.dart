import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_manager.dart';

enum ShortcutCategory { search, playback }

enum ShortcutActionId {
  focusSearch,
  togglePlayPause,
  mute,
  seekBackward,
  seekForward,
  volumeUp,
  volumeDown,
  toggleFullscreen,
  exitFullscreen,
  searchNext,
  searchPrev,
  searchSelect,
  searchSwitchTab,
  searchExit,
}

class ShortcutKeyBinding {
  final int keyId;
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool meta;

  const ShortcutKeyBinding(
    this.keyId, {
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  bool matches(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    return event.logicalKey.keyId == keyId &&
        keyboard.isControlPressed == ctrl &&
        keyboard.isAltPressed == alt &&
        keyboard.isShiftPressed == shift &&
        keyboard.isMetaPressed == meta;
  }

  String format({bool? isMac}) {
    final mac = isMac ?? Platform.isMacOS;
    final modifierText = mac
        ? '${ctrl ? '⌃' : ''}${alt ? '⌥' : ''}${shift ? '⇧' : ''}${meta ? '⌘' : ''}'
        : [
            if (ctrl) 'Ctrl',
            if (alt) 'Alt',
            if (shift) 'Shift',
            if (meta) 'Win',
          ].join(' + ');
    final keyLabel = _keyLabelForId(keyId, mac);
    if (modifierText.isEmpty) return keyLabel;
    return mac ? '$modifierText$keyLabel' : '$modifierText + $keyLabel';
  }

  String toStorageString() => '$keyId|$ctrl|$alt|$shift|$meta';

  static ShortcutKeyBinding? fromStorageString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length != 5) return null;
    final keyId = int.tryParse(parts[0]);
    if (keyId == null) return null;
    return ShortcutKeyBinding(
      keyId,
      ctrl: bool.tryParse(parts[1]) ?? false,
      alt: bool.tryParse(parts[2]) ?? false,
      shift: bool.tryParse(parts[3]) ?? false,
      meta: bool.tryParse(parts[4]) ?? false,
    );
  }

  static ShortcutKeyBinding? fromKeyEvent(KeyEvent event) {
    if (_isModifierKey(event.logicalKey)) return null;
    final keyboard = HardwareKeyboard.instance;
    return ShortcutKeyBinding(
      event.logicalKey.keyId,
      ctrl: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
      meta: keyboard.isMetaPressed,
    );
  }

  static bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  static String _keyLabelForId(int keyId, bool isMac) {
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
    if (key == null) return 'Key $keyId';
    if (key == LogicalKeyboardKey.enter) return isMac ? '⏎' : 'Enter';
    if (key == LogicalKeyboardKey.numpadEnter) return isMac ? '⌤' : 'Num Enter';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.tab) return isMac ? '⇥' : 'Tab';
    if (key == LogicalKeyboardKey.backspace) return isMac ? '⌫' : 'Backspace';
    if (key == LogicalKeyboardKey.delete) return isMac ? '⌦' : 'Delete';
    if (key == LogicalKeyboardKey.home) return isMac ? '↖' : 'Home';
    if (key == LogicalKeyboardKey.end) return isMac ? '↘' : 'End';
    if (key == LogicalKeyboardKey.pageUp) return isMac ? '⇞' : 'Page Up';
    if (key == LogicalKeyboardKey.pageDown) return isMac ? '⇟' : 'Page Down';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.mediaPlayPause) return 'Play/Pause';
    if (key == LogicalKeyboardKey.mediaTrackPrevious) return 'Prev';
    if (key == LogicalKeyboardKey.mediaTrackNext) return 'Next';
    if (key == LogicalKeyboardKey.audioVolumeUp) return 'Volume Up';
    if (key == LogicalKeyboardKey.audioVolumeDown) return 'Volume Down';
    if (key == LogicalKeyboardKey.audioVolumeMute) return 'Mute';

    final label = key.keyLabel;
    if (label.isNotEmpty) return label;
    return key.debugName ?? 'Key $keyId';
  }
}

class ShortcutBinding {
  final ShortcutKeyBinding primary;
  final ShortcutKeyBinding? secondary;

  const ShortcutBinding({required this.primary, this.secondary});

  bool matches(KeyEvent event) {
    return primary.matches(event) || secondary?.matches(event) == true;
  }

  String format({bool? isMac}) {
    final primaryLabel = primary.format(isMac: isMac);
    final secondaryLabel = secondary?.format(isMac: isMac);
    if (secondaryLabel == null || secondaryLabel.isEmpty) return primaryLabel;
    return '$primaryLabel / $secondaryLabel';
  }
}

class ShortcutActionDefinition {
  final ShortcutActionId id;
  final String title;
  final ShortcutCategory category;
  final ShortcutBinding defaultBinding;

  const ShortcutActionDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.defaultBinding,
  });
}

class ShortcutSettingsStore {
  final SharedPreferences _prefs;
  final String? _userGuid;

  ShortcutSettingsStore(this._prefs, {String? userGuid})
      : _userGuid = PreferencesManager.normalizeGuid(userGuid);

  static final definitions = <ShortcutActionDefinition>[
    ShortcutActionDefinition(
      id: ShortcutActionId.focusSearch,
      title: '聚焦搜索输入框',
      category: ShortcutCategory.search,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.enter.keyId),
        secondary: ShortcutKeyBinding(LogicalKeyboardKey.numpadEnter.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.togglePlayPause,
      title: '播放/暂停',
      category: ShortcutCategory.playback,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.space.keyId),
        secondary: ShortcutKeyBinding(LogicalKeyboardKey.mediaPlayPause.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.mute,
      title: '静音/取消静音',
      category: ShortcutCategory.playback,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.keyM.keyId),
        secondary: ShortcutKeyBinding(LogicalKeyboardKey.audioVolumeMute.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.seekBackward,
      title: '快退 10 秒',
      category: ShortcutCategory.playback,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.arrowLeft.keyId),
        secondary:
            ShortcutKeyBinding(LogicalKeyboardKey.mediaTrackPrevious.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.seekForward,
      title: '快进 10 秒',
      category: ShortcutCategory.playback,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.arrowRight.keyId),
        secondary: ShortcutKeyBinding(LogicalKeyboardKey.mediaTrackNext.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.volumeUp,
      title: '音量增加',
      category: ShortcutCategory.playback,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.arrowUp.keyId),
        secondary: ShortcutKeyBinding(LogicalKeyboardKey.audioVolumeUp.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.volumeDown,
      title: '音量减少',
      category: ShortcutCategory.playback,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.arrowDown.keyId),
        secondary: ShortcutKeyBinding(LogicalKeyboardKey.audioVolumeDown.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.toggleFullscreen,
      title: '切换全屏',
      category: ShortcutCategory.playback,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.keyF.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.exitFullscreen,
      title: '退出全屏',
      category: ShortcutCategory.playback,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.escape.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.searchNext,
      title: '下一个搜索项',
      category: ShortcutCategory.search,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.arrowDown.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.searchPrev,
      title: '上一个搜索项',
      category: ShortcutCategory.search,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.arrowUp.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.searchSelect,
      title: '选中搜索项',
      category: ShortcutCategory.search,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.enter.keyId),
        secondary: ShortcutKeyBinding(LogicalKeyboardKey.numpadEnter.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.searchSwitchTab,
      title: '切换搜索分类',
      category: ShortcutCategory.search,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.tab.keyId),
      ),
    ),
    ShortcutActionDefinition(
      id: ShortcutActionId.searchExit,
      title: '退出搜索',
      category: ShortcutCategory.search,
      defaultBinding: ShortcutBinding(
        primary: ShortcutKeyBinding(LogicalKeyboardKey.escape.keyId),
      ),
    ),
  ];

  static final Map<ShortcutActionId, ShortcutActionDefinition> _definitionMap =
      {
    for (final definition in definitions) definition.id: definition,
  };

  ShortcutBinding getBinding(ShortcutActionId actionId) {
    final definition = _definitionMap[actionId];
    if (definition == null) {
      throw ArgumentError('Unknown shortcut action: $actionId');
    }
    final primary = ShortcutKeyBinding.fromStorageString(
          _readStringScoped(_storageKey(actionId, 'primary')),
        ) ??
        definition.defaultBinding.primary;
    final secondary = ShortcutKeyBinding.fromStorageString(
          _readStringScoped(_storageKey(actionId, 'secondary')),
        ) ??
        definition.defaultBinding.secondary;
    return ShortcutBinding(primary: primary, secondary: secondary);
  }

  Map<ShortcutActionId, ShortcutBinding> getAllBindings() {
    return {
      for (final definition in definitions)
        definition.id: getBinding(definition.id),
    };
  }

  Future<void> setBinding(
    ShortcutActionId actionId,
    ShortcutBinding binding,
  ) async {
    await _writeStringScoped(
      _storageKey(actionId, 'primary'),
      binding.primary.toStorageString(),
    );
    await _writeStringScoped(
      _storageKey(actionId, 'secondary'),
      binding.secondary?.toStorageString() ?? '',
    );
  }

  Future<void> resetToDefaults() async {
    for (final definition in definitions) {
      await setBinding(definition.id, definition.defaultBinding);
    }
  }

  bool matches(KeyEvent event, ShortcutActionId actionId) {
    return getBinding(actionId).matches(event);
  }

  bool shouldSuppressFocusSearchInput(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    return _isTextInputKey(event.logicalKey);
  }

  String _storageKey(ShortcutActionId actionId, String slot) {
    return 'shortcut.${actionId.name}.$slot';
  }

  String _scopedKey(String rawKey) {
    final guid = _userGuid;
    if (guid == null) return rawKey;
    return '$guid::$rawKey';
  }

  // 作用域读取：未登录读全局键；登录态只读 <guid>::<key>。
  // 不再做"懒迁移"复制：迁移由 UserSettingsMigrator 统一处理并删除全局值。
  String? _readStringScoped(String rawKey) {
    final guid = _userGuid;
    if (guid == null) {
      return _prefs.getString(rawKey);
    }
    return _prefs.getString('$guid::$rawKey');
  }

  Future<void> _writeStringScoped(String rawKey, String value) {
    return _prefs.setString(_scopedKey(rawKey), value);
  }

  bool _isTextInputKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyB ||
        key == LogicalKeyboardKey.keyC ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.keyE ||
        key == LogicalKeyboardKey.keyF ||
        key == LogicalKeyboardKey.keyG ||
        key == LogicalKeyboardKey.keyH ||
        key == LogicalKeyboardKey.keyI ||
        key == LogicalKeyboardKey.keyJ ||
        key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.keyL ||
        key == LogicalKeyboardKey.keyM ||
        key == LogicalKeyboardKey.keyN ||
        key == LogicalKeyboardKey.keyO ||
        key == LogicalKeyboardKey.keyP ||
        key == LogicalKeyboardKey.keyQ ||
        key == LogicalKeyboardKey.keyR ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyT ||
        key == LogicalKeyboardKey.keyU ||
        key == LogicalKeyboardKey.keyV ||
        key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyX ||
        key == LogicalKeyboardKey.keyY ||
        key == LogicalKeyboardKey.keyZ ||
        key == LogicalKeyboardKey.digit0 ||
        key == LogicalKeyboardKey.digit1 ||
        key == LogicalKeyboardKey.digit2 ||
        key == LogicalKeyboardKey.digit3 ||
        key == LogicalKeyboardKey.digit4 ||
        key == LogicalKeyboardKey.digit5 ||
        key == LogicalKeyboardKey.digit6 ||
        key == LogicalKeyboardKey.digit7 ||
        key == LogicalKeyboardKey.digit8 ||
        key == LogicalKeyboardKey.digit9;
  }
}
