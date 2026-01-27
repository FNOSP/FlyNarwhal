package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import flynarwhal.composeapp.generated.resources.Res
import flynarwhal.composeapp.generated.resources.empty_folder
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.Text
import org.jetbrains.compose.resources.painterResource

@Composable
fun EmptyFolder(modifier: Modifier, text: String, imgSize: Dp = 110.dp) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Image(
                painter = painterResource(Res.drawable.empty_folder),
                contentDescription = null,
                modifier = Modifier
                    .size(imgSize)
                    .padding(bottom = 24.dp)
            )
            Text(
                text,
                fontSize = 14.sp,
                color = FluentTheme.colors.text.text.primary
            )
        }
    }
}
