import '../../l10n/generated/app_localizations.dart';
import '../../data/storage/shortcut_settings_store.dart';

/// Localized display name for a keyboard-shortcut action.
///
/// Kept out of the storage layer so the persisted definitions stay free of
/// localization dependencies.
extension ShortcutActionLocalization on ShortcutActionId {
  String localizedTitle(AppLocalizations l10n) {
    switch (this) {
      case ShortcutActionId.focusSearch:
        return l10n.shortcutFocusSearch;
      case ShortcutActionId.togglePlayPause:
        return l10n.shortcutTogglePlayPause;
      case ShortcutActionId.mute:
        return l10n.shortcutMute;
      case ShortcutActionId.seekBackward:
        return l10n.shortcutSeekBackward;
      case ShortcutActionId.seekForward:
        return l10n.shortcutSeekForward;
      case ShortcutActionId.volumeUp:
        return l10n.shortcutVolumeUp;
      case ShortcutActionId.volumeDown:
        return l10n.shortcutVolumeDown;
      case ShortcutActionId.toggleFullscreen:
        return l10n.shortcutToggleFullscreen;
      case ShortcutActionId.exitFullscreen:
        return l10n.shortcutExitFullscreen;
      case ShortcutActionId.searchNext:
        return l10n.shortcutSearchNext;
      case ShortcutActionId.searchPrev:
        return l10n.shortcutSearchPrev;
      case ShortcutActionId.searchSelect:
        return l10n.shortcutSearchSelect;
      case ShortcutActionId.searchSwitchTab:
        return l10n.shortcutSearchSwitchTab;
      case ShortcutActionId.searchExit:
        return l10n.shortcutSearchExit;
    }
  }
}
