package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import com.jankinwu.fntv.client.data.constants.Colors
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.ProgressRing
import io.github.composefluent.component.ProgressRingSize

@Composable
fun ImgLoadingProgressRing(modifier: Modifier = Modifier, size: Dp = ProgressRingSize.Medium) {
    Box(
        modifier = modifier
            .fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        ProgressRing(
            size = size,
            color = Colors.TextTertiaryColor
        )
    }
}