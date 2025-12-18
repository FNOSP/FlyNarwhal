package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.icons.ArrowLeft
import io.github.composefluent.component.Icon

@Composable
fun BackButton(
    navigator: ComponentNavigator,
    modifier: Modifier = Modifier,
    iconColor: Color = Color.White,
    hasShadow: Boolean = true
) {
    Box(
        modifier = modifier
            .padding(16.dp)
    ) {
        IconButton(
            onClick = { navigator.navigateUp() },
            modifier = Modifier
                .drawBehind {
                    if (hasShadow) {
                        drawCircle(
                            brush = Brush.radialGradient(
                                colors = listOf(
                                    Color.Black.copy(alpha = 0.2f),
                                    Color.Black.copy(alpha = 0.15f),
                                    Color.Black.copy(alpha = 0.1f),
                                    Color.Black.copy(alpha = 0.01f),
                                    Color.Transparent
                                ),
                                radius = size.minDimension / 1.7f,
                                center = center
                            )
                        )
                    }
                }
                .pointerHoverIcon(PointerIcon.Hand)
        ) {
            Icon(
                imageVector = ArrowLeft,
                contentDescription = "返回",
                tint = iconColor,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}