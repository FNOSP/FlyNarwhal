package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkHorizontally
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
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
import androidx.compose.ui.graphics.Color
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
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.HeartFilled
import com.jankinwu.fntv.client.ui.component.common.dialog.VersionManagementDialog
import com.jankinwu.fntv.client.ui.providable.LocalMediaPlayer
import com.jankinwu.fntv.client.ui.screen.MovieDetailScreen
import com.jankinwu.fntv.client.ui.screen.rememberPlayMediaFunction
import io.github.composefluent.FluentTheme
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Checkmark
import io.github.composefluent.icons.regular.MoreHorizontal
import io.github.composefluent.icons.regular.PlayCircle
import kotlinx.coroutines.delay
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.ui.screen.TvSeasonDetailScreen

/**
 * 最近观看
 *
 * @param modifier The modifier to be applied to the component.
 * @param movies 要展示的电影列表.
 */
@Suppress("UnusedBoxWithConstraintsScope")
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun RecentlyWatched(
    modifier: Modifier = Modifier,
    title: String,
    movies: List<ScrollRowItemData>,
    recentlyWatchedListState: LazyListState,
    onFavoriteToggle: ((String, Boolean, (Boolean) -> Unit) -> Unit)? = null,
    onWatchedToggle: ((String, Boolean, (Boolean) -> Unit) -> Unit)? = null,
    onItemRemoved: ((String) -> Unit)? = null,
    navigator: ComponentNavigator
) {
    val scaleFactor = LocalStore.current.scaleFactor
    // 设置高度
    val mediaLibColumnHeight = (190 * scaleFactor).dp

    // 当电影列表改变时，重置滚动位置到初始位置
    LaunchedEffect(movies) {
        if (movies.isNotEmpty()) {
            recentlyWatchedListState.scrollToItem(0)
        }
    }

    Column(
        modifier = modifier
            .height(mediaLibColumnHeight),
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

        ScrollRow(
            itemsData = movies,
            listState = recentlyWatchedListState
        ) { index, movie, modifier, _ ->
            RecentlyWatchedItem(
                modifier = modifier,
                title = movie.title,
                subtitle = movie.subtitle,
                posterImg = movie.posterImg,
                isFavorite = movie.isFavourite,
                isAlreadyWatched = movie.isAlreadyWatched,
                duration = movie.duration,
                ts = movie.ts,
                guid = movie.guid,
                parentGuid = movie.parentGuid,
                onFavoriteToggle = onFavoriteToggle,
                onWatchedToggle = onWatchedToggle,
                onMarkAsWatched = {
                    // 当动画结束时，通知父组件移除该项目
                    onItemRemoved?.invoke(movie.guid)
                },
                status = movie.status,
                onClick = { movieGuid, parentGuid ->
                    if (movie.type == FnTvMediaType.MOVIE.value  || movie.type == FnTvMediaType.VIDEO.value) {
                        // 创建电影详情页面组件并导航到该页面
                        val movieDetailComponent = ComponentItem(
                            name = "电影详情",
                            group = "/详情",
                            description = "电影详情页面",
                            guid = "movie_detail_$movieGuid",
                            content = { nav ->
                                MovieDetailScreen(
                                    guid = movieGuid,
                                    navigator = nav
                                )
                            }
                        )
                        navigator.navigate(movieDetailComponent)
                    } else if (movie.type == FnTvMediaType.EPISODE.value) {
                        val tvDetailComponent = ComponentItem(
                            name = "剧集分季详情",
                            group = "/详情",
                            description = "剧集分季详情页面",
                            guid = "tv_detail_$parentGuid",
                            content = { nav ->
                                parentGuid?.let {
                                    TvSeasonDetailScreen(
                                        guid = parentGuid,
                                        navigator = nav
                                    )
                                }
                            }
                        )
                        navigator.navigate(tvDetailComponent)
                    }
                }
            )
        }


    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun RecentlyWatchedItem(
    modifier: Modifier = Modifier,
    title: String,
    subtitle: String?,
    posterImg: String?,
    isFavorite: Boolean = false,
    isAlreadyWatched: Boolean = false,
    duration: Int = 0,
    ts: Long = 0,
    guid: String,
    parentGuid: String? = null,
    onFavoriteToggle: ((String, Boolean, (Boolean) -> Unit) -> Unit)? = null,
    onWatchedToggle: ((String, Boolean, (Boolean) -> Unit) -> Unit)? = null,
    onMarkAsWatched: (() -> Unit)? = null,
    status: String? = "",
    onClick: ((String, String?) -> Unit)? = null
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
    val watchedAnimationDuration = 500

    var isVisible by remember(guid) {
        mutableStateOf(true)
    }

    val animatedVisible by remember {
        derivedStateOf { isVisible }
    }
    val player = LocalMediaPlayer.current
    val playMedia = rememberPlayMediaFunction(
        guid = guid,
        player = player,
    )

    LaunchedEffect(!isVisible) {
        if (!isVisible) {
            // 等待动画完成
            delay(watchedAnimationDuration.toLong())
            onMarkAsWatched?.invoke()
        }
    }

    AnimatedVisibility(
        visible = animatedVisible,
        exit = fadeOut(animationSpec = tween(durationMillis = watchedAnimationDuration)) +
                shrinkHorizontally(
                    shrinkTowards = Alignment.Start,
                    animationSpec = tween(
                        durationMillis = watchedAnimationDuration,
                        easing = LinearOutSlowInEasing
                    )
                )
    ) {
        val interactionSource = remember { MutableInteractionSource() }
        Column(
            modifier = modifier
                .pointerHoverIcon(PointerIcon.Hand)
                .onPointerEvent(PointerEventType.Enter) { isPosterHovered = true }
                .onPointerEvent(PointerEventType.Exit) { isPosterHovered = false }
                .fillMaxHeight()
                .clickable(
                    interactionSource = interactionSource,
                    indication = null, // 移除点击波纹效果
                    onClick = {
                        if (parentGuid != null) {
                            onClick?.invoke(guid, parentGuid)
                        } else {
                            onClick?.invoke(guid, null)
                        }
                    }
                )
                .pointerHoverIcon(PointerIcon.Hand),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(
                modifier = Modifier
                    .aspectRatio(16f / 9f)
                    .weight(1f)
                    .border(
                        1.dp,
                        Color.Gray.copy(alpha = 0.5f),
                        RoundedCornerShape((8 * scaleFactor).dp)
                    )
                    .clip(RoundedCornerShape((8 * scaleFactor).dp))
                    .onSizeChanged { size ->
                        imageContainerWidthPx = size.width
                    }
            ) {
                // 电影海报图片
                SubcomposeAsyncImage(
                    model = ImageRequest.Builder(PlatformContext.INSTANCE)
                        .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img$posterImg${Constants.FN_IMG_URL_PARAM}")
                        .httpHeaders(store.fnImgHeaders)
                        .crossfade(true)
                        .build(),
                    contentDescription = title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                    loading = { ImgLoadingProgressRing(modifier = Modifier.fillMaxSize()) },
                    error = {
                        ImgLoadingError()
                    },
                )

                // 纯色进度条
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .clip(RoundedCornerShape(3.dp))
                        .fillMaxWidth()
                        .height(5.dp)
                        .background(Color.White.copy(alpha = 0.05f))
                )
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .clip(RoundedCornerShape(3.dp))
                        .fillMaxWidth(
                            if (duration > 0) (ts.toFloat() / duration.toFloat()).coerceIn(
                                0f,
                                1f
                            ) else 0f
                        )
                        .height(5.dp)
                        .background(Color(0xFF2073DF))
                )

                // 半透明遮罩层
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color(0xFF1C1C1C).copy(alpha = if (isPosterHovered) 0.5f else 0f))
                        .alpha(if (isPosterHovered) 1f else 0f)
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

                Row(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(bottom = (8 * scaleFactor).dp),
                ) {

                    // 标记为已观看按钮
                    BottomIconButton(
                        modifier = Modifier
                            .alpha(if (isPosterHovered) 1f else 0f)
                            .padding(horizontal = (8 * scaleFactor).dp),
                        icon = Icons.Regular.Checkmark,
                        contentDescription = "alreadyWatched",
                        onClick = {
                            onWatchedToggle?.invoke(guid, isAlreadyWatched) { success ->
                                isAlreadyWatched = if (!success) {
                                    isAlreadyWatched
                                } else {
//                                    onMarkAsWatched?.invoke()
                                    // 触发移除动画
                                    isVisible = false
                                    isAlreadyWatched.not()
                                }
                            }
                        },
                        scaleFactor = scaleFactor,
                        iconTint = if (isAlreadyWatched) Color.Green else Color.White
                    )

                    // 收藏按钮
                    BottomIconButton(
                        modifier = Modifier
                            .alpha(if (isPosterHovered) 1f else 0f)
                            .padding(horizontal = (8 * scaleFactor).dp),
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
                        iconTint = if (isFavorite) Color.Red else Color.White,
                        iconYOffset = (1 * scaleFactor).dp
                    )

                    var isManageVersionsDialogVisible by remember { mutableStateOf(false) }
                    Box(
                        modifier = Modifier
                            .alpha(if (isPosterHovered) 1f else 0f)
                            .padding(horizontal = (8 * scaleFactor).dp)
                    ) {
                        MediaMoreFlyout(onManageVersionsClick = { isManageVersionsDialogVisible = true }){ onClick ->
                            BottomIconButton(
                                icon = Icons.Regular.MoreHorizontal,
                                contentDescription = "more",
                                scaleFactor = scaleFactor,
                                onClick = onClick
                            )
                        }
                    }

                    VersionManagementDialog(
                        visible = isManageVersionsDialogVisible,
                        guid = guid,
                        itemTitle = title,
                        onDismiss = { isManageVersionsDialogVisible = false },
                        onDelete = { _, _ -> },
                        onUnmatchConfirmed = { _, _ -> },
                        onMatchToOther = { _, _ -> }
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
                    fontWeight = FontWeight.Normal,
                    fontSize = (12 * scaleFactor).sp,
                    textAlign = TextAlign.Center,
                    color = if (isPosterHovered) Color(0xFF2073DF) else FluentTheme.colors.text.text.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.fillMaxWidth()
                )
                // 副标题/描述
                Spacer(Modifier.height((4 * scaleFactor).dp))
                subtitle?.let {
                    Text(
                        text = it,
                        fontSize = (12 * scaleFactor).sp,
                        textAlign = TextAlign.Center,
                        color = FluentTheme.colors.text.text.tertiary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}
