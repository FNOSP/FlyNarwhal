package com.jankinwu.fntv.client.ui.window

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.BrushPainter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.utils.isSystemInDarkMode
import io.github.composefluent.ExperimentalFluentApi
import io.github.composefluent.FluentTheme
import io.github.composefluent.background.Mica
import io.github.composefluent.component.ProgressRing
import io.github.composefluent.component.ProgressRingSize
import io.github.composefluent.component.Text
import io.github.composefluent.darkColors
import io.github.composefluent.lightColors

/**
 * 美化的启动页
 */
@OptIn(ExperimentalFluentApi::class)
@Composable
fun SplashScreen(
    icon: Painter,
    title: String,
    error: Throwable? = null
) {
    val isDark = isSystemInDarkMode()
    val colors = if (isDark) darkColors() else lightColors()

    FluentTheme(colors = colors) {
        val gradient = if (isDark) {
            listOf(
                Color(0xff282C51),
                Color(0xff2A344A),
            )
        } else {
            listOf(
                Color(0xffB1D0ED),
                Color(0xffDAE3EC),
            )
        }

        Mica(
            background = {
                Image(
                    painter = BrushPainter(Brush.linearGradient(gradient)),
                    contentDescription = null,
                    contentScale = ContentScale.FillBounds
                )
            },
            modifier = Modifier.fillMaxSize()
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    // 应用图标
//                    Box(
//                        modifier = Modifier
//                            .size(80.dp)
//                            .shadow(8.dp, CircleShape)
//                            .clip(CircleShape)
//                            .background(Color.White),
//                        contentAlignment = Alignment.Center
//                    ) {
//                        Image(
//                            painter = icon,
//                            contentDescription = null,
//                            modifier = Modifier.size(56.dp)
//                        )
//                    }
//
//                    Spacer(modifier = Modifier.height(24.dp))

                    // 应用名称
                    Text(
                        text = title,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = FluentTheme.colors.text.text.primary
                    )

                    Spacer(modifier = Modifier.height(32.dp))

                    if (error != null) {
                        // 错误状态
                        Text(
                            text = "初始化失败",
                            fontSize = 14.sp,
                            color = Color.Red,
                            fontWeight = FontWeight.Medium
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = error.message ?: "未知错误",
                            fontSize = 12.sp,
                            color = FluentTheme.colors.text.text.secondary
                        )
                    } else {
                        // 加载状态
                        ProgressRing(
                            size = ProgressRingSize.Medium,
                            color = FluentTheme.colors.fillAccent.default
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "正在初始化组件...",
                            fontSize = 13.sp,
                            color = FluentTheme.colors.text.text.secondary
                        )
                    }
                }
            }
        }
    }
}
