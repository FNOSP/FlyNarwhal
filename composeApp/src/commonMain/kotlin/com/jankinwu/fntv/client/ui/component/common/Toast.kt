package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.icons.Completed
import com.jankinwu.fntv.client.icons.Warning
import io.github.composefluent.FluentTheme
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

data class ToastMessage(
    val id: String = UUID.randomUUID().toString(), // 唯一标识符
    val message: String, // 提示文字
    val duration: Long = 2000L, // 显示时长（毫秒）
    val isSuccess: Boolean = true
)

@Composable
fun Toast(
    message: String,
    isSuccess: Boolean = true,
    duration: Long = 2000L,
    onDismiss: () -> Unit
) {
    var isVisible by remember { mutableStateOf(true) }
    val alpha = remember { Animatable(0f) }
    val offsetY = remember { Animatable((-50f)) } // 初始位置在上方

    LaunchedEffect(Unit) {
        // 同时执行淡入和下移动画
        coroutineScope {
            launch {
                alpha.animateTo(
                    targetValue = 1f,
                    animationSpec = tween(durationMillis = 300)
                )
            }

            launch {
                offsetY.animateTo(
                    targetValue = 0f,
                    animationSpec = tween(durationMillis = 300)
                )
            }
        }

        // 等待指定时长
        delay(duration)

        // 同时执行淡出和上移动画
        coroutineScope {
            launch {
                alpha.animateTo(
                    targetValue = 0f,
                    animationSpec = tween(durationMillis = 300)
                )
            }

            launch {
                offsetY.animateTo(
                    targetValue = (-50f),
                    animationSpec = tween(durationMillis = 300)
                )
            }
        }

        // 动画结束后通知消失
        isVisible = false
        onDismiss()
    }

    if (isVisible) {
        Box(
            modifier = Modifier
                .offset(y = offsetY.value.dp) // 应用垂直偏移动画
                .alpha(alpha.value) // 应用透明度动画
                .background(
                    color = FluentTheme.colors.controlSolid.default,
                    shape = RoundedCornerShape(6.dp)
                )
                .padding(start = 10.dp, end = 15.dp, top = 8.dp, bottom = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            Row(
                modifier = Modifier
                    .align(Alignment.Center),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = if (isSuccess) Completed else Warning,
                    contentDescription = null,
                    tint = if (isSuccess) Color(0xFF5BA85A) else Color(0xFFFF0421),
                    modifier = Modifier
                        .size(28.dp)
                        .padding(end = 8.dp)
                )

                Text(
                    text = message,
                    style = TextStyle(
                        color = FluentTheme.colors.text.text.primary,
                        fontSize = 14.sp
                    )
                )
            }
        }
    }
}