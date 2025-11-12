package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.PlatformContext
import coil3.compose.SubcomposeAsyncImage
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.crossfade
import com.jankinwu.fntv.client.LocalStore
import com.jankinwu.fntv.client.LocalTypography
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.Delete
import com.jankinwu.fntv.client.icons.Edit
import com.jankinwu.fntv.client.icons.HeartFilled
import com.jankinwu.fntv.client.icons.Lifted
import com.jankinwu.fntv.client.ui.screen.LocalMediaPlayer
import com.jankinwu.fntv.client.ui.screen.MovieDetailScreen
import com.jankinwu.fntv.client.ui.screen.rememberPlayMediaFunction
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.FlyoutPlacement
import io.github.composefluent.component.MenuFlyoutContainer
import io.github.composefluent.component.MenuFlyoutItem
import io.github.composefluent.component.MenuFlyoutSeparator
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Checkmark
import io.github.composefluent.icons.regular.MoreHorizontal
import io.github.composefluent.icons.regular.PlayCircle

/**
 * 电影海报组件
 *
 * @param modifier The modifier to be applied to the component.
 * @param title 电影标题 (第一行文字)
 * @param subtitle 电影副标题或描述 (第二行文字)
 * @param score 电影评分
 * @param posterImg 海报图片地址
 * @param isFavorite 是否已收藏
 * @param isAlreadyWatched 是否已观看
 * @param resolutions 视频分辨率, 如 "4K", "1080p"
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun MoviePoster(
    modifier: Modifier = Modifier,
    title: String,
    subtitle: String?,
    score: String?,
    posterImg: String?,
    isFavorite: Boolean = false,
    isAlreadyWatched: Boolean = false,
    resolutions: List<String>? = listOf(),
    guid: String,
    onFavoriteToggle: ((String, Boolean, (Boolean) -> Unit) -> Unit)? = null,
    onWatchedToggle: ((String, Boolean, (Boolean) -> Unit) -> Unit)? = null,
    posterWidth: Int = 0,
    posterHeight: Int = 0,
    status: String? = "",
    navigator: ComponentNavigator,
    type: String?
) {
    val store = LocalStore.current

    val scaleFactor = store.scaleFactor
    var isPosterHovered by remember { mutableStateOf(false) }
    var isPlayButtonHovered by remember { mutableStateOf(false) }

    var normalPlayButtonSize by remember(scaleFactor) { mutableStateOf((48 * scaleFactor).dp) }
    var hoveredPlayButtonSize by remember(scaleFactor) { mutableStateOf((56 * scaleFactor).dp) }
    // 播放按钮动画大小状态
    val playButtonSize by animateDpAsState(
        targetValue = if (isPlayButtonHovered) hoveredPlayButtonSize else normalPlayButtonSize,
        animationSpec = tween(durationMillis = 200),
        label = "playButtonSize"
    )
    // 收藏状态
    var isFavorite by remember(isFavorite) { mutableStateOf(isFavorite) }
    var isAlreadyWatched by remember(isAlreadyWatched) { mutableStateOf(isAlreadyWatched) }
    var imageContainerWidthPx by remember { mutableIntStateOf(0) }
    val interactionSource = remember { MutableInteractionSource() }
    Column(
        modifier = modifier
            .fillMaxHeight()
            .onPointerEvent(PointerEventType.Enter) { isPosterHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isPosterHovered = false }
            .clickable(
                interactionSource = interactionSource,
                indication = null, // 移除点击波纹效果
                onClick = {
                    if (type == FnTvMediaType.MOVIE.value) {
                        // 创建电影详情页面组件并导航到该页面
                        val movieDetailComponent = ComponentItem(
                            name = "电影详情",
                            group = "/详情",
                            description = "电影详情页面",
                            guid = "movie_detail_$guid",
                            content = { nav ->
                                MovieDetailScreen(
                                    guid = guid,
                                    navigator = nav
                                )
                            }
                        )
                        navigator.navigate(movieDetailComponent)
                    }
                }
            )
            .pointerHoverIcon(PointerIcon.Hand),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {

        // 海报图片和覆盖层的容器
        Box(
            modifier = Modifier
                .aspectRatio(2f / 3f)
                .weight(1f)
                .border(1.dp, Color.Gray.copy(alpha = 0.5f), RoundedCornerShape((8 * scaleFactor).dp))
                .clip(RoundedCornerShape((8 * scaleFactor).dp))
                .onSizeChanged { size ->
                    imageContainerWidthPx = size.width
                }
        ) {
            if (posterImg != null) {
                val widthGtHeight = posterWidth > posterHeight
                SubcomposeAsyncImage(
                    model = ImageRequest.Builder(PlatformContext.INSTANCE)
                        .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img$posterImg${Constants.FN_IMG_URL_PARAM}")
                        .httpHeaders(store.fnImgHeaders)
                        .crossfade(true)
                        .build(),
                    contentDescription = title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = if (widthGtHeight) ContentScale.Fit else ContentScale.Crop,
                    loading = {
                        ImgLoadingProgressRing()
                    },
                    error = {
                        ImgLoadingError()
                    },
                )
            } else {
                ImgNotMapped()
            }

            // 左上角评分
            score?.let {
                if (score != "0.0") {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .padding(4.dp)
                            .background(
                                color = Color.Black.copy(alpha = 0.5f),
                                shape = RoundedCornerShape((4 * scaleFactor).dp)
                            )
                            .padding(horizontal = 4.dp, vertical = 2.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = score,
                            color = Color(0xFFFBBF24), // 黄色
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
            // 底部渐变遮罩层
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height((with(LocalDensity.current) {
                        (2f / 3f * imageContainerWidthPx).toDp() / 2
                    }))
                    .background(
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                Color(0xFF1C1C1C).copy(alpha = if (isPosterHovered) 0f else 0.8f),
                                Color.Transparent
                            ),
                            startY = Float.POSITIVE_INFINITY,
                            endY = 0f
                        )
                    )
                    .alpha(if (isPosterHovered) 0f else 1f)
            )
            // 右下角分辨率
            resolutions?.let {
                Row(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(end = (6 * scaleFactor).dp, bottom = (6 * scaleFactor).dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(
                        space = (4 * scaleFactor).dp,
                        alignment = Alignment.End
                    )
                ) {

                    for ((_, resolution) in it.withIndex()) {
                        if (resolution.endsWith("k")) {
                            Box(
                                modifier = Modifier
                                    .alpha(if (isPosterHovered) 0f else 1f)
                                    //                                .align(Alignment.BottomEnd)
                                    //                                .padding((8 * scaleFactor).dp)
                                    .background(
                                        color = Color.White.copy(alpha = 0.8f),
                                        shape = RoundedCornerShape((3 * scaleFactor).dp)
                                    )
                                    .padding(
                                        horizontal = (6 * scaleFactor).dp,
                                        vertical = (1 * scaleFactor).dp
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = resolution.uppercase(),
                                    color = Color.Black.copy(alpha = 0.6f),
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.ExtraBold
                                )
                            }
                        } else {
                            Box(
                                modifier = Modifier
                                    .alpha(if (isPosterHovered) 0f else 1f)
                                    //                                .align(Alignment.BottomEnd)
                                    //                                .padding((8 * scaleFactor).dp)
                                    .border(
                                        2.dp,
                                        Color.White.copy(alpha = 0.6f),
                                        RoundedCornerShape((3 * scaleFactor).dp)
                                    )
                                    .padding(
                                        horizontal = (3 * scaleFactor).dp,
                                        vertical = (1 * scaleFactor).dp
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = resolution.dropLast(1),
                                    color = Color.White.copy(alpha = 0.6f),
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }
            }

            // 半透明遮罩层
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFF1C1C1C).copy(alpha = if (isPosterHovered) 0.5f else 0f))
                    .alpha(if (isPosterHovered) 1f else 0f)
            )
            val player = LocalMediaPlayer.current
            val playMedia = rememberPlayMediaFunction(
                guid = guid,
                player = player,
            )
            // 播放按钮
            Icon(
                imageVector = Icons.Regular.PlayCircle,
                contentDescription = "Play",
                tint = Color.White,
                modifier = Modifier
                    .align(Alignment.Center)
                    .size(playButtonSize)
                    .alpha(if (isPosterHovered) 1f else 0f)
                    .onPointerEvent(PointerEventType.Enter) { isPlayButtonHovered = true }
                    .onPointerEvent(PointerEventType.Exit) { isPlayButtonHovered = false }
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) {
                        playMedia()
                    }
            )

            // 标记为已观看按钮
            BottomIconButton(
                modifier = Modifier
                    .alpha(if (isPosterHovered) 1f else 0f)
                    .padding((8 * scaleFactor).dp)
                    .align(Alignment.BottomStart),
                icon = Icons.Regular.Checkmark,
                contentDescription = "alreadyWatched",
                onClick = {
                    onWatchedToggle?.invoke(guid, isAlreadyWatched) { success ->
                        isAlreadyWatched = if (!success) {
                            isAlreadyWatched
                        } else {
                            !isAlreadyWatched
                        }
                    }
                },
                scaleFactor = scaleFactor,
                iconTint = if (isAlreadyWatched) Colors.PrimaryColor else Color.White
            )

            // 收藏按钮
            BottomIconButton(
                modifier = Modifier
                    .alpha(if (isPosterHovered) 1f else 0f)
                    .padding((8 * scaleFactor).dp)
                    .align(Alignment.BottomCenter),
                icon = HeartFilled,
                contentDescription = "collection",
                onClick = {
                    onFavoriteToggle?.invoke(guid, isFavorite) { success ->
                        isFavorite = if (!success) {
                            isFavorite
                        } else {
                            !isFavorite
                        }
                    }
                },
                scaleFactor = scaleFactor,
                iconTint = if (isFavorite) Colors.DangerColor else Color.White
            )

            Box(
                modifier = Modifier
                    .alpha(if (isPosterHovered) 1f else 0f)
                    .padding((8 * scaleFactor).dp)
                    .align(Alignment.BottomEnd)
            ) {
                MenuFlyoutContainer(
                    flyout = {
                        MenuFlyoutItem(
                            text = {
                                Text(
                                    "手动匹配影片",
                                    fontSize = (12 * scaleFactor).sp,
                                    fontWeight = FontWeight.Bold,
                                    color = FluentTheme.colors.text.text.tertiary
                                )
                            },
                            onClick = {
                                isFlyoutVisible = false
                                // TODO: 处理手动匹配影片按钮点击事件
                            },
                            icon = {
                                Icon(
                                    Edit,
                                    contentDescription = "手动匹配影片",
                                    tint = FluentTheme.colors.text.text.tertiary,
                                    modifier = Modifier.requiredSize((20 * scaleFactor).dp)
                                )
                            })
                        MenuFlyoutItem(
                            text = {
                                Text(
                                    "解除匹配影片",
                                    fontSize = (12 * scaleFactor).sp,
                                    fontWeight = FontWeight.Bold,
                                    color = FluentTheme.colors.text.text.tertiary
                                )
                            },
                            onClick = {
                                isFlyoutVisible = false
                                // TODO: 处理解除匹配影片按钮点击事件
                            },
                            icon = {
                                Icon(
                                    Lifted,
                                    tint = FluentTheme.colors.text.text.tertiary,
                                    contentDescription = "解除匹配影片",
                                    modifier = Modifier.requiredSize((20 * scaleFactor).dp)
                                )
                            })
                        MenuFlyoutSeparator(modifier = Modifier.padding(horizontal = 1.dp))
                        MenuFlyoutItem(
                            text = {
                                Text(
                                    "删除",
                                    fontSize = (12 * scaleFactor).sp,
                                    color = FluentTheme.colors.text.text.tertiary,
                                    fontWeight = FontWeight.Bold,
                                )
                            },
                            onClick = {
                                isFlyoutVisible = false
                                // TODO: 处理删除按钮点击事件
                            },
                            icon = {
                                Icon(
                                    Delete,
                                    tint = FluentTheme.colors.text.text.tertiary,
                                    contentDescription = "删除",
                                    modifier = Modifier.requiredSize((20 * scaleFactor).dp)
                                )
                            })
                    },
                    content = {
                        BottomIconButton(
                            icon = Icons.Regular.MoreHorizontal,
                            contentDescription = "more",
                            onClick = {
                                isFlyoutVisible = !isFlyoutVisible
                            },
                            scaleFactor = scaleFactor
                        )
                    },
                    adaptivePlacement = true,
                    placement = FlyoutPlacement.BottomAlignedEnd
                )
            }

        }

        // 图片下方的间距
        Spacer(Modifier.height((8 * scaleFactor).dp))
        val textContainerWidthDp = with(LocalDensity.current) { imageContainerWidthPx.toDp() }
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = if (textContainerWidthDp > 0.dp) {
                Modifier.width(textContainerWidthDp)
            } else {
                Modifier.fillMaxWidth()
            }
        ) {
            // 电影标题
            Text(
                text = title,
                style = LocalTypography.current.caption,
                fontWeight = FontWeight.Normal,
                fontSize = (12 * scaleFactor).sp,
                textAlign = TextAlign.Center,
                color = if (isPosterHovered) Color(0xFF2073DF) else FluentTheme.colors.text.text.primary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height((4 * scaleFactor).dp))
            // 副标题/描述
            subtitle?.let {
                Text(
                    text = it,
                    style = LocalTypography.current.subtitle,
                    fontSize = (12 * scaleFactor).sp,
                    textAlign = TextAlign.Center,
                    color = FluentTheme.colors.text.text.tertiary
                )
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
internal fun BottomIconButton(
    modifier: Modifier = Modifier,
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    scaleFactor: Float,
    iconTint: Color = Color.White
) {
    var isHovered by remember { mutableStateOf(false) }
    Box(
        modifier = modifier
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = { onClick() }
            )
    ) {
        // 悬停时显示的圆形背景
        Box(
            modifier = Modifier
                .size((24 * scaleFactor).dp)
                .align(Alignment.Center)
                .background(
                    color = if (isHovered) Color.Gray.copy(alpha = 0.6f) else Color.Transparent,
                    shape = CircleShape
                )
        )

        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = iconTint,
            modifier = Modifier
                .size((16 * scaleFactor).dp)
                .align(Alignment.Center)
        )
    }
}