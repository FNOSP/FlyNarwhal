package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.ClickableText
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import androidx.compose.ui.window.PopupPositionProvider
import com.jankinwu.fntv.client.data.constants.Colors
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.Text
import kotlinx.coroutines.delay

@Composable
fun HoverTip(
    tipText: String,
    modifier: Modifier = Modifier,
    offset: IntOffset = IntOffset(0, -8),
    maxWidth: Dp = 300.dp,
) {
    val uriHandler = LocalUriHandler.current
    val iconInteractionSource = remember { MutableInteractionSource() }
    val popupInteractionSource = remember { MutableInteractionSource() }
    val iconHovered by iconInteractionSource.collectIsHoveredAsState()
    val popupHovered by popupInteractionSource.collectIsHoveredAsState()
    var visible by remember { mutableStateOf(false) }
    val annotatedTipText = remember(tipText) { buildUrlAnnotatedString(tipText) }

    LaunchedEffect(iconHovered, popupHovered) {
        if (iconHovered || popupHovered) {
            visible = true
        } else {
            delay(120)
            if (!iconHovered && !popupHovered) {
                visible = false
            }
        }
    }

    Box(modifier = modifier) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .border(
                    width = 1.dp,
                    color = FluentTheme.colors.stroke.control.default.copy(alpha = 0.25f),
                    shape = CircleShape
                )
                .background(Color.Transparent, CircleShape)
                .hoverable(iconInteractionSource)
                .pointerHoverIcon(PointerIcon.Hand),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "?",
                fontSize = 8.sp,
                modifier = Modifier.padding(bottom = 2.dp),
                style = FluentTheme.typography.caption,
                color = FluentTheme.colors.text.text.tertiary
            )
        }

        if (visible) {
            val positionProvider = remember(offset) {
                object : PopupPositionProvider {
                    override fun calculatePosition(
                        anchorBounds: IntRect,
                        windowSize: IntSize,
                        layoutDirection: LayoutDirection,
                        popupContentSize: IntSize
                    ): IntOffset {
                        val x = (anchorBounds.left + (anchorBounds.width - popupContentSize.width) / 2) + offset.x
                        val y = (anchorBounds.top - popupContentSize.height) + offset.y
                        val maxX = (windowSize.width - popupContentSize.width).coerceAtLeast(0)
                        val maxY = (windowSize.height - popupContentSize.height).coerceAtLeast(0)
                        return IntOffset(
                            x = x.coerceIn(0, maxX),
                            y = y.coerceIn(0, maxY)
                        )
                    }
                }
            }
            Popup(
                popupPositionProvider = positionProvider,
                properties = PopupProperties(
                    focusable = false,
                    clippingEnabled = false
                ),
                onDismissRequest = {
                    visible = false
                }
            ) {
                Box(
                    modifier = Modifier
                        .hoverable(popupInteractionSource)
                        .background(
                            color = FluentTheme.colors.background.mica.base,
                            shape = RoundedCornerShape(8.dp)
                        )
                        .border(
                            width = 1.dp,
                            color = FluentTheme.colors.stroke.control.default.copy(alpha = 0.25f),
                            shape = RoundedCornerShape(8.dp)
                        )
                        .padding(horizontal = 12.dp, vertical = 10.dp)
                        .widthIn(max = maxWidth)
                ) {
                    SelectionContainer {
                        LinkAwareClickableText(
                            annotatedText = annotatedTipText,
                            onOpenUrl = { uriHandler.openUri(it) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun LinkAwareClickableText(
    annotatedText: AnnotatedString,
    onOpenUrl: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var layoutResult by remember { mutableStateOf<TextLayoutResult?>(null) }
    var isLinkHovered by remember { mutableStateOf(false) }

    fun updateHoverState(positionOffset: Int?) {
        val currentLayout = layoutResult
        if (currentLayout == null || positionOffset == null) {
            isLinkHovered = false
            return
        }
        isLinkHovered = annotatedText
            .getStringAnnotations(tag = "URL", start = positionOffset, end = positionOffset)
            .isNotEmpty()
    }

    @OptIn(ExperimentalComposeUiApi::class)
    ClickableText(
        text = annotatedText,
        style = FluentTheme.typography.body.copy(color = FluentTheme.colors.text.text.primary),
        onTextLayout = { layoutResult = it },
        modifier = modifier
            .onPointerEvent(PointerEventType.Exit) { isLinkHovered = false }
            .onPointerEvent(PointerEventType.Enter) { event ->
                val currentLayout = layoutResult
                val position = event.changes.firstOrNull()?.position
                if (currentLayout == null || position == null) {
                    isLinkHovered = false
                } else {
                    updateHoverState(currentLayout.getOffsetForPosition(position))
                }
            }
            .onPointerEvent(PointerEventType.Move) { event ->
                val currentLayout = layoutResult
                val position = event.changes.firstOrNull()?.position
                if (currentLayout == null || position == null) {
                    isLinkHovered = false
                } else {
                    updateHoverState(currentLayout.getOffsetForPosition(position))
                }
            }
            .pointerHoverIcon(if (isLinkHovered) PointerIcon.Hand else PointerIcon.Default),
        onClick = { offset ->
            annotatedText
                .getStringAnnotations(tag = "URL", start = offset, end = offset)
                .firstOrNull()
                ?.let { onOpenUrl(it.item) }
        }
    )
}

private fun buildUrlAnnotatedString(text: String): AnnotatedString {
    val urlRegex = Regex("""https?://[^\s]+""")
    return buildAnnotatedString {
        var lastIndex = 0
        for (match in urlRegex.findAll(text)) {
            val start = match.range.first
            val endExclusive = match.range.last + 1
            if (start > lastIndex) {
                append(text.substring(lastIndex, start))
            }

            var url = text.substring(start, endExclusive)
            while (url.isNotEmpty() && url.last() in setOf('.', ',', ';', ':', ')', ']', '}', '!', '?')) {
                url = url.dropLast(1)
            }
            val trailing = text.substring(start + url.length, endExclusive)

            val linkStart = length
            append(url)
            val linkEnd = length
            addStringAnnotation(tag = "URL", annotation = url, start = linkStart, end = linkEnd)
            addStyle(
                style = SpanStyle(
                    color = Colors.AccentColorDefault,
                    textDecoration = TextDecoration.Underline
                ),
                start = linkStart,
                end = linkEnd
            )

            if (trailing.isNotEmpty()) {
                append(trailing)
            }
            lastIndex = endExclusive
        }
        if (lastIndex < text.length) {
            append(text.substring(lastIndex))
        }
    }
}
