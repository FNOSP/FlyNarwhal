package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.PlatformContext
import coil3.compose.SubcomposeAsyncImage
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.crossfade
import com.jankinwu.fntv.client.LocalStore
import com.jankinwu.fntv.client.LocalTypography
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.data.store.AccountDataCache
import io.github.composefluent.FluentTheme

/**
 * 一个可重用的媒体库卡片组件，用于展示拼接的海报、倒影和标题。
 *
 * @param posters 要展示的海报 Painter 列表。最多会显示前4张。
 * @param title 媒体库的标题，会显示在下方的半透明遮罩上。
 * @param modifier 应用于此组件的 Modifier。
 * @param cornerRadius 卡片的圆角半径。
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun MediaLibraryCard(
    modifier: Modifier = Modifier,
    posters: List<String>? = listOf(),
    title: String,
    cornerRadius: Dp = 12.dp,
) {
    // 最多取前4张海报
    val visiblePosters = posters?.take(4)
    val posterCount = visiblePosters?.size

    // 如果没有海报，则不显示任何内容
    if (posterCount == 0) return

    Box(
        modifier = modifier
            .fillMaxHeight()
            .aspectRatio(3f / 2f)
            .background(Color.Transparent, RoundedCornerShape(cornerRadius))
            .clip(RoundedCornerShape(cornerRadius))
            .border(1.dp, Color.Gray.copy(alpha = 0.5f), RoundedCornerShape(cornerRadius))
            .pointerHoverIcon(PointerIcon.Hand),
    ) {
        var isPosterHovered by remember { mutableStateOf(false) }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .onPointerEvent(PointerEventType.Enter) { isPosterHovered = true }
                .onPointerEvent(PointerEventType.Exit) { isPosterHovered = false },
            contentAlignment = Alignment.Center
        ) {
            // 包含上半部分图片和下半部分倒影的列布局
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(4.dp)
                    .background(
                        FluentTheme.colors.stroke.control.secondary.copy(alpha = 0.07f),
                        RoundedCornerShape(cornerRadius - 2.dp)
                    )
                    .clip(RoundedCornerShape(cornerRadius - 2.dp))
            ) {
                // 上半部分: 原始海报行
                PosterRow(
                    posters = visiblePosters,
                    modifier = Modifier
                        .weight(0.7f),
                )
                // 下半部分: 垂直翻转的海报行 (倒影)
                Box(
                    modifier = Modifier
                        .weight(0.3f)
                ) {
                    PosterRow(
                        posters = visiblePosters,
                        modifier = Modifier
                            .fillMaxSize()
                            .graphicsLayer {
                                // 沿Y轴缩放-1倍以实现垂直翻转
                                scaleY = -1f
                            }
                    )
                }
            }

            // 位于下半部分的半透明遮罩和标题
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .fillMaxHeight(0.31f)
                    .background(FluentTheme.colors.controlOnImage.default.copy(alpha = 0.9f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = title,
                    style = LocalTypography.current.caption,
                    color = FluentTheme.colors.text.text.primary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Normal
                )
            }
            // 半透明遮罩层
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFF1C1C1C).copy(alpha = if (isPosterHovered) 0.5f else 0f))
            )
        }
    }
}

/**
 * 水平拼接的海报组件
 */
@Composable
private fun PosterRow(posters: List<String>?, modifier: Modifier = Modifier) {
    val store = LocalStore.current
    val visiblePosters = posters?.take(4) ?: emptyList()
    val posterCount = visiblePosters.size

    if (posterCount == 0) return

    Box(
        modifier = modifier
            .clip(RectangleShape)
            .fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Row(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth(posterCount * 0.25f) // 每张海报占25%宽度，根据实际数量计算总宽度
        ) {
            visiblePosters.forEach { poster ->
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                ) {
                    SubcomposeAsyncImage(
                        model = ImageRequest.Builder(PlatformContext.INSTANCE)
                            .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img$poster${Constants.FN_IMG_URL_PARAM}")
                            .httpHeaders(store.fnImgHeaders)
                            .crossfade(true)
                            .build(),
                        contentDescription = null,
                        modifier = Modifier
                            .fillMaxSize()
                            .align(Alignment.Center),
                        contentScale = ContentScale.Crop,
                        onError = { result -> },
                        onLoading = {
//                            println("图片加载中...")
                        },
                        loading = {
                            ImgLoadingProgressRing(modifier = Modifier.fillMaxSize())
                        },
                        error = {
                            ImgLoadingError()
                        },
                    )
                }
            }
        }
    }
}