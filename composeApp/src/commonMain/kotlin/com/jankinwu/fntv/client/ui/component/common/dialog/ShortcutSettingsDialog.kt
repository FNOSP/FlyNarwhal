package com.jankinwu.fntv.client.ui.component.common.dialog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.store.*
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.*

/**
 * Target for capturing a new shortcut key combination
 */
private data class ShortcutCaptureTarget(
    val actionId: ShortcutActionId,
    val isSecondary: Boolean
)

/**
 * Dialog component for configuring application keyboard shortcuts
 */
@Composable
fun ShortcutSettingsDialog(
    visible: Boolean,
    onDismiss: () -> Unit,
    guid: String
) {
    if (!visible) return

    // State for managing shortcut bindings and current capture target
    var shortcutBindings by remember(guid) { mutableStateOf(ShortcutSettingsStore.getAllBindings()) }
    var captureTarget by remember { mutableStateOf<ShortcutCaptureTarget?>(null) }
    val isMac = ShortcutSettingsStore.isMacPlatform()

    // Reset state when dialog visibility or user GUID changes
    LaunchedEffect(visible, guid) {
        if (visible) {
            shortcutBindings = ShortcutSettingsStore.getAllBindings()
            captureTarget = null
        }
    }

    FluentDialog(
        visible = true,
        size = DialogSize.Standard
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp)
                .onPreviewKeyEvent { event ->
                    // Handle key events when capturing a new shortcut
                    if (event.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                    val target = captureTarget ?: return@onPreviewKeyEvent false

                    // Escape cancels the capture
//                    if (event.key == Key.Escape) {
//                        captureTarget = null
//                        return@onPreviewKeyEvent true
//                    }

                    // Update shortcut binding with the pressed key
                    val shortcutKey =
                        ShortcutKey.fromKeyEvent(event) ?: return@onPreviewKeyEvent true
                    val currentBinding = shortcutBindings[target.actionId]
                        ?: ShortcutSettingsStore.getBinding(target.actionId)
                    val updatedBinding =
                        ShortcutBinding(primary = shortcutKey, secondary = currentBinding.secondary)

                    ShortcutSettingsStore.setBinding(target.actionId, updatedBinding)
                    shortcutBindings = shortcutBindings.toMutableMap()
                        .apply { put(target.actionId, updatedBinding) }
                    captureTarget = null
                    true
                }
        ) {
            Text("快捷键设置", style = FluentTheme.typography.subtitle)
            Spacer(Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "说明",
                    style = FluentTheme.typography.bodyStrong,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    "快捷键",
                    style = FluentTheme.typography.bodyStrong,
                    modifier = Modifier.width(140.dp)
                )
            }

            // Scrollable list of shortcut settings
            val shortcutScrollState = rememberScrollState()
            ScrollbarContainer(
                adapter = rememberScrollbarAdapter(shortcutScrollState),
                scrollbar = {
                    Scrollbar(
                        true,
                        rememberScrollbarAdapter(shortcutScrollState),
                        modifier = Modifier.offset(x = 20.dp)
                    )
                },
                modifier = Modifier.weight(1f, fill = false).heightIn(max = 400.dp)
            ) {
                Column(modifier = Modifier.verticalScroll(shortcutScrollState)) {
                    val definitionsByCategory =
                        ShortcutSettingsStore.definitions.groupBy { it.category }
                    listOf(ShortcutCategory.Search, ShortcutCategory.Playback).forEach { category ->
                        val categoryTitle = when (category) {
                            ShortcutCategory.Search -> "搜索"
                            ShortcutCategory.Playback -> "播放"
                        }
                        Text(categoryTitle, style = FluentTheme.typography.bodyStrong)
                        Spacer(Modifier.height(8.dp))

                        definitionsByCategory[category].orEmpty().forEach { definition ->
                            val binding =
                                shortcutBindings[definition.id] ?: definition.defaultBinding
                            val isCapturing = captureTarget?.actionId == definition.id

                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(definition.title, modifier = Modifier.weight(1f))

                                // Shortcut display and capture trigger area
                                Box(
                                    modifier = Modifier
                                        .width(200.dp)
                                        .height(32.dp)
                                        .border(
                                            1.dp,
                                            if (isCapturing) Colors.AccentColorDefault else FluentTheme.colors.stroke.control.default,
                                            RoundedCornerShape(4.dp)
                                        )
                                        .background(
                                            FluentTheme.colors.control.default,
                                            RoundedCornerShape(4.dp)
                                        )
                                        .clickable {
                                            captureTarget =
                                                ShortcutCaptureTarget(definition.id, false)
                                        }
                                        .pointerHoverIcon(PointerIcon.Hand),
                                    contentAlignment = Alignment.CenterStart
                                ) {
                                    val text =
                                        if (isCapturing) "请在键盘按下快捷键或组合" else binding.primary.format(
                                            isMac
                                        )
                                    Text(
                                        text = text,
                                        modifier = Modifier.padding(horizontal = 8.dp),
                                        style = FluentTheme.typography.body,
                                        maxLines = 1,
                                        color = if (isCapturing) FluentTheme.colors.text.text.tertiary else FluentTheme.colors.text.text.primary
                                    )
                                }
                            }
                        }
                        Spacer(Modifier.height(12.dp))
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
            Row(
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                DialogSecondaryButton("恢复默认", onClick = {
                    ShortcutSettingsStore.resetToDefaults()
                    shortcutBindings = ShortcutSettingsStore.getAllBindings()
                    captureTarget = null
                })
                Spacer(Modifier.width(8.dp))
                DialogAccentButton("确定", onClick = {
                    onDismiss()
                    captureTarget = null
                })
            }
        }
    }
}
