package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.touchlab.kermit.Logger
import coil3.PlatformContext
import coil3.compose.SubcomposeAsyncImage
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.crossfade
import coil3.size.Precision
import coil3.size.Size
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.response.ItemResponse
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.model.response.SeasonListResponse
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.icons.HeartFilled
import com.jankinwu.fntv.client.ui.component.common.BackButton
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingError
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.MediaMoreFlyout
import com.jankinwu.fntv.client.ui.component.common.MoviePoster
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.component.common.dialog.VersionManagementDialog
import com.jankinwu.fntv.client.ui.component.detail.DetailPlayButton
import com.jankinwu.fntv.client.ui.component.detail.DetailTags
import com.jankinwu.fntv.client.ui.component.detail.ImdbLink
import com.jankinwu.fntv.client.ui.component.detail.MediaDescription
import com.jankinwu.fntv.client.ui.component.detail.MediaDescriptionDialog
import com.jankinwu.fntv.client.ui.providable.IsoTagData
import com.jankinwu.fntv.client.ui.providable.LocalIsoTagData
import com.jankinwu.fntv.client.ui.providable.LocalMediaPlayer
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.ui.providable.LocalRefreshState
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalToastManager
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.viewmodel.FavoriteViewModel
import com.jankinwu.fntv.client.viewmodel.GenresViewModel
import com.jankinwu.fntv.client.viewmodel.ItemViewModel
import com.jankinwu.fntv.client.viewmodel.PlayInfoViewModel
import com.jankinwu.fntv.client.viewmodel.SeasonListViewModel
import com.jankinwu.fntv.client.viewmodel.SmartAnalysisViewModel
import com.jankinwu.fntv.client.viewmodel.TagViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.WatchedViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.rememberScrollbarAdapter
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Checkmark
import io.github.composefluent.icons.regular.MoreHorizontal
import kotlinx.coroutines.delay
import org.koin.compose.viewmodel.koinViewModel

private val logger = Logger.withTag("TvDetailScreen")

@Composable
fun TvDetailScreen(
    guid: String,
    navigator: ComponentNavigator
) {
    val itemViewModel: ItemViewModel = koinViewModel()
    val itemUiState by itemViewModel.uiState.collectAsState()
    var itemData: ItemResponse? by remember { mutableStateOf(null) }

    val playInfoViewModel: PlayInfoViewModel = koinViewModel()
    val playInfoUiState by playInfoViewModel.uiState.collectAsState()

    var playInfoResponse: PlayInfoResponse? by remember { mutableStateOf(null) }

    val seasonListViewModel: SeasonListViewModel = koinViewModel()
    val seasonListState by seasonListViewModel.uiState.collectAsState()
    var seasonList: List<SeasonListResponse> by remember { mutableStateOf(emptyList()) }

    val tagViewModel: TagViewModel = koinViewModel<TagViewModel>()
    val iso6392State by tagViewModel.iso6392State.collectAsState()
    val iso6391State by tagViewModel.iso6391State.collectAsState()
    val iso3166State by tagViewModel.iso3166State.collectAsState()
    var isoTagData by remember {
        mutableStateOf(
            IsoTagData(
                iso6391Map = emptyMap(),
                iso6392Map = emptyMap(),
                iso3166Map = emptyMap()
            )
        )
    }
    val genresViewModel: GenresViewModel = koinViewModel<GenresViewModel>()
    val refreshState = LocalRefreshState.current
    val toastManager = rememberToastManager()
    val playerManager = LocalPlayerManager.current
    var isFirstLoad by remember(guid) { mutableStateOf(true) }
    // 当从播放器返回时刷新最近播放列表
    LaunchedEffect(playerManager.playerState) {
        if (!playerManager.playerState.isVisible && !isFirstLoad) {
            itemViewModel.loadData(guid)
            playInfoViewModel.loadData(guid)
            seasonListViewModel.loadData(guid)
        }
    }

    LaunchedEffect(Unit) {
        itemViewModel.loadData(guid)
        playInfoViewModel.loadData(guid)
        seasonListViewModel.loadData(guid)

        if (iso6392State !is UiState.Success) {
            tagViewModel.loadIso6392Tags()
        }
        if (iso6391State !is UiState.Success) {
            tagViewModel.loadIso6391Tags()
        }
        if (iso3166State !is UiState.Success) {
            tagViewModel.loadIso3166Tags()
        }
    }
    // 监听刷新状态变化
    LaunchedEffect(refreshState.refreshKey) {
        // 当刷新状态变化时执行刷新逻辑
        if (refreshState.refreshKey.isNotEmpty()) {
            itemViewModel.loadData(guid)
//            personListViewModel.loadData(guid)
            playInfoViewModel.loadData(guid)
            seasonListViewModel.loadData(guid)
            tagViewModel.loadIso6392Tags()
            tagViewModel.loadIso3166Tags()
            genresViewModel.loadGenres()
        }
    }
    LaunchedEffect(itemUiState) {
        when (itemUiState) {
            is UiState.Success -> {
                itemData = (itemUiState as UiState.Success<ItemResponse>).data
            }

            is UiState.Error -> {
                logger.e("itemUiState error: ${(itemUiState as UiState.Error).message}")
            }

            else -> {}
        }
    }
    LaunchedEffect(playInfoUiState) {
        when (playInfoUiState) {
            is UiState.Success -> {
                playInfoResponse = (playInfoUiState as UiState.Success<PlayInfoResponse>).data
            }

            is UiState.Error -> {
                logger.e("playInfoUiState error: ${(playInfoUiState as UiState.Error).message}")
            }

            else -> {}
        }
    }
    LaunchedEffect(seasonListState) {
        logger.i("seasonListState: $seasonListState")
        when (seasonListState) {
            is UiState.Success -> {
                seasonList = (seasonListState as UiState.Success<List<SeasonListResponse>>).data
            }

            is UiState.Error -> {
                logger.e("seasonListState error: ${(seasonListState as UiState.Error).message}")
            }

            else -> {}
        }
    }

    LaunchedEffect(iso6391State, iso6392State, iso3166State) {
        val newIso6391Map = when (iso6391State) {
            is UiState.Success -> {
                (iso6391State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
            }

            is UiState.Error -> {
                logger.e("iso6391State error: ${(iso6391State as UiState.Error).message}")
                emptyMap()
            }

            else -> emptyMap()
        }

        val newIso6392Map = when (iso6392State) {
            is UiState.Success -> {
                (iso6392State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
            }

            is UiState.Error -> {
                logger.e("iso6392State error: ${(iso6392State as UiState.Error).message}")
                emptyMap()
            }

            else -> emptyMap()
        }

        val newIso3166Map = when (iso3166State) {
            is UiState.Success -> {
                (iso3166State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
            }

            is UiState.Error -> {
                logger.e("iso3166State error: ${(iso3166State as UiState.Error).message}")
                emptyMap()
            }

            else -> emptyMap()
        }

        isoTagData = IsoTagData(
            iso6391Map = newIso6391Map,
            iso6392Map = newIso6392Map,
            iso3166Map = newIso3166Map
        )
    }
    CompositionLocalProvider(
        LocalIsoTagData provides isoTagData,
        LocalToastManager provides toastManager
    ) {
        TvDetailBody(
            itemData = itemData,
            playInfoResponse = playInfoResponse,
            guid = guid,
            seasonList = seasonList,
            navigator = navigator,
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TvDetailBody(
    itemData: ItemResponse?,
    playInfoResponse: PlayInfoResponse?,
    guid: String,
    seasonList: List<SeasonListResponse>,
    navigator: ComponentNavigator,
) {
    val store = LocalStore.current
    val windowHeight = store.windowHeightState
    val toastManager = LocalToastManager.current
    val smartAnalysisEnabled = AppSettingsStore.smartAnalysisEnabled
    val smartAnalysisViewModel: SmartAnalysisViewModel = koinViewModel()
    val analyzeState by smartAnalysisViewModel.analyzeState.collectAsState()
    val watchedViewModel: WatchedViewModel = koinViewModel<WatchedViewModel>()
    val watchedUiState by watchedViewModel.uiState.collectAsState()
    val favoriteViewModel: FavoriteViewModel = koinViewModel<FavoriteViewModel>()
    val favoriteUiState by favoriteViewModel.uiState.collectAsState()
    var pendingCallbacks by remember { mutableStateOf<Map<String, (Boolean) -> Unit>>(emptyMap()) }
    val seasonListViewModel: SeasonListViewModel = koinViewModel()
    val itemViewModel: ItemViewModel = koinViewModel()
    var showDescriptionDialog by remember { mutableStateOf(false) }

    LaunchedEffect(analyzeState) {
        when (val state = analyzeState) {
            is UiState.Success -> {
                toastManager.showToast(state.data, ToastType.Success)
                smartAnalysisViewModel.clearState()
            }

            is UiState.Error -> {
                toastManager.showToast(state.message, ToastType.Failed)
                smartAnalysisViewModel.clearState()
            }

            else -> Unit
        }
    }

    // 监听已观看操作结果并显示提示
    LaunchedEffect(watchedUiState) {
        when (val state = watchedUiState) {
            is UiState.Success -> {
                toastManager.showToast(
                    state.data.message,
                    if (state.data.success) ToastType.Success else ToastType.Failed
                )
                // 调用对应的回调函数
                pendingCallbacks[state.data.guid]?.invoke(state.data.success)
                // 从 pendingCallbacks 中移除已处理的回调
                pendingCallbacks = pendingCallbacks - state.data.guid
                seasonListViewModel.loadData(guid)
                itemViewModel.loadData(guid)
            }

            is UiState.Error -> {
                // 显示错误提示
                logger.e("watchedUiState error: ${state.message}")
                toastManager.showToast("操作失败，${state.message}", ToastType.Failed)
                state.operationId?.let {
                    pendingCallbacks[state.operationId]?.invoke(false)
                    // 从 pendingCallbacks 中移除已处理的回调
                    pendingCallbacks = pendingCallbacks - state.operationId
                }
            }

            else -> {}
        }

        // 清除状态
        if (watchedUiState is UiState.Success || watchedUiState is UiState.Error) {
            delay(2000) // 2秒后清除状态
            watchedViewModel.clearError()
        }
    }

    // 监听收藏操作结果并显示提示
    LaunchedEffect(favoriteUiState) {
        when (val state = favoriteUiState) {
            is UiState.Success -> {
                toastManager.showToast(
                    state.data.message,
                    if (state.data.success) ToastType.Success else ToastType.Failed
                )
                itemViewModel.loadData(guid)
            }

            is UiState.Error -> {
                // 显示错误提示
                logger.e("favoriteUiState error: ${state.message}")
                toastManager.showToast("操作失败，${state.message}", ToastType.Failed)
            }

            else -> {}
        }

        // 清除状态
        if (favoriteUiState is UiState.Success || favoriteUiState is UiState.Error) {
            delay(2000) // 2秒后清除状态
            favoriteViewModel.clearError()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
    ) {
        val lazyListState = rememberLazyListState()
        ScrollbarContainer(adapter = rememberScrollbarAdapter(lazyListState)) {
            LazyColumn(state = lazyListState) {
                // Header Image & Title
                item {
                    Box(
                        modifier = Modifier
                            .height((windowHeight / 2.dp).dp)
                            .fillMaxWidth(),
                        contentAlignment = Alignment.TopCenter
                    ) {
                        if (itemData != null) {
                            val backdropsImg =
                                if (!itemData.backdrops.isNullOrBlank()) itemData.backdrops else itemData.posters
                            SubcomposeAsyncImage(
                                model = ImageRequest.Builder(PlatformContext.INSTANCE)
                                    .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img${backdropsImg}")
                                    .httpHeaders(store.fnImgHeaders)
                                    .crossfade(true)
                                    .size(Size.ORIGINAL)
                                    .build(),
                                contentDescription = itemData.title,
                                modifier = Modifier
                                    .height((windowHeight / 2.dp).dp)
                                    .fillMaxWidth(),
                                contentScale = ContentScale.Crop,
                                filterQuality = FilterQuality.High,
                                loading = { ImgLoadingProgressRing() },
                                error = { ImgLoadingError() },
                            )
                        }
                        // Gradient Overlay
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(
                                    brush = Brush.verticalGradient(
                                        colorStops = arrayOf(
                                            0.45f to Color.Transparent,
                                            1.0f to if (store.darkMode) Colors.BackgroundColorDark else Colors.BackgroundColorLight
                                        )
                                    )
                                )
                        )
                        // Title / Logo
                        if (itemData != null) {
                            if (itemData.logos != null) {
                                var imageHeight by remember { mutableStateOf(90.dp) }
                                SubcomposeAsyncImage(
                                    model = ImageRequest.Builder(PlatformContext.INSTANCE)
                                        .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img${itemData.logos}")
                                        .httpHeaders(store.fnImgHeaders)
                                        .crossfade(true)
                                        .precision(Precision.EXACT)
                                        .build(),
                                    contentDescription = itemData.title,
                                    modifier = Modifier
                                        .align(Alignment.BottomStart)
                                        .height(imageHeight)
                                        .padding(start = 48.dp, bottom = 12.dp),
                                    contentScale = ContentScale.FillHeight,
                                    filterQuality = FilterQuality.High,
                                    onSuccess = { state ->
                                        state.result.image.let { drawable ->
                                            imageHeight = 90.dp
                                            val width = drawable.width
                                            val height = drawable.height
                                            val actualWidth = width.toDouble() / height * 90
                                            if (actualWidth > 0 && actualWidth < 280) {
                                                imageHeight = 150.dp
                                            }
                                        }
                                    }
                                )
                            } else {
                                Box(
                                    modifier = Modifier
                                        .align(Alignment.BottomStart)
                                        .padding(horizontal = 48.dp)
                                ) {
                                    Text(
                                        text = itemData.title,
                                        style = LocalTypography.current.title,
                                        fontWeight = FontWeight.Medium,
                                        color = Color.White,
                                        lineHeight = 80.sp,
                                        fontSize = 60.sp,
                                        maxLines = 2,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            }
                        }
                    }
                }

                // Media Info (Play button, tags, description)
                item {
                    if (itemData != null && playInfoResponse != null) {
                        TvMediaInfo(
                            itemData,
                            guid,
                            playInfoResponse,
                            seasonList,
                            modifier = Modifier
                                .padding(start = 48.dp, end = 48.dp, top = 24.dp),
                            showDescriptionDialog = {
                                showDescriptionDialog = true
                            }
                        )
                    }
                }

                // Season List
                if (seasonList.isNotEmpty()) {
                    val scaleFactor = store.scaleFactor
                    val posterMinWidth = (128 * scaleFactor).dp
                    val posterMaxWidth = (190 * scaleFactor).dp
                    val spacing = 16.dp
                    item {
                        BoxWithConstraints(modifier = Modifier.padding(horizontal = 48.dp)) {
                            val availableWidth = maxWidth

                            val itemsPerRow =
                                ((availableWidth + spacing) / (posterMinWidth + spacing)).toInt()
                                    .coerceAtLeast(1)

                            val itemWidth = if (itemsPerRow >= 4) {
                                val totalSpacing = spacing * (itemsPerRow - 1)
                                ((availableWidth - totalSpacing) / itemsPerRow)
                                    .coerceIn(posterMinWidth, posterMaxWidth)
                            } else {
                                posterMinWidth
                            }

                            FlowRow(
                                horizontalArrangement = Arrangement.spacedBy(spacing),
                                verticalArrangement = Arrangement.spacedBy(spacing),
                            ) {
                                seasonList.forEach { season ->
                                    Box(
                                        modifier = Modifier
                                            .width(itemWidth)
                                            .height((253 * scaleFactor).dp)
                                    ) {
                                        val episodeNumber = if (season.episodeNumber > 0) {
                                            season.episodeNumber
                                        } else {
                                            season.localNumberOfEpisodes
                                        }
                                        MoviePoster(
                                            modifier = Modifier.fillMaxSize(),
                                            title = season.title,
                                            subtitle = if (season.airDate != null) "共 $episodeNumber 集 · ${
                                                season.airDate.take(4)
                                            }" else "共 $episodeNumber 集",
                                            score = FnDataConvertor.formatVoteAverage(season.voteAverage),
                                            posterImg = season.poster,
                                            isFavorite = season.isFavorite == 1,
                                            isAlreadyWatched = season.watched == 1,
                                            guid = season.guid,
                                            status = season.status,
                                            navigator = navigator,
                                            type = season.type,
                                            posterWidth = season.posterWidth,
                                            posterHeight = season.posterHeight,
                                            onWatchedToggle = { guid, currentWatchedState, resultCallback ->
                                                // 保存回调函数
                                                pendingCallbacks =
                                                    pendingCallbacks + (guid to resultCallback)
                                                // 调用 ViewModel 方法
                                                watchedViewModel.toggleWatched(
                                                    guid,
                                                    currentWatchedState
                                                )
                                            },
                                            seasonNumber = season.seasonNumber,
                                            mediaTitle = itemData?.title
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                item {
                    if (itemData?.imdbId?.isNotBlank() ?: false) {
                        ImdbLink(
                            FnDataConvertor.getImdbLink(itemData.imdbId),
                            modifier = Modifier.padding(horizontal = 48.dp, vertical = 24.dp)
                        )
                    }
                }
            }
        }
        BackButton(navigator, modifier = Modifier.align(Alignment.TopStart))
        ToastHost(
            toastManager = toastManager,
            modifier = Modifier.fillMaxSize()
        )
        if (showDescriptionDialog) {
            MediaDescriptionDialog(
                title = "电影简介",
                content = itemData?.overview?.replace("\n\n", "\n") ?: "",
                onDismiss = { showDescriptionDialog = false }
            )
        }
    }
}

@Composable
private fun TvMediaInfo(
    itemData: ItemResponse,
    guid: String,
    playInfo: PlayInfoResponse,
    seasonList: List<SeasonListResponse>,
    modifier: Modifier = Modifier,
    showDescriptionDialog: () -> Unit
) {

    Column(
        modifier = modifier
            .fillMaxWidth(),
        verticalArrangement = Arrangement.Center
    ) {
        TvMiddleControls(
            modifier = Modifier.padding(bottom = 16.dp),
            itemData,
            guid,
            seasonList,
            playInfo
        )
        if (!itemData.overview.isNullOrBlank()) {
            MediaDescription(
                modifier = Modifier.padding(bottom = 32.dp), itemData,
                onClick = { showDescriptionDialog() })
        }
    }
}

@Composable
private fun TvMiddleControls(
    modifier: Modifier = Modifier,
    itemData: ItemResponse,
    guid: String,
    seasonList: List<SeasonListResponse>,
    playInfo: PlayInfoResponse,
) {
    val player = LocalMediaPlayer.current
    val playMedia = rememberPlayMediaFunction(
        guid = guid,
        player = player,
//        mediaGuid = playInfo.mediaGuid,
//        currentAudioGuid = currentAudioStream?.guid,
//        currentSubtitleGuid = currentSubtitleStream?.guid
    )
    val favoriteViewModel: FavoriteViewModel = koinViewModel<FavoriteViewModel>()
    var isFavorite by remember(itemData.isFavorite == 1) { mutableStateOf(itemData.isFavorite == 1) }
    val watchedViewModel: WatchedViewModel = koinViewModel<WatchedViewModel>()
    var isWatched by remember(itemData.isWatched == 1) { mutableStateOf(itemData.isWatched == 1) }
    val smartAnalysisEnabled = AppSettingsStore.smartAnalysisEnabled
    val smartAnalysisViewModel: SmartAnalysisViewModel = koinViewModel()
    var isManageVersionsDialogVisible by remember { mutableStateOf(false) }

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(end = 64.dp)
        ) {
            // 播放按钮
            if (seasonList.size == 1) {
                DetailPlayButton("第 ${playInfo.item.episodeNumber} 集") { playMedia() }
            } else {
                DetailPlayButton("第 ${playInfo.item.seasonNumber} 季 第 ${playInfo.item.episodeNumber} 集") { playMedia() }
            }
            // 收藏按钮
            CircleIconButton(
                icon = HeartFilled,
                description = "收藏",
                iconColor = if (isFavorite) Colors.DangerDefaultColor else FluentTheme.colors.text.text.primary,
                onClick = {
                    favoriteViewModel.toggleFavorite(
                        guid,
                        isFavorite
                    )
                })

            // 是否已观看按钮
            CircleIconButton(
                icon = Icons.Regular.Checkmark, description = "已观看",
                iconColor = if (isWatched) Colors.AccentColorDefault else FluentTheme.colors.text.text.primary,
                onClick = {
                    watchedViewModel.toggleWatched(
                        guid,
                        isWatched
                    )
                })

            // 更多按钮
            MediaMoreFlyout(
                onManageVersionsClick = { isManageVersionsDialogVisible = true },
                onSmartAnalysisClick = if (smartAnalysisEnabled) {
                    { smartAnalysisViewModel.analyzeTv(guid, itemData.title) }
                } else null
            ) { onClick ->
                CircleIconButton(
                    icon = Icons.Regular.MoreHorizontal,
                    description = "更多",
                    onClick = onClick,
                    iconColor = FluentTheme.colors.text.text.primary
                )
            }
        }
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically)
        ) {
            // 标签
            DetailTags(
                itemData
            )
        }
    }

    VersionManagementDialog(
        visible = isManageVersionsDialogVisible,
        guid = guid,
        itemTitle = itemData.title,
        onDismiss = { isManageVersionsDialogVisible = false },
        onDelete = { _, _ -> },
        onUnmatchConfirmed = { _, _ -> },
        onMatchToOther = { _, _ -> }
    )
}
