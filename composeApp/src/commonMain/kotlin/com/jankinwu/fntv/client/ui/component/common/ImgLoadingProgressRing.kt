package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.ProgressRing
import io.github.composefluent.component.ProgressRingSize

@Composable
fun ImgLoadingProgressRing(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        ProgressRing(
            size = ProgressRingSize.Medium,
            color = FluentTheme.colors.text.text.tertiary
        )
    }
}