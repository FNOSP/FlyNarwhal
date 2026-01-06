package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.touchlab.kermit.Logger
import coil3.PlatformContext
import coil3.compose.AsyncImagePainter
import coil3.compose.rememberAsyncImagePainter
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.crossfade
import coil3.size.Size
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.convertor.convertPersonToScrollRowItemData
import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
import com.jankinwu.fntv.client.data.model.response.ItemResponse
import com.jankinwu.fntv.client.data.model.response.PersonList
import com.jankinwu.fntv.client.data.model.response.PersonListResponse
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.ui.component.common.BackButton
import com.jankinwu.fntv.client.ui.component.common.CastScrollRow
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingError
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.MediaMoreFlyout
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.component.detail.DetailPlayButton
import com.jankinwu.fntv.client.ui.component.detail.DetailTags
import com.jankinwu.fntv.client.ui.component.detail.EpisodesScrollRow
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
import com.jankinwu.fntv.client.viewmodel.EpisodeListViewModel
import com.jankinwu.fntv.client.viewmodel.GenresViewModel
import com.jankinwu.fntv.client.viewmodel.ItemViewModel
import com.jankinwu.fntv.client.viewmodel.PersonListViewModel
import com.jankinwu.fntv.client.viewmodel.PlayInfoViewModel
import com.jankinwu.fntv.client.viewmodel.SmartAnalysisStatusViewModel
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

private val logger = Logger.withTag("TvSeasonDetailScreen")

@Composable
fun TvSeasonDetailScreen(
    guid: String,
    navigator: ComponentNavigator
) {
    val itemViewModel: ItemViewModel = koinViewModel()
    val itemUiState by itemViewModel.uiState.collectAsState()
    var itemData: ItemResponse? by remember { mutableStateOf(null) }

    val playInfoViewModel: PlayInfoViewModel = koinViewModel()
    val playInfoUiState by playInfoViewModel.uiState.collectAsState()

    var playInfoResponse: PlayInfoResponse? by remember { mutableStateOf(null) }

    val episodeListViewModel: EpisodeListViewModel = koinViewModel()
    val episodeListState by episodeListViewModel.uiState.collectAsState()
    val episodeList = remember(episodeListState) {
        when (episodeListState) {
            is UiState.Success -> {
                (episodeListState as UiState.Success).data
            }

            is UiState.Error -> {
                val message = (episodeListState as UiState.Error).message
                logger.e("episodeList request error: $message")
                emptyList()
            }

            else -> {
                emptyList()
            }
        }
    }
    val personListViewModel: PersonListViewModel = koinViewModel()
    val personListState by personListViewModel.uiState.collectAsState()
    var personList: List<PersonList> by remember { mutableStateOf(emptyList()) }
    var castScrollRowItemList by remember { mutableStateOf(emptyList<ScrollRowItemData>()) }
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
            episodeListViewModel.loadData(guid)
        }
    }
    LaunchedEffect(guid) {
        itemViewModel.clearError()
        playInfoViewModel.clearError()
        episodeListViewModel.clearError()
        personListViewModel.clearError()

        itemViewModel.loadData(guid)
        playInfoViewModel.loadData(guid)
        episodeListViewModel.loadData(guid)
        personListViewModel.loadData(guid)

        if (iso6392State !is UiState.Success) {
            tagViewModel.loadIso6392Tags()
        }
        if (iso6391State !is UiState.Success) {
            tagViewModel.loadIso6391Tags()
        }
        if (iso3166State !is UiState.Success) {
            tagViewModel.loadIso3166Tags()
        }
        isFirstLoad = false
    }
    // 监听刷新状态变化
    LaunchedEffect(refreshState.refreshKey) {
        // 当刷新状态变化时执行刷新逻辑
        if (refreshState.refreshKey.isNotEmpty()) {
            itemViewModel.loadData(guid)
//            personListViewModel.loadData(guid)
            playInfoViewModel.loadData(guid)
            episodeListViewModel.loadData(guid)
            tagViewModel.loadIso6392Tags()
            tagViewModel.loadIso3166Tags()
            genresViewModel.loadGenres()
            personListViewModel.loadData(guid)
        }
    }
    LaunchedEffect(itemUiState) {
        when (itemUiState) {
            is UiState.Success -> {
                itemData = (itemUiState as UiState.Success<ItemResponse>).data
            }

            is UiState.Error -> {
                logger.e("itemUiState error: ${(itemUiState as UiState.Error).message}")
                itemData = null
            }

            else -> {
                itemData = null
            }
        }
    }

    LaunchedEffect(playInfoUiState) {
        when (playInfoUiState) {
            is UiState.Success -> {
                playInfoResponse = (playInfoUiState as UiState.Success<PlayInfoResponse>).data
            }

            is UiState.Error -> {
                logger.e("playInfoUiState error: ${(playInfoUiState as UiState.Error).message}")
                playInfoResponse = null
            }

            else -> {
                playInfoResponse = null
            }
        }
    }

    LaunchedEffect(personListState) {
        when (personListState) {
            is UiState.Success -> {
                personList = (personListState as UiState.Success<PersonListResponse>).data.list
                castScrollRowItemList = convertPersonToScrollRowItemData(personList)
                logger.i("scrollRowItemList: $castScrollRowItemList")
            }

            is UiState.Error -> {
                logger.e("personListState error: ${(personListState as UiState.Error).message}")
                castScrollRowItemList = emptyList()
            }

            else -> {
                castScrollRowItemList = emptyList()
            }
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
        LocalToastManager provides toastManager,
    ) {
        TvEpisodeBody(
            itemData = itemData,
            playInfo = playInfoResponse,
            guid = guid,
            episodeList = episodeList,
            castScrollRowItemList,
            navigator = navigator
        )
    }
}

@Composable
fun TvEpisodeBody(
    itemData: ItemResponse?,
    playInfo: PlayInfoResponse?,
    guid: String,
    episodeList: List<EpisodeListResponse>,
    castScrollRowItemList: List<ScrollRowItemData>,
    navigator: ComponentNavigator,
) {
    val store = LocalStore.current
    val windowHeight = store.windowHeightState
    val toastManager = LocalToastManager.current
    val smartAnalysisEnabled = AppSettingsStore.smartAnalysisEnabled
    val smartAnalysisViewModel: SmartAnalysisViewModel = koinViewModel()
    val analyzeState by smartAnalysisViewModel.analyzeState.collectAsState()
    val smartAnalysisStatusViewModel: SmartAnalysisStatusViewModel = koinViewModel()
    val statusUiState by smartAnalysisStatusViewModel.uiState.collectAsState()
    var isWatched by remember(itemData?.isWatched == 1) { mutableStateOf(itemData?.isWatched == 1) }
    var showDescriptionDialog by remember { mutableStateOf(false) }
    var isManageVersionsDialogVisible by remember { mutableStateOf(false) }
    val watchedViewModel: WatchedViewModel = koinViewModel<WatchedViewModel>()
    val watchedUiState by watchedViewModel.uiState.collectAsState()
    val itemViewModel: ItemViewModel = koinViewModel()
    val episodeListViewModel: EpisodeListViewModel = koinViewModel()
    val imageRequest = remember(itemData) {
        if (itemData != null && itemData.posters.isNotBlank()) {
            ImageRequest.Builder(PlatformContext.INSTANCE)
                .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img${itemData.posters}")
                .httpHeaders(store.fnImgHeaders)
                .crossfade(true)
                .size(Size.ORIGINAL)
                .build()
        } else {
            null
        }
    }

    val painter = rememberAsyncImagePainter(model = imageRequest)
    val painterState by painter.state.collectAsState()

    LaunchedEffect(smartAnalysisEnabled, itemData?.type, guid) {
        if (!smartAnalysisEnabled || itemData?.type != FnTvMediaType.SEASON.value) return@LaunchedEffect
        smartAnalysisViewModel.seasonStatusPollingTrigger.collect { seasonGuid ->
            if (seasonGuid == guid) {
                smartAnalysisStatusViewModel.startPolling(type = "SEASON", guid = guid, force = true)
            }
        }
    }

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

    val shouldShowSmartAnalysisStatus = smartAnalysisEnabled && itemData?.type == FnTvMediaType.SEASON.value
    LaunchedEffect(shouldShowSmartAnalysisStatus, guid) {
        if (shouldShowSmartAnalysisStatus) {
            smartAnalysisStatusViewModel.startPolling(type = "SEASON", guid = guid)
        } else {
            smartAnalysisStatusViewModel.stopPolling()
        }
    }
    DisposableEffect(Unit) {
        onDispose {
            smartAnalysisStatusViewModel.stopPolling()
        }
    }
    val smartAnalysisStatusText = remember(shouldShowSmartAnalysisStatus, statusUiState) {
        if (!shouldShowSmartAnalysisStatus) {
            null
        } else {
            when (val state = statusUiState) {
                is UiState.Success -> {
                    val result = state.data
                    if (result.isSuccess()) {
                        result.data?.description ?: "未检测"
                    } else {
                        "获取失败"
                    }
                }

                is UiState.Error -> "获取失败"
                UiState.Loading, UiState.Initial -> "获取中"
            }
        }
    }

    // 监听已观看操作结果并显示提示
    LaunchedEffect(watchedUiState) {
        when (val state = watchedUiState) {
            is UiState.Success -> {
                itemViewModel.loadData(guid)
                episodeListViewModel.loadData(guid)
            }

            is UiState.Error -> {
                logger.e("watchedUiState error: ${state.message}")
            }

            else -> {}
        }

        // 清除状态
        if (watchedUiState is UiState.Success || watchedUiState is UiState.Error) {
            delay(2000) // 2秒后清除状态
            watchedViewModel.clearError()
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
                        if (imageRequest != null && itemData != null) {
                            Image(
                                painter = painter,
                                contentDescription = itemData.title,
                                modifier = Modifier
                                    .height((windowHeight / 2.dp).dp)
                                    .fillMaxWidth()
                                    .blur(10.dp),
                                contentScale = ContentScale.Crop,
                            )
                        }
                        // Gradient Overlay
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(
                                    brush = Brush.verticalGradient(
                                        colorStops = arrayOf(
                                            0.0f to Color.Transparent,
                                            0.7f to Color(0xFF1A1E23).copy(alpha = 0.5f),
                                            1.0f to if (store.darkMode) Colors.BackgroundColorDark else Colors.BackgroundColorLight
                                        )
                                    )
                                )
                        )

                        // Poster and Info Row
                        if (itemData != null) {
                            Row(
                                modifier = Modifier
                                    .align(Alignment.BottomStart)
                                    .padding(horizontal = 48.dp, vertical = 24.dp)
                                    .fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(24.dp),
                                verticalAlignment = Alignment.Bottom
                            ) {
                                // Poster
                                if (imageRequest != null) {
                                    when (painterState) {
                                        is AsyncImagePainter.State.Loading -> {
                                            Box(
                                                modifier = Modifier
                                                    .width(180.dp)
                                                    .aspectRatio(2f / 3f),
                                                contentAlignment = Alignment.Center
                                            ) {
                                                ImgLoadingProgressRing()
                                            }
                                        }

                                        is AsyncImagePainter.State.Error -> {
                                            Box(
                                                modifier = Modifier
                                                    .width(180.dp)
                                                    .aspectRatio(2f / 3f),
                                                contentAlignment = Alignment.Center
                                            ) {
                                                ImgLoadingError()
                                            }
                                        }

                                        else -> {
                                            Image(
                                                painter = painter,
                                                contentDescription = itemData.title,
                                                modifier = Modifier
                                                    .width(180.dp)
                                                    .aspectRatio(2f / 3f)
                                                    .clip(RoundedCornerShape(8.dp))
                                                    .border(
                                                        1.dp,
                                                        Color.White.copy(alpha = 0.2f),
                                                        RoundedCornerShape(8.dp)
                                                    ),
                                                contentScale = ContentScale.Crop
                                            )
                                        }
                                    }
                                }

                                // Info Column
                                Column(
                                    verticalArrangement = Arrangement.spacedBy(12.dp),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    // Title
                                    Text(
                                        text = itemData.tvTitle,
                                        style = LocalTypography.current.title,
                                        fontWeight = FontWeight.Medium,
                                        color = Color.White,
                                        fontSize = 48.sp,
                                        lineHeight = 56.sp,
                                        maxLines = 2,
                                        overflow = TextOverflow.Ellipsis
                                    )

                                    // Season Name
                                    Text(
                                        text = itemData.title,
                                        style = LocalTypography.current.subtitle,
                                        color = Color.White.copy(alpha = 0.8f),
                                        fontSize = 24.sp
                                    )

                                    // Tags
                                    DetailTags(
                                        itemData = itemData,
                                        smartAnalysisStatusText = smartAnalysisStatusText
                                    )
                                    val player = LocalMediaPlayer.current
                                    val playMedia = rememberPlayMediaFunction(
                                        guid = guid,
                                        player = player,
                                    )
                                    // Buttons
                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(16.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        DetailPlayButton("第 ${playInfo?.item?.episodeNumber} 集") { playMedia() }
                                        CircleIconButton(
                                            icon = Icons.Regular.Checkmark,
                                            description = "已观看",
                                            iconColor = if (isWatched) Colors.AccentColorDefault else FluentTheme.colors.text.text.primary,
                                            onClick = {
                                                watchedViewModel.toggleWatched(
                                                    guid,
                                                    isWatched
                                                )
                                            }
                                        )
                                        MediaMoreFlyout(
//                                            onManageVersionsClick = { isManageVersionsDialogVisible = true },
                                            onSmartAnalysisClick = if (smartAnalysisEnabled) {
                                                {
                                                    val tvTitle = itemData.tvTitle
                                                    val seasonNumber = playInfo?.item?.seasonNumber ?: 0
                                                    smartAnalysisViewModel.analyzeSeason(guid, tvTitle, seasonNumber)
                                                }
                                            } else null,
                                            type = itemData.type
                                        ) { onClick ->
                                            CircleIconButton(
                                                icon = Icons.Regular.MoreHorizontal,
                                                description = "更多",
                                                iconColor = FluentTheme.colors.text.text.primary,
                                                onClick = onClick
                                            )
                                        }
                                    }

                                    // Description
                                    MediaDescription(
                                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                                        itemData = itemData,
                                        isSeason = true,
                                        onClick = {
                                            showDescriptionDialog = true
                                        }
                                    )
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(20.dp))
                }

                item {
                    logger.i("episodeList: $episodeList")
                    val currentEpisodeIndex = remember(episodeList, playInfo) {
                        playInfo?.item?.episodeNumber?.let { episodeNumber ->
                            episodeList.indexOfFirst { it.episodeNumber == episodeNumber }
                        } ?: 0
                    }
                    EpisodesScrollRow(
                        episodes = episodeList,
                        navigator,
                        modifier = Modifier.padding(horizontal = 16.dp),
                        initialIndex = if (currentEpisodeIndex != -1) currentEpisodeIndex else 0
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                }
                if (castScrollRowItemList.isNotEmpty()) {
                    item {
//                        Spacer(modifier = Modifier.height(24.dp))
                        CastScrollRow(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp),
                            castScrollRowItemList
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                    }
                }

                item {
                    if (itemData?.imdbId?.isNotBlank() ?: false) {
                        ImdbLink(
                            FnDataConvertor.getImdbLink(itemData.imdbId),
                            modifier = Modifier.padding(start = 48.dp, end = 48.dp, bottom = 24.dp)
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

//        VersionManagementDialog(
//            visible = isManageVersionsDialogVisible,
//            guid = guid,
//            itemTitle = itemData?.title ?: "",
//            onDismiss = { isManageVersionsDialogVisible = false },
//            onDelete = { _, _ -> },
//            onUnmatchConfirmed = { _, _ -> },
//            onMatchToOther = { _, _ -> }
//        )
    }
}
