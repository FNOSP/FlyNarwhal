package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun SkipOutroPrompt(
    countdown: Int,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
    ) {
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = Color(0xFF2B2B2B).copy(alpha = 0.9f),
            contentColor = Color.White
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${countdown}s 后将自动跳过片尾并播放下集",
                    fontSize = 14.sp
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "取消跳过",
                    color = Color(0xFF3B82F6),
                    fontSize = 14.sp,
                    modifier = Modifier.clickable {
                        onCancel()
                    }
                )
            }
        }
    }
}

@Composable
fun SkipIntroPrompt(
    countdown: Int,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
    ) {
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = Color(0xFF2B2B2B).copy(alpha = 0.9f),
            contentColor = Color.White
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "已跳过片头，${countdown}s 后关闭提示",
                    fontSize = 14.sp
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "取消跳过",
                    color = Color(0xFF3B82F6),
                    fontSize = 14.sp,
                    modifier = Modifier.clickable {
                        onCancel()
                    }
                )
            }
        }
    }
}