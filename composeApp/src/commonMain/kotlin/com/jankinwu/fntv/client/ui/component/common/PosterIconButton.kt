package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalComposeUiApi::class)
@Composable
internal fun BottomIconButton(
    modifier: Modifier = Modifier,
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit =  {},
    scaleFactor: Float,
    iconTint: Color = Color.White,
    iconYOffset: Dp = 0.dp
) {
    var isHovered by remember { mutableStateOf(false) }
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = { onClick() }
            )
    ) {
        // 悬停时显示的圆形背景
        Box(
            modifier = Modifier
                .size((28 * scaleFactor).dp)
                .align(Alignment.Center)
                .background(
                    color = if (isHovered) Color.Black.copy(alpha = 0.5f) else Color.Transparent,
                    shape = CircleShape
                )
        )

        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = iconTint,
            modifier = Modifier
                .size((16 * scaleFactor).dp)
                .offset(y = iconYOffset)
                .align(Alignment.Center)
        )
    }
}