package com.jankinwu.fntv.client.ui.component.detail

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.PlatformContext
import coil3.compose.SubcomposeAsyncImage
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.crossfade
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.HeartFilled
import com.jankinwu.fntv.client.manager.HandleFavoriteResult
import com.jankinwu.fntv.client.manager.HandleWatchedResult
import com.jankinwu.fntv.client.ui.component.common.BottomIconButton
import com.jankinwu.fntv.client.ui.component.common.ComponentItem
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingError
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.MediaMoreFlyout
import com.jankinwu.fntv.client.ui.component.common.ScrollRow
import com.jankinwu.fntv.client.ui.component.common.dialog.VersionManagementDialog
import com.jankinwu.fntv.client.ui.providable.LocalMediaPlayer
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalToastManager
import com.jankinwu.fntv.client.ui.screen.MovieDetailScreen
import com.jankinwu.fntv.client.ui.screen.TvSeasonDetailScreen
import com.jankinwu.fntv.client.ui.screen.rememberPlayMediaFunction
import com.jankinwu.fntv.client.viewmodel.FavoriteViewModel
import com.jankinwu.fntv.client.viewmodel.WatchedViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Checkmark
import io.github.composefluent.icons.regular.MoreHorizontal
import io.github.composefluent.icons.regular.PlayCircle
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun EpisodesScrollRow(
    episodes: List<EpisodeListResponse>,
    navigator: ComponentNavigator,
    modifier: Modifier = Modifier,
    initialIndex: Int = 0,
) {
    val scrollState = rememberLazyListState()

    // 监听初始索引变化并滚动到指定位置
    androidx.compose.runtime.LaunchedEffect(initialIndex) {
        if (initialIndex >= 0 && initialIndex < episodes.size) {
            scrollState.scrollToItem(initialIndex)
        }
    }
    val scrollRowItemDataList = FnDataConvertor.convertToScrollRowItemDataList(episodes)
    val favoriteViewModel: FavoriteViewModel = koinViewModel<FavoriteViewModel>()
    val favoriteUiState by favoriteViewModel.uiState.collectAsState()
    val watchedViewModel: WatchedViewModel = koinViewModel<WatchedViewModel>()
    val watchedUiState by watchedViewModel.uiState.collectAsState()
    // 存储回调函数
    var pendingCallbacks by remember { mutableStateOf<Map<String, (Boolean) -> Unit>>(emptyMap()) }
    val toastManager = LocalToastManager.current
    HandleFavoriteResult(
        favoriteUiState = favoriteUiState,
        toastManager = toastManager,
        pendingCallbacks = pendingCallbacks,
        onPendingCallbackHandled = { id ->
            pendingCallbacks = pendingCallbacks - id
        },
        clearError = { favoriteViewModel.clearError() }
    )

    HandleWatchedResult(
        watchedUiState = watchedUiState,
        toastManager = toastManager,
        pendingCallbacks = pendingCallbacks,
        onPendingCallbackHandled = { id ->
            pendingCallbacks = pendingCallbacks - id
        },
        clearError = { watchedViewModel.clearError() }
    )
    Column(
        modifier = modifier
            .height(235.dp)
    ) {
        ScrollRow(
            itemsData = scrollRowItemDataList,
            listState = scrollState
        ) { index, movie, modifier, _ ->
            EpisodeScrollItem(
                modifier = modifier.wrapContentHeight(Alignment.Top),
                title = movie.title,
                subtitle = movie.subtitle,
                posterImg = movie.posterImg,
                isFavorite = movie.isFavourite,
                isAlreadyWatched = movie.isAlreadyWatched,
                duration = movie.duration,
                ts = movie.ts,
                guid = movie.guid,
                parentGuid = movie.parentGuid,
                onFavoriteToggle = { guid, currentFavoriteState, resultCallback ->
                    favoriteViewModel.toggleFavorite(guid, currentFavoriteState)
                    // 保存回调函数
                    pendingCallbacks =
                        pendingCallbacks + (guid to resultCallback)
                },
                onWatchedToggle = { guid, currentFavoriteState, resultCallback ->
                    watchedViewModel.toggleWatched(guid, currentFavoriteState)
                    // 保存回调函数
                    pendingCallbacks =
                        pendingCallbacks + (guid to resultCallback)
                },
                status = movie.status,
                onClick = { movieGuid, parentGuid ->
                    if (movie.type == FnTvMediaType.MOVIE.value || movie.type == FnTvMediaType.VIDEO.value) {
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
                            guid = "tv_detail_$movieGuid",
                            content = { nav ->
                                TvSeasonDetailScreen(
                                    guid = movieGuid,
                                    navigator = nav
                                )
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
fun EpisodeScrollItem(
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
    status: String? = "",
    posterHeight: Dp = 140.dp,
    onClick: ((String, String?) -> Unit)? = null
) {
    val store = LocalStore.current
//    val scaleFactor = store.scaleFactor

    var isPosterHovered by remember { mutableStateOf(false) }
    var isPlayButtonHovered by remember { mutableStateOf(false) }

    var normalPlayButtonSize by remember { mutableStateOf(48.dp) }
    var hoveredPlayButtonSize by remember { mutableStateOf(56.dp) }
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

    val player = LocalMediaPlayer.current
    val playMedia = rememberPlayMediaFunction(
        guid = guid,
        player = player,
    )

    val interactionSource = remember { MutableInteractionSource() }
    Column(
        modifier = modifier
            .pointerHoverIcon(PointerIcon.Hand)
            .onPointerEvent(PointerEventType.Enter) { isPosterHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isPosterHovered = false }
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
//                    .aspectRatio(16f / 9f)
//                    .weight(1f)
                .height(posterHeight)
                .width(posterHeight * 16f / 9f)
                .border(
                    1.dp,
                    Color.Gray.copy(alpha = 0.5f),
                    RoundedCornerShape(8.dp)
                )
                .clip(RoundedCornerShape(8.dp))
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
                modifier = Modifier
                    .height(posterHeight)
                    .width(posterHeight * 16f / 9f),
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
                    .padding(bottom = 8.dp),
            ) {

                // 标记为已观看按钮
                BottomIconButton(
                    modifier = Modifier
                        .alpha(if (isPosterHovered) 1f else 0f)
                        .padding(horizontal = 8.dp),
                    icon = Icons.Regular.Checkmark,
                    contentDescription = "alreadyWatched",
                    onClick = {
                        onWatchedToggle?.invoke(guid, isAlreadyWatched) { success ->
                            isAlreadyWatched = if (!success) {
                                isAlreadyWatched
                            } else {
//                                    onMarkAsWatched?.invoke()
                                // 触发移除动画
//                                    isVisible = false
                                isAlreadyWatched.not()
                            }
                        }
                    },
//                        scaleFactor = scaleFactor,
                    iconTint = if (isAlreadyWatched) Color.Green else Color.White
                )

                // 收藏按钮
                BottomIconButton(
                    modifier = Modifier
                        .alpha(if (isPosterHovered) 1f else 0f)
                        .padding(horizontal = 8.dp),
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
//                        scaleFactor = scaleFactor,
                    iconTint = if (isFavorite) Color.Red else Color.White,
                    iconYOffset = 1.dp
                )

                var isManageVersionsDialogVisible by remember { mutableStateOf(false) }
                Box(
                    modifier = Modifier
                        .alpha(if (isPosterHovered) 1f else 0f)
                        .padding(horizontal = 8.dp)
                ) {
                    MediaMoreFlyout(
                        onManageVersionsClick = {
                            isManageVersionsDialogVisible = true
                        },
                        type = FnTvMediaType.EPISODE.value,
                    ) { onClick ->
                        BottomIconButton(
                            icon = Icons.Regular.MoreHorizontal,
                            contentDescription = "more",
//                                scaleFactor = scaleFactor,
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
        Spacer(Modifier.height(8.dp))
        val textContainerWidthDp = with(LocalDensity.current) { imageContainerWidthPx.toDp() }
        Column(
            horizontalAlignment = Alignment.Start,
            modifier = if (textContainerWidthDp > 0.dp) {
                Modifier.width(textContainerWidthDp).weight(1f)
            } else {
                Modifier.fillMaxWidth().weight(1f)
            }
        ) {
            // 电影标题
            Text(
                text = title,
                fontWeight = FontWeight.Normal,
                fontSize = 14.sp,
                textAlign = TextAlign.Start,
                color = if (isPosterHovered) Color(0xFF2073DF) else FluentTheme.colors.text.text.primary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(6.dp))
            // 副标题/描述
            subtitle?.let {
                Text(
                    text = it,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Start,
                    color = FluentTheme.colors.text.text.tertiary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = FnDataConvertor.formatSecondsToCNDateTime(duration),
                fontSize = 12.sp,
                textAlign = TextAlign.Start,
                color = FluentTheme.colors.text.text.tertiary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}