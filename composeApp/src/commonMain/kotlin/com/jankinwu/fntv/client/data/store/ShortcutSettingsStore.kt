package com.jankinwu.fntv.client.data.store

import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.isAltPressed
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.isMetaPressed
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import com.jankinwu.fntv.client.currentPlatform
import com.jankinwu.fntv.client.isMacOS
import com.russhwolf.settings.Settings
import com.russhwolf.settings.set

data class ShortcutKey(
    val keyCode: Long,
    val ctrl: Boolean = false,
    val alt: Boolean = false,
    val shift: Boolean = false,
    val meta: Boolean = false
) {
    fun matches(event: KeyEvent): Boolean {
        return event.key.keyCode == keyCode &&
                event.isCtrlPressed == ctrl &&
                event.isAltPressed == alt &&
                event.isShiftPressed == shift &&
                event.isMetaPressed == meta
    }

    fun format(isMac: Boolean): String {
        val modifierText = if (isMac) {
            buildString {
                if (ctrl) append("⌃")
                if (alt) append("⌥")
                if (shift) append("⇧")
                if (meta) append("⌘")
            }
        } else {
            buildList {
                if (ctrl) add("Ctrl")
                if (alt) add("Alt")
                if (shift) add("Shift")
                if (meta) add("Win")
            }.joinToString(" + ")
        }
        val keyLabel = keyLabelForCode(keyCode, isMac)
        return when {
            modifierText.isBlank() -> keyLabel
            isMac -> modifierText + keyLabel
            else -> "$modifierText + $keyLabel"
        }
    }

    fun toStorageString(): String {
        return listOf(keyCode.toString(), ctrl.toString(), alt.toString(), shift.toString(), meta.toString())
            .joinToString("|")
    }

    companion object {
        fun fromStorageString(raw: String?): ShortcutKey? {
            if (raw.isNullOrBlank()) return null
            val parts = raw.split("|")
            if (parts.size != 5) return null
            val keyCode = parts[0].toLongOrNull() ?: return null
            return ShortcutKey(
                keyCode = keyCode,
                ctrl = parts[1].toBooleanStrictOrNull() ?: false,
                alt = parts[2].toBooleanStrictOrNull() ?: false,
                shift = parts[3].toBooleanStrictOrNull() ?: false,
                meta = parts[4].toBooleanStrictOrNull() ?: false
            )
        }

        fun fromKeyEvent(event: KeyEvent): ShortcutKey? {
            if (isModifierKey(event.key)) return null
            return ShortcutKey(
                keyCode = event.key.keyCode,
                ctrl = event.isCtrlPressed,
                alt = event.isAltPressed,
                shift = event.isShiftPressed,
                meta = event.isMetaPressed
            )
        }

        private fun isModifierKey(key: Key): Boolean {
            return key == Key.ShiftLeft ||
                    key == Key.ShiftRight ||
                    key == Key.CtrlLeft ||
                    key == Key.CtrlRight ||
                    key == Key.AltLeft ||
                    key == Key.AltRight ||
                    key == Key.MetaLeft ||
                    key == Key.MetaRight
        }

        private fun keyLabelForCode(keyCode: Long, isMac: Boolean): String {
            return keyLabelMap(keyCode, isMac) ?: "Key $keyCode"
        }

        private fun keyLabelMap(keyCode: Long, isMac: Boolean): String? {
            return when (keyCode) {
                Key.Enter.keyCode -> if (isMac) "⏎" else "Enter"
                Key.NumPadEnter.keyCode -> if (isMac) "⌤" else "Num Enter"
                Key.Spacebar.keyCode -> if (isMac) "Space" else "Space"
                Key.Tab.keyCode -> if (isMac) "⇥" else "Tab"
                Key.Backspace.keyCode -> if (isMac) "⌫" else "Backspace"
                Key.Insert.keyCode -> "Ins"
                Key.Delete.keyCode -> if (isMac) "⌦" else "Delete"
                Key.Home.keyCode -> if (isMac) "↖" else "Home"
                Key.MoveEnd.keyCode -> if (isMac) "↘" else "End"
                Key.PageUp.keyCode -> if (isMac) "⇞" else "Page Up"
                Key.PageDown.keyCode -> if (isMac) "⇟" else "Page Down"
                Key.PrintScreen.keyCode -> "Print Screen"
                Key.ScrollLock.keyCode -> "Scroll Lock"
                Key.MediaPause.keyCode -> "Pause"
                Key.CapsLock.keyCode -> "Caps Lock"
                Key.NumLock.keyCode -> "Num Lock"
                Key.F2.keyCode -> "F2"
                Key.F3.keyCode -> "F3"
                Key.F4.keyCode -> "F4"
                Key.F5.keyCode -> "F5"
                Key.F6.keyCode -> "F6"
                Key.F7.keyCode -> "F7"
                Key.F8.keyCode -> "F8"
                Key.F9.keyCode -> "F9"
                Key.F10.keyCode -> "F10"
                Key.F11.keyCode -> "F11"
                Key.F12.keyCode -> "F12"
                Key.Escape.keyCode -> "Esc"
                Key.DirectionLeft.keyCode -> "←"
                Key.DirectionRight.keyCode -> "→"
                Key.DirectionUp.keyCode -> "↑"
                Key.DirectionDown.keyCode -> "↓"
                Key.MediaPlayPause.keyCode -> if (isMac) "Play/Pause" else "Play/Pause"
                Key.MediaStepBackward.keyCode -> if (isMac) "Prev" else "Prev"
                Key.MediaStepForward.keyCode -> if (isMac) "Next" else "Next"
                Key.VolumeUp.keyCode -> if (isMac) "Volume Up" else "Volume Up"
                Key.VolumeDown.keyCode -> if (isMac) "Volume Down" else "Volume Down"
                Key.VolumeMute.keyCode -> if (isMac) "Mute" else "Mute"
                Key.MediaStop.keyCode -> if (isMac) "Stop" else "Stop"
                Key.Comma.keyCode -> ","
                Key.Period.keyCode -> "."
                Key.Slash.keyCode -> "/"
                Key.Backslash.keyCode -> "\\"
                Key.Semicolon.keyCode -> ";"
                Key.Apostrophe.keyCode -> "'"
                Key.LeftBracket.keyCode -> "["
                Key.RightBracket.keyCode -> "]"
                Key.Grave.keyCode -> "`"
                Key.Minus.keyCode -> "-"
                Key.Equals.keyCode -> "="
                Key.NumPad0.keyCode -> "Num 0"
                Key.NumPad1.keyCode -> "Num 1"
                Key.NumPad2.keyCode -> "Num 2"
                Key.NumPad3.keyCode -> "Num 3"
                Key.NumPad4.keyCode -> "Num 4"
                Key.NumPad5.keyCode -> "Num 5"
                Key.NumPad6.keyCode -> "Num 6"
                Key.NumPad7.keyCode -> "Num 7"
                Key.NumPad8.keyCode -> "Num 8"
                Key.NumPad9.keyCode -> "Num 9"
                Key.NumPadAdd.keyCode -> "Num +"
                Key.NumPadSubtract.keyCode -> "Num -"
                Key.NumPadMultiply.keyCode -> "Num *"
                Key.NumPadDivide.keyCode -> "Num /"
                Key.NumPadDot.keyCode -> "Num ."
                else -> {
                    when (keyCode) {
                        Key.A.keyCode -> "A"
                        Key.B.keyCode -> "B"
                        Key.C.keyCode -> "C"
                        Key.D.keyCode -> "D"
                        Key.E.keyCode -> "E"
                        Key.F.keyCode -> "F"
                        Key.G.keyCode -> "G"
                        Key.H.keyCode -> "H"
                        Key.I.keyCode -> "I"
                        Key.J.keyCode -> "J"
                        Key.K.keyCode -> "K"
                        Key.L.keyCode -> "L"
                        Key.M.keyCode -> "M"
                        Key.N.keyCode -> "N"
                        Key.O.keyCode -> "O"
                        Key.P.keyCode -> "P"
                        Key.Q.keyCode -> "Q"
                        Key.R.keyCode -> "R"
                        Key.S.keyCode -> "S"
                        Key.T.keyCode -> "T"
                        Key.U.keyCode -> "U"
                        Key.V.keyCode -> "V"
                        Key.W.keyCode -> "W"
                        Key.X.keyCode -> "X"
                        Key.Y.keyCode -> "Y"
                        Key.Z.keyCode -> "Z"
                        Key.Zero.keyCode -> "0"
                        Key.One.keyCode -> "1"
                        Key.Two.keyCode -> "2"
                        Key.Three.keyCode -> "3"
                        Key.Four.keyCode -> "4"
                        Key.Five.keyCode -> "5"
                        Key.Six.keyCode -> "6"
                        Key.Seven.keyCode -> "7"
                        Key.Eight.keyCode -> "8"
                        Key.Nine.keyCode -> "9"
                        else -> null
                    }
                }
            }
        }
    }
}

data class ShortcutBinding(
    val primary: ShortcutKey,
    val secondary: ShortcutKey? = null
) {
    fun matches(event: KeyEvent): Boolean {
        return primary.matches(event) || secondary?.matches(event) == true
    }

    fun format(isMac: Boolean): String {
        val primaryLabel = primary.format(isMac)
        val secondaryLabel = secondary?.format(isMac)
        return if (secondaryLabel.isNullOrBlank()) primaryLabel else "$primaryLabel / $secondaryLabel"
    }
}

enum class ShortcutCategory {
    Search,
    Playback
}

enum class ShortcutActionId {
    FocusSearch,
    TogglePlayPause,
    StopPlayback,
    Mute,
    SeekBackward,
    SeekForward,
    VolumeUp,
    VolumeDown,
    ToggleFullscreen,
    ExitFullscreen,
    SearchNext,
    SearchPrev,
    SearchSelect,
    SearchSwitchTab,
    SearchExit
}

data class ShortcutActionDefinition(
    val id: ShortcutActionId,
    val title: String,
    val category: ShortcutCategory,
    val defaultBinding: ShortcutBinding
)

object ShortcutSettingsStore {
    private val settings = Settings()

    private fun scopedKey(rawKey: String): String {
        val guid = UserInfoMemoryCache.guid
        return if (guid.isNullOrBlank()) rawKey else "$guid::$rawKey"
    }

    val definitions = listOf(
        ShortcutActionDefinition(
            id = ShortcutActionId.FocusSearch,
            title = "聚焦搜索输入框",
            category = ShortcutCategory.Search,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.Enter.keyCode),
                secondary = ShortcutKey(Key.NumPadEnter.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.TogglePlayPause,
            title = "播放/暂停",
            category = ShortcutCategory.Playback,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.Spacebar.keyCode),
                secondary = ShortcutKey(Key.MediaPlayPause.keyCode)
            )
        ),
//        ShortcutActionDefinition(
//            id = ShortcutActionId.StopPlayback,
//            title = "停止播放",
//            category = ShortcutCategory.Playback,
//            defaultBinding = ShortcutBinding(
//                primary = ShortcutKey(Key.MediaStop.keyCode)
//            )
//        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.Mute,
            title = "静音/取消静音",
            category = ShortcutCategory.Playback,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.M.keyCode),
                secondary = ShortcutKey(Key.VolumeMute.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.SeekBackward,
            title = "快退 10 秒",
            category = ShortcutCategory.Playback,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.DirectionLeft.keyCode),
                secondary = ShortcutKey(Key.MediaStepBackward.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.SeekForward,
            title = "快进 10 秒",
            category = ShortcutCategory.Playback,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.DirectionRight.keyCode),
                secondary = ShortcutKey(Key.MediaStepForward.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.VolumeUp,
            title = "音量增加",
            category = ShortcutCategory.Playback,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.DirectionUp.keyCode),
                secondary = ShortcutKey(Key.VolumeUp.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.VolumeDown,
            title = "音量减少",
            category = ShortcutCategory.Playback,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.DirectionDown.keyCode),
                secondary = ShortcutKey(Key.VolumeDown.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.ToggleFullscreen,
            title = "切换全屏",
            category = ShortcutCategory.Playback,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.F.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.ExitFullscreen,
            title = "退出全屏",
            category = ShortcutCategory.Playback,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.Escape.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.SearchNext,
            title = "下一个搜索项",
            category = ShortcutCategory.Search,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.DirectionDown.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.SearchPrev,
            title = "上一个搜索项",
            category = ShortcutCategory.Search,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.DirectionUp.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.SearchSelect,
            title = "选中搜索项",
            category = ShortcutCategory.Search,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.Enter.keyCode),
                secondary = ShortcutKey(Key.NumPadEnter.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.SearchSwitchTab,
            title = "切换搜索分类",
            category = ShortcutCategory.Search,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.Tab.keyCode)
            )
        ),
        ShortcutActionDefinition(
            id = ShortcutActionId.SearchExit,
            title = "退出搜索",
            category = ShortcutCategory.Search,
            defaultBinding = ShortcutBinding(
                primary = ShortcutKey(Key.Escape.keyCode)
            )
        )
    )

    private val definitionMap = definitions.associateBy { it.id }

    fun getBinding(actionId: ShortcutActionId): ShortcutBinding {
        val definition = definitionMap[actionId] ?: error("Unknown shortcut action: $actionId")
        val primaryRaw = settings.getString(scopedKey("${actionId.name}.primary"), "")
        val secondaryRaw = settings.getString(scopedKey("${actionId.name}.secondary"), "")
        val primary = ShortcutKey.fromStorageString(primaryRaw) ?: definition.defaultBinding.primary
        val secondary = ShortcutKey.fromStorageString(secondaryRaw) ?: definition.defaultBinding.secondary
        return ShortcutBinding(primary = primary, secondary = secondary)
    }

    fun getAllBindings(): Map<ShortcutActionId, ShortcutBinding> {
        return definitions.associate { it.id to getBinding(it.id) }
    }

    fun setBinding(actionId: ShortcutActionId, binding: ShortcutBinding) {
        settings[scopedKey("${actionId.name}.primary")] = binding.primary.toStorageString()
        val secondaryValue = binding.secondary?.toStorageString().orEmpty()
        settings[scopedKey("${actionId.name}.secondary")] = secondaryValue
    }

    fun resetToDefaults() {
        definitions.forEach { definition ->
            setBinding(definition.id, definition.defaultBinding)
        }
    }

    fun matches(event: KeyEvent, actionId: ShortcutActionId): Boolean {
        return getBinding(actionId).matches(event)
    }

    fun shouldSuppressFocusSearchInput(event: KeyEvent): Boolean {
        if (event.isCtrlPressed || event.isAltPressed || event.isMetaPressed) return false
        return isTextInputKey(event.key)
    }

    fun isMacPlatform(): Boolean {
        return currentPlatform().isMacOS()
    }

    private fun isTextInputKey(key: Key): Boolean {
        return when (key) {
            Key.Spacebar,
            Key.A, Key.B, Key.C, Key.D, Key.E, Key.F, Key.G, Key.H, Key.I, Key.J, Key.K, Key.L,
            Key.M, Key.N, Key.O, Key.P, Key.Q, Key.R, Key.S, Key.T, Key.U, Key.V, Key.W, Key.X,
            Key.Y, Key.Z,
            Key.Zero, Key.One, Key.Two, Key.Three, Key.Four, Key.Five, Key.Six, Key.Seven, Key.Eight, Key.Nine -> true
            else -> false
        }
    }
}
