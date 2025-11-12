package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.LocalStore
import com.jankinwu.fntv.client.LocalTypography
import com.jankinwu.fntv.client.components
import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.Icon
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.filled.IosArrowRtl

/**
 * 媒体库 gallery
 *
 * @param modifier The modifier to be applied to the component.
 * @param movies 要展示的电影列表.
 */
@Suppress("UnusedBoxWithConstraintsScope")
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun MediaLibGallery(
    modifier: Modifier = Modifier,
    title: String,
    movies: List<ScrollRowItemData>,
    onFavoriteToggle: ((String, Boolean, (Boolean) -> Unit) -> Unit)? = null,
    onWatchedToggle: ((String, Boolean, (Boolean) -> Unit) -> Unit)? = null,
    navigator: ComponentNavigator,
    guid: String,
//    onMovieClick: ((String) -> Unit)? = null
) {
    val scaleFactor = LocalStore.current.scaleFactor
    // 设置媒体库画廊高度
    val mediaLibColumnHeight = (280 * scaleFactor).dp
    Column(
        modifier = modifier
            .height(mediaLibColumnHeight),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // 媒体库标题行
        Row(
            modifier = Modifier
                .padding(start = 32.dp, bottom = 12.dp)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {
                        // 在组件内部实现导航逻辑
                        val targetComponent = components
                            .firstOrNull { it.name == "媒体库" }
                            ?.items
                            ?.firstOrNull { it.guid == guid }

                        targetComponent?.let {
                            navigator.navigate(it)
                        }
                    }
                )
                .pointerHoverIcon(PointerIcon.Hand),
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
            Spacer(Modifier.width(4.dp))
            Icon(
                imageVector = Icons.Filled.IosArrowRtl,
                contentDescription = "View More",
                tint = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.requiredSize(11.dp)
            )
        }

        ScrollRow(movies) { _, movie, modifier, _ ->
            MoviePoster(
                modifier = modifier,
                title = movie.title,
                subtitle = movie.subtitle,
                score = movie.score,
                posterImg = movie.posterImg,
                isFavorite = movie.isFavourite,
                isAlreadyWatched = movie.isAlreadyWatched,
                resolutions = movie.resolutions,
                guid = movie.guid,
                onFavoriteToggle = onFavoriteToggle,
                onWatchedToggle = onWatchedToggle,
                posterWidth = movie.posterWidth,
                posterHeight = movie.posterHeight,
                status = movie.status,
                type = movie.type,
                navigator = navigator
            )
        }

    }
}