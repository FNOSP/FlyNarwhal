package com.jankinwu.fntv.client.ui.component.common

import androidx.annotation.FloatRange
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.placeholder_error
import io.github.composefluent.FluentTheme
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource

@Composable
fun ImgLoadingError(
    modifier: Modifier = Modifier,
    resource: DrawableResource = Res.drawable.placeholder_error,
    @FloatRange(from = 0.0, to = 1.0) fraction: Float = 0.5f
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FluentTheme.colors.stroke.control.secondary.copy(alpha = 0.07f)),
        contentAlignment = Alignment.Center
    ) {
        Image(
            painterResource(resource),
            contentDescription = "加载失败占位图",
            modifier = Modifier
                .fillMaxSize(fraction)
        )
    }
}