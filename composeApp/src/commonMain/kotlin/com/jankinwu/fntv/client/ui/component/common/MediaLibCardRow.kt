package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.LocalStore
import com.jankinwu.fntv.client.LocalTypography
import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import io.github.composefluent.FluentTheme

@Composable
fun MediaLibCardRow(
    mediaLibs: List<ScrollRowItemData>,
    title: String,
    modifier: Modifier = Modifier,
    onItemClick: ((ScrollRowItemData) -> Unit)? = null,
) {
    val scaleFactor = LocalStore.current.scaleFactor
    // 设置媒体库卡片行高度
    val mediaLibCardColumnHeight = (160 * scaleFactor).dp

    Column(
        modifier = modifier
            .height(mediaLibCardColumnHeight),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            modifier = Modifier
                .padding(start = 32.dp, bottom = 12.dp)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = { /* TODO: Handle navigation for this category */ }
                ),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                style = LocalTypography.current.title.copy(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold
                ),
                color = FluentTheme.colors.text.text.tertiary
            )
        }

        ScrollRow(mediaLibs, listState = rememberLazyListState(),{ _, mediaLib, modifier, _ ->
            val interactionSource = remember { MutableInteractionSource() }
            MediaLibraryCard(
                title = mediaLib.title,
                posters = mediaLib.posters,
                modifier = modifier.clickable(
                    enabled = onItemClick != null,
                    interactionSource = interactionSource,
                    indication = null,
                    onClick = { onItemClick?.invoke(mediaLib) }
                )
            )
        })

    }
}