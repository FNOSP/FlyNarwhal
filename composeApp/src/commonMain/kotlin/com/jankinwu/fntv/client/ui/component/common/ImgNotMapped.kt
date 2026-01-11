package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import flynarwhal.composeapp.generated.resources.Res
import flynarwhal.composeapp.generated.resources.placeholder_not_mapped
import io.github.composefluent.FluentTheme
import org.jetbrains.compose.resources.painterResource

@Composable
fun ImgNotMapped(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FluentTheme.colors.stroke.control.secondary.copy(alpha = 0.07f)),
        contentAlignment = Alignment.Center
    ) {
        Image(
            painterResource(Res.drawable.placeholder_not_mapped),
            contentDescription = "加载失败占位图",
            modifier = Modifier.fillMaxSize(0.5f)
        )
    }
}