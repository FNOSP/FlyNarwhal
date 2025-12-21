package com.jankinwu.fntv.client.ui.screen

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ProgressIndicatorDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
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
import com.jankinwu.fntv.client.data.convertor.convertPersonToScrollRowItemData
import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import com.jankinwu.fntv.client.data.model.response.AudioStream
import com.jankinwu.fntv.client.data.model.response.FileInfo
import com.jankinwu.fntv.client.data.model.response.ItemResponse
import com.jankinwu.fntv.client.data.model.response.PersonList
import com.jankinwu.fntv.client.data.model.response.PersonListResponse
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.model.response.StreamListResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.enums.MediaQualityTagEnums
import com.jankinwu.fntv.client.icons.HeartFilled
import com.jankinwu.fntv.client.ui.component.common.BackButton
import com.jankinwu.fntv.client.ui.component.common.CastScrollRow
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingError
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.component.detail.DetailPlayButton
import com.jankinwu.fntv.client.ui.component.detail.DetailTags
import com.jankinwu.fntv.client.ui.component.detail.MediaDescription
import com.jankinwu.fntv.client.ui.component.detail.MediaDescriptionDialog
import com.jankinwu.fntv.client.ui.component.detail.MediaInfo
import com.jankinwu.fntv.client.ui.component.detail.StreamOptionItem
import com.jankinwu.fntv.client.ui.component.detail.StreamSelector
import com.jankinwu.fntv.client.ui.component.detail.noDisplayStream
import com.jankinwu.fntv.client.ui.providable.CurrentStreamData
import com.jankinwu.fntv.client.ui.providable.IsoTagData
import com.jankinwu.fntv.client.ui.providable.LocalFileInfo
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
import com.jankinwu.fntv.client.viewmodel.PersonListViewModel
import com.jankinwu.fntv.client.viewmodel.PlayInfoViewModel
import com.jankinwu.fntv.client.viewmodel.StreamListViewModel
import com.jankinwu.fntv.client.viewmodel.TagViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.WatchedViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.Icon
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.rememberScrollbarAdapter
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Checkmark
import io.github.composefluent.icons.regular.MoreHorizontal
import kotlinx.coroutines.delay
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.viewmodel.koinViewModel

private val logger = Logger.withTag("MovieDetailScreen")

@Composable
fun MovieDetailScreen(
    guid: String,
    navigator: ComponentNavigator
) {
    val itemViewModel: ItemViewModel = koinViewModel()
    val itemUiState by itemViewModel.uiState.collectAsState()
    var itemData: ItemResponse? by remember { mutableStateOf(null) }
    val streamListViewModel: StreamListViewModel = koinViewModel()
    val streamUiState by streamListViewModel.uiState.collectAsState()
    var streamData: StreamListResponse? by remember { mutableStateOf(null) }
    val playInfoViewModel: PlayInfoViewModel = koinViewModel()
    val playInfoUiState by playInfoViewModel.uiState.collectAsState()
    val personListViewModel: PersonListViewModel = koinViewModel()
    val personListState by personListViewModel.uiState.collectAsState()
    var personList: List<PersonList> by remember { mutableStateOf(emptyList()) }
    var castScrollRowItemList by remember { mutableStateOf(emptyList<ScrollRowItemData>()) }
    var playInfoResponse: PlayInfoResponse? by remember { mutableStateOf(null) }
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
    var currentMediaGuid by remember(guid) { mutableStateOf(playInfoResponse?.mediaGuid ?: "") }
    var currentStreamData: CurrentStreamData? by remember(guid) { mutableStateOf(null) }
    val toastManager = rememberToastManager()
    val playerManager = LocalPlayerManager.current
    var isFirstLoad by remember(guid) { mutableStateOf(true) }
    // 当从播放器返回时刷新最近播放列表
    LaunchedEffect(playerManager.playerState) {
        if (!playerManager.playerState.isVisible && !isFirstLoad) {
            itemViewModel.loadData(guid)
            playInfoViewModel.loadData(guid)
            streamListViewModel.loadData(guid)
        }
    }
    LaunchedEffect(Unit) {
        itemViewModel.loadData(guid)
        streamListViewModel.loadData(guid)
        personListViewModel.loadData(guid)
        playInfoViewModel.loadData(guid)
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
//            refreshState.onRefresh()
            // 执行当前页面的特定刷新逻辑
            itemViewModel.loadData(guid)
            streamListViewModel.loadData(guid)
            personListViewModel.loadData(guid)
            playInfoViewModel.loadData(guid)
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
                logger.i("message: ${(itemUiState as UiState.Error).message}")
            }

            else -> {}
        }
    }
    LaunchedEffect(streamUiState) {
        when (streamUiState) {
            is UiState.Success -> {
                streamData = (streamUiState as UiState.Success<StreamListResponse>).data
            }

            is UiState.Error -> {
                logger.i("message: ${(streamUiState as UiState.Error).message}")
            }

            else -> {}
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
                logger.e("message: ${(personListState as UiState.Error).message}")
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
                logger.e("message: ${(playInfoUiState as UiState.Error).message}")
            }

            else -> {}
        }
    }
    LaunchedEffect(currentMediaGuid) {
        val streamData = streamData
        if (currentMediaGuid.isNotBlank() && streamData != null) {
            logger.i("currentGuid: $currentMediaGuid, streamData: $streamData")
            val currentFileInfo = streamData.files?.firstOrNull {
                it.guid == currentMediaGuid
            }

            val currentVideoStream = streamData.videoStreams
                .firstOrNull {
                    it.mediaGuid == currentMediaGuid
                }
            val currentAudioStreamList = streamData.audioStreams
                .filter {
                    it.mediaGuid == currentMediaGuid
                }
            val currentSubtitleStreamList = streamData.subtitleStreams
                .filter {
                    it.mediaGuid == currentMediaGuid
                }
            currentStreamData = CurrentStreamData(
                currentFileInfo,
                currentVideoStream,
                currentAudioStreamList,
                currentSubtitleStreamList
            )
        }
    }
    LaunchedEffect(iso6391State, iso6392State, iso3166State) {
        val newIso6391Map = if (iso6391State is UiState.Success) {
            (iso6391State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
        } else {
            emptyMap()
        }

        val newIso6392Map = if (iso6392State is UiState.Success) {
            (iso6392State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
        } else {
            emptyMap()
        }

        val newIso3166Map = if (iso3166State is UiState.Success) {
            (iso3166State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
        } else {
            emptyMap()
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
        val currentItem = itemData
        val currentStream = streamData
        val playInfoResponse = playInfoResponse
        MovieDetailBody(
            currentItem,
            currentStream,
            playInfoResponse,
            guid,
            currentStreamData,
            castScrollRowItemList,
            navigator,
            onMediaGuidChanged = { currentMediaGuid = it }
        )
    }
}

@Composable
fun MovieDetailBody(
    itemData: ItemResponse?,
    streamData: StreamListResponse?,
    playInfoResponse: PlayInfoResponse?,
    guid: String,
    currentStreamData: CurrentStreamData?,
    castScrollRowItemList: List<ScrollRowItemData>,
    navigator: ComponentNavigator,
    onMediaGuidChanged: (String) -> Unit
) {
    val store = LocalStore.current
    val windowHeight = store.windowHeightState
    val toastManager = LocalToastManager.current
    var showDescriptionDialog by remember { mutableStateOf(false) }
    Box(
        modifier = Modifier
            .fillMaxSize()
//            .background(Color(0xFF2D2D2D))
    ) {
        val lazyListState = rememberLazyListState()
        ScrollbarContainer(
            adapter = rememberScrollbarAdapter(lazyListState)
        ) {
            LazyColumn(
                state = lazyListState,
            ) {
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
                            // 背景图
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
                                loading = {
                                    ImgLoadingProgressRing()
                                },
                                error = {
                                    ImgLoadingError()
                                },
                            )
                        }
                        // 渐变遮罩层
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(
                                    brush = Brush.verticalGradient(
                                        colorStops = arrayOf(
                                            0.45f to Color.Transparent, // 从顶部 50% 的位置开始（对应你原来的 startY = H/4, 总高度 H/2）
                                            1.0f to if (store.darkMode) Colors.BackgroundColorDark else Colors.BackgroundColorLight // 到 100% 的位置结束
                                        )
                                    )
                                )
                        )
                        // 标题
                        if (itemData != null && itemData.logos != null) {
                            var imageHeight by remember { mutableStateOf(90.dp) }
                            SubcomposeAsyncImage(
                                model = ImageRequest.Builder(PlatformContext.INSTANCE)
                                    .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img${itemData.logos}")
                                    .httpHeaders(store.fnImgHeaders)
                                    .crossfade(true)
//                                        .size(Size.ORIGINAL)
                                    .precision(Precision.EXACT)
                                    .build(),
                                contentDescription = itemData.title,
                                modifier = Modifier
                                    .align(Alignment.BottomStart)
                                    .height(imageHeight)
                                    .padding(start = 48.dp),
                                contentScale = ContentScale.FillHeight,
                                filterQuality = FilterQuality.High,
                                loading = {
                                    ImgLoadingProgressRing()
                                },
                                error = {
                                    ImgLoadingError()
                                },
                                onSuccess = { state ->
                                    // 获取图片尺寸并判断是否需要调整高度
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
//                                        .width(200.dp)
                                    .padding(start = 48.dp, end = 48.dp)
                            ) {
                                Text(
                                    text = itemData?.title ?: "",
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
                item {
                    val playInfoResponse = playInfoResponse
                    if (itemData != null && streamData != null && playInfoResponse != null) {
                        Spacer(modifier = Modifier.height(24.dp))
                        MediaIntroduction(
                            itemData,
                            streamData,
                            guid,
                            playInfoResponse,
                            modifier = Modifier
                                .padding(horizontal = 48.dp),
                            onMediaGuidChanged = {
                                onMediaGuidChanged(it)
                            },
                            onShowDescriptionDialog = {
                                showDescriptionDialog = true
                            },
                        )
                    }
                    Spacer(modifier = Modifier.height(20.dp))
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
                        Spacer(modifier = Modifier.height(48.dp))
                    }
                }
                item {
//                    Spacer(modifier = Modifier.height(24.dp))
                    currentStreamData?.let {
                        MediaInfo(
                            modifier = Modifier.padding(horizontal = 48.dp), it,
                            itemData?.imdbId
                        )
                    }
                    Spacer(modifier = Modifier.height(24.dp))
                }
            }
        }
        // 返回按钮
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
fun MediaIntroduction(
    itemData: ItemResponse,
    streamData: StreamListResponse,
    guid: String,
    playInfoResponse: PlayInfoResponse,
    modifier: Modifier = Modifier,
    onMediaGuidChanged: (String) -> Unit = {},
    onShowDescriptionDialog: () -> Unit = {}
) {
    var currentMediaGuid by remember { mutableStateOf(playInfoResponse.mediaGuid) }
    var selectedVideoStreamIndex by remember { mutableIntStateOf(0) }
    val mediaGuidAudioGuidMap = remember { mutableMapOf<String, String>() }
    var currentAudioStreamGuid: String? by remember { mutableStateOf("") }
    var currentAudioStream: AudioStream? by remember { mutableStateOf(null) }
    var currentAudioStreamList by remember { mutableStateOf<List<AudioStream>>(emptyList()) }
    val mediaGuidSubTitleGuidMap = remember { mutableMapOf<String, String>() }
    var currentSubtitleStreamGuid: String? by remember { mutableStateOf("") }
    var currentSubtitleStream: SubtitleStream? by remember { mutableStateOf(null) }
    var currentSubtitleStreamList by remember { mutableStateOf<List<SubtitleStream>>(emptyList()) }
    var currentFileInfo: FileInfo? by remember { mutableStateOf(null) }
    var totalDuration by remember { mutableIntStateOf(0) }
    val reminingDuration = totalDuration.minus(itemData.watchedTs)
    val formatReminingDuration = FnDataConvertor.formatSecondsToCNDateTime(reminingDuration)
    val formatedTotalDuration = FnDataConvertor.formatSecondsToCNDateTime(totalDuration)

    LaunchedEffect(guid, streamData, playInfoResponse) {
        currentMediaGuid = playInfoResponse.mediaGuid
        mediaGuidAudioGuidMap.clear()
        mediaGuidSubTitleGuidMap.clear()
//        currentAudioStreamGuid = null // 重置音频流GUID
//        currentAudioStream = null // 重置音频流对象
//        currentSubtitleStreamGuid = null
//        currentSubtitleStream = null

        // 如果和 playInfo 的 audioGuid 相等，则使用，否则使用默认
        streamData.audioStreams.forEach { audioStream ->
            if (audioStream.guid == playInfoResponse.audioGuid) {
                mediaGuidAudioGuidMap[audioStream.mediaGuid] = audioStream.guid
                currentAudioStreamGuid = audioStream.guid
            } else if (audioStream.isDefault == 1) {
                mediaGuidAudioGuidMap[audioStream.mediaGuid] = audioStream.guid
            }
        }
        streamData.subtitleStreams.forEach { subtitleStream ->
            if (playInfoResponse.subtitleGuid == "_no_display_") {
                mediaGuidSubTitleGuidMap[subtitleStream.mediaGuid] = "_no_display_"
                currentSubtitleStreamGuid = "_no_display_"
            } else if (subtitleStream.guid == playInfoResponse.subtitleGuid) {
                mediaGuidSubTitleGuidMap[subtitleStream.mediaGuid] = subtitleStream.guid
                currentSubtitleStreamGuid = subtitleStream.guid
            } else if (subtitleStream.isDefault == 1) {
                mediaGuidSubTitleGuidMap[subtitleStream.mediaGuid] = subtitleStream.guid
            }
        }
    }

    LaunchedEffect(currentMediaGuid, guid, streamData) {
        streamData.videoStreams.forEach {
            if (it.mediaGuid == currentMediaGuid) {
                selectedVideoStreamIndex = streamData.videoStreams.indexOf(it)
                totalDuration = streamData.videoStreams[selectedVideoStreamIndex].duration
            }
        }
        currentAudioStreamList = streamData.audioStreams
            .filter {
                it.mediaGuid == currentMediaGuid
            }
//            .sortedByDescending { it.index }
        currentAudioStreamGuid = mediaGuidAudioGuidMap[currentMediaGuid]
        currentSubtitleStreamList = streamData.subtitleStreams
            .filter {
                it.mediaGuid == currentMediaGuid
            }
//            .sortedByDescending { it.index }
        currentSubtitleStreamList = listOf(noDisplayStream) + currentSubtitleStreamList
        currentSubtitleStreamGuid = mediaGuidSubTitleGuidMap[currentMediaGuid]
        currentFileInfo = streamData.files?.firstOrNull {
            it.guid == currentMediaGuid
        }
        onMediaGuidChanged(currentMediaGuid)
    }

    LaunchedEffect(selectedVideoStreamIndex, guid) {
        currentMediaGuid = streamData.videoStreams[selectedVideoStreamIndex].mediaGuid
    }

    LaunchedEffect(currentAudioStreamGuid, guid) {
        currentAudioStream = streamData.audioStreams.firstOrNull {
            it.guid == currentAudioStreamGuid
        }
    }
    LaunchedEffect(currentSubtitleStreamGuid, guid) {
        currentSubtitleStream = if (currentSubtitleStreamGuid == "_no_display_") {
            noDisplayStream
        } else {
            streamData.subtitleStreams.firstOrNull {
                it.guid == currentSubtitleStreamGuid
            }
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
//            .padding(vertical = 24.dp)
    ) {
        // 进度条
        itemData.watchedTs.let {
            if (it > 0) {
                ProgressBar(
                    modifier = Modifier.padding(bottom = 8.dp),
                    totalDuration,
                    itemData.watchedTs,
                    formatReminingDuration
                )
            }
        }
        CompositionLocalProvider(
            LocalFileInfo provides currentFileInfo
        ) {
            MiddleControls(
                modifier = Modifier.padding(bottom = 16.dp),
                itemData,
                formatedTotalDuration,
                guid,
                currentMediaGuid,
                selectedVideoStreamIndex,
                streamData,
                currentAudioStream,
                currentAudioStreamList,
                currentSubtitleStream,
                currentSubtitleStreamList,
                onAudioSelected = {
                    currentAudioStreamGuid = it
                    mediaGuidAudioGuidMap[currentMediaGuid] = it
                },
                onSubtitleSelected = {
                    currentSubtitleStreamGuid = it
                    mediaGuidSubTitleGuidMap[currentMediaGuid] = it
                }
            )
        }

        if (streamData.videoStreams.size > 1) {
            MediaSourceBoxes(modifier = Modifier.padding(bottom = 16.dp), streamData, onClick = {
                selectedVideoStreamIndex = it
            }, selectedVideoStreamIndex)
        }
        if (!itemData.overview.isNullOrBlank()) {
            MediaDescription(modifier = Modifier.padding(bottom = 32.dp), itemData, onClick = {
                onShowDescriptionDialog()
            })
        }
    }
}

@Composable
fun MediaSourceBoxes(
    modifier: Modifier = Modifier,
    streamData: StreamListResponse,
    onClick: (index: Int) -> Unit,
    selectedVideoStreamIndex: Int
) {
    var selectedTagIndex by remember { mutableIntStateOf(selectedVideoStreamIndex) }
    LaunchedEffect(selectedVideoStreamIndex) {
        selectedTagIndex = selectedVideoStreamIndex
    }
    FlowRow(
        modifier = modifier
            .padding(top = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)
    ) {
        val qualityTags = streamData.videoStreams.map {
            val colorRangeType = when (it.colorRangeType) {
                "DolbyVision" -> "杜比视界"
                else -> it.colorRangeType
            }
            "${it.resolutionType.uppercase()} $colorRangeType"
        }
        qualityTags.forEachIndexed { index, quality ->
            VideoSelectionBox(
                text = quality,
                onClick = {
                    selectedTagIndex = index // 点击时更新选中索引
                    onClick(index)
                },
                isSelected = index == selectedTagIndex // 判断是否为当前选中项
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun ProgressBar(
    modifier: Modifier = Modifier,
    totalDuration: Int,
    watchedTs: Int,
    formatReminingDuration: String,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically
    ) {
        LinearProgressIndicator(
            progress = {
                (watchedTs.toFloat() / totalDuration.toFloat())
            },
            modifier = Modifier.width(300.dp),
            color = Colors.AccentColorDefault, // 蓝色
            trackColor = Color.DarkGray.copy(alpha = 0.4f),
            strokeCap = ProgressIndicatorDefaults.CircularDeterminateStrokeCap,
            gapSize = 0.dp,
            drawStopIndicator = {}
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = "剩余 $formatReminingDuration",
            color = FluentTheme.colors.text.text.secondary,
            fontSize = 12.sp
        )
    }
}

@Composable
fun MiddleControls(
    modifier: Modifier = Modifier,
    itemData: ItemResponse,
    formatedTotalDuration: String,
    guid: String,
    mediaGuid: String,
    selectedVideoStreamIndex: Int,
    streamData: StreamListResponse,
    currentAudioStream: AudioStream?,
    currentAudioStreamList: List<AudioStream>,
    currentSubtitleStream: SubtitleStream?,
    currentSubtitleStreamList: List<SubtitleStream>,
    onAudioSelected: (audioGuid: String) -> Unit,
    onSubtitleSelected: (subtitleGuid: String) -> Unit
) {
    val player = LocalMediaPlayer.current
    val playMedia = rememberPlayMediaFunction(
        guid = guid,
        player = player,
        mediaGuid = mediaGuid,
        currentAudioGuid = currentAudioStream?.guid,
        currentSubtitleGuid = currentSubtitleStream?.guid
    )
    val favoriteViewModel: FavoriteViewModel = koinViewModel<FavoriteViewModel>()
    val favoriteUiState by favoriteViewModel.uiState.collectAsState()
    var isFavorite by remember(itemData.isFavorite == 1) { mutableStateOf(itemData.isFavorite == 1) }
    val watchedViewModel: WatchedViewModel = koinViewModel<WatchedViewModel>()
    val watchedUiState by watchedViewModel.uiState.collectAsState()
    var isWatched by remember(itemData.isWatched == 1) { mutableStateOf(itemData.isWatched == 1) }
    val streamListViewModel: StreamListViewModel = koinViewModel()
    val itemViewModel: ItemViewModel = koinViewModel()
    val toastManager = LocalToastManager.current

    // 监听收藏操作结果并显示提示
    LaunchedEffect(favoriteUiState) {
        when (val state = favoriteUiState) {
            is UiState.Success -> {
                isFavorite = !isFavorite
                toastManager.showToast(state.data.message, if (state.data.success) ToastType.Success else ToastType.Failed)

            }

            is UiState.Error -> {
                // 显示错误提示
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

    // 监听已观看操作结果并显示提示
    LaunchedEffect(watchedUiState) {
        when (val state = watchedUiState) {
            is UiState.Success -> {
                streamListViewModel.loadData(guid)
                itemViewModel.loadData(guid)
                toastManager.showToast(state.data.message, if (state.data.success) ToastType.Success else ToastType.Failed)
            }

            is UiState.Error -> {
                // 显示错误提示
                toastManager.showToast("操作失败，${state.message}", ToastType.Failed)
            }

            else -> {}
        }

        // 清除状态
        if (watchedUiState is UiState.Success || watchedUiState is UiState.Error) {
            delay(2000) // 2秒后清除状态
            watchedViewModel.clearError()
        }
    }

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        // 第一行：播放、收藏、更多
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(end = 64.dp)
        ) {
            // 播放按钮
            if (itemData.watchedTs == 0) {
                DetailPlayButton("播放") { playMedia() }
            } else {
                DetailPlayButton("继续播放") { playMedia() }
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
            CircleIconButton(
                icon = Icons.Regular.MoreHorizontal,
                description = "更多",
                onClick = {},
                iconColor = FluentTheme.colors.text.text.primary
            )
        }

        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically)
        ) {
            // 右侧：评分、标签
            // 使用 FlowRow 可以在空间不足时自动换行
            DetailTags(itemData, formatedTotalDuration)
            // 第二行：4K 标签
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.height(24.dp)
            ) {
//                InfoIconText("中文字幕")
                SubtitleSelector(
                    currentSubtitleStreamList,
                    currentSubtitleStream,
                    onSubtitleSelected,
                    guid,
                    mediaGuid
                )
                AudioSelector(
                    currentAudioStreamList,
                    currentAudioStream,
                    onAudioSelected
                )

                val safeCurrentVideoStream by remember(streamData, selectedVideoStreamIndex) {
                    derivedStateOf {
                        if (streamData.videoStreams.isNotEmpty() &&
                            selectedVideoStreamIndex >= 0 &&
                            selectedVideoStreamIndex < streamData.videoStreams.size
                        ) {
                            streamData.videoStreams[selectedVideoStreamIndex]
                        } else {
                            null
                        }
                    }
                }

                // 使用安全引用来渲染标签
                safeCurrentVideoStream?.let { videoStream ->
                    MediaQualityTag(videoStream.resolutionType)
                    MediaQualityTag(videoStream.colorRangeType)
                }
                MediaQualityTag(currentAudioStream?.audioType ?: "")
            }
        }
    }
}

@Composable
fun AudioSelector(
    currentAudioStreamList: List<AudioStream>,
    currentAudioStream: AudioStream?,
    onAudioSelected: (String) -> Unit,
) {
    val isoTagData = LocalIsoTagData.current
    val iso6392Map = isoTagData.iso6392Map

    val selectorOptions by remember(currentAudioStreamList, iso6392Map, currentAudioStream) {
        derivedStateOf {
            currentAudioStreamList.map { audioStream ->
                val language: String = FnDataConvertor.getLanguageName(audioStream.language, isoTagData)
                StreamOptionItem(
                    optionGuid = audioStream.guid,
                    title = language,
                    subtitle1 = audioStream.codecName,
                    subtitle3 = audioStream.title,
                    subtitle2 = audioStream.channelLayout,
                    isDefault = audioStream.isDefault == 1,
                    isSelected = audioStream.guid == currentAudioStream?.guid
                )
            }
        }
    }
    val selectedLanguage: String = FnDataConvertor.getLanguageName(currentAudioStream?.language, isoTagData) + "音频"
    val selectedIndex by remember(selectorOptions, currentAudioStream) {
        derivedStateOf {
            currentAudioStreamList.indexOfFirst { it.guid == currentAudioStream?.guid }
        }
    }
    StreamSelector(
        selectorOptions,
        selectedLanguage,
        onAudioSelected,
        selectedIndex = selectedIndex
    )
}

@Composable
fun SubtitleSelector(
    currentSubtitleStreamList: List<SubtitleStream>,
    currentSubtitleStream: SubtitleStream?,
    onSubtitleSelected: (String) -> Unit,
    guid: String = "",
    mediaGuid: String = "",
) {
    val isoTagData = LocalIsoTagData.current
    val iso6391Map = isoTagData.iso6391Map
    val iso6392Map = isoTagData.iso6392Map

    val selectorOptions by remember(currentSubtitleStreamList, iso6392Map, iso6391Map, currentSubtitleStream) {
        derivedStateOf {
            currentSubtitleStreamList.map { subtitleStream ->
                val languageTitle: String =FnDataConvertor.getLanguageName(
                    subtitleStream.language,
                    isoTagData
                )
                StreamOptionItem(
                    optionGuid = subtitleStream.guid,
                    title = if (subtitleStream.isExternal == 1) "$languageTitle - 外挂" else languageTitle,
                    subtitle1 = subtitleStream.format.uppercase(),
                    subtitle3 = subtitleStream.title,
//                    subtitle2 = "",
                    isDefault = subtitleStream.isDefault == 1,
                    isSelected = subtitleStream.guid == currentSubtitleStream?.guid,
                    isExternal = subtitleStream.isExternal == 1
                )
            }
        }
    }
    val selectedLanguage: String = FnDataConvertor.getLanguageName(
        currentSubtitleStream?.language,
        isoTagData
    ) + "字幕"
    val selectedIndex by remember(currentSubtitleStream) {
        derivedStateOf {
            currentSubtitleStreamList.indexOfFirst { it.guid == currentSubtitleStream?.guid }
        }
    }
    val trimIdList = currentSubtitleStreamList.map { it.trimId }.filter { it.isNotBlank() }.toList()
    StreamSelector(
        selectorOptions,
        selectedLanguage,
        onSubtitleSelected,
        true,
        mediaGuid,
        guid,
        selectedIndex,
        trimIdList,
    )
}

@Composable
fun Separator() {
    Text(
        "/",
        color = FluentTheme.colors.text.text.disabled.copy(alpha = 0.1f),
        fontSize = 16.sp,
        modifier = Modifier.offset(y = (-3).dp)
    )
}

/**
 * 质量标签
 */
@Composable
fun MediaQualityTag(qualityTag: String, scale: Float = 1f) {
    val store = LocalStore.current
    if (qualityTag.endsWith("k")) {
        Box(
            modifier = Modifier
                .graphicsLayer(scaleX = scale, scaleY = scale)
                .background(
                    color = FluentTheme.colors.stroke.control.default.copy(alpha = 0.5f),
                    shape = RoundedCornerShape(4.dp * scale)
                )
                .padding(
                    horizontal = 7.dp * scale,
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = qualityTag.uppercase(),
                style = LocalTypography.current.body,
                color = if (store.darkMode) Colors.BackgroundColorDark else Colors.BackgroundColorLight,
                fontSize = 14.sp * scale,
                fontWeight = FontWeight.Bold
            )
        }
    } else if (qualityTag.endsWith("p") || qualityTag in listOf(
            "HLG",
            "Stereo",
            "SDR"
        ) || qualityTag.startsWith("HDR")
    ) {
        var qualityTag = when (qualityTag) {
            "Stereo" -> "立体声"
            "HDR10" -> "HDR"
            else -> qualityTag
        }
        if (qualityTag.endsWith("p")) {
            qualityTag = qualityTag.dropLast(1)
        }
        Box(
            modifier = Modifier
                .graphicsLayer(scaleX = scale, scaleY = scale)
                .border(
                    1.5.dp * scale,
                    FluentTheme.colors.stroke.control.default.copy(alpha = 0.5f),
                    RoundedCornerShape(4.dp * scale)
                )
                .padding(
                    top = if(qualityTag.contains("立体声")) 2.dp * scale else 0.dp,
                    start = 4.dp * scale,
                    end = 4.dp * scale,
                    bottom = 2.dp * scale
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = qualityTag,
                style = LocalTypography.current.body,
                color = FluentTheme.colors.stroke.control.default.copy(alpha = 0.5f),
                fontSize = 13.sp * scale,
                fontWeight = FontWeight.Medium
            )
        }
    } else if (qualityTag in listOf("DolbySurround", "DolbyVision", "DTS", "DolbyAtmos")) {
        val drawableSource = MediaQualityTagEnums.getDrawableByTagName(qualityTag)
        if (drawableSource != null) {
            Image(
                painterResource(drawableSource),
                contentDescription = "质量 logo",
                modifier = Modifier
                    .graphicsLayer(scaleX = scale, scaleY = scale)
                    .height(24.dp * scale),
                colorFilter = ColorFilter.tint(FluentTheme.colors.stroke.control.default.copy(alpha = 0.5f))
            )
        }
    }
}

/**
 * 中间的圆形图标按钮
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun CircleIconButton(
    icon: ImageVector,
    description: String,
    iconColor: Color,
    onClick: () -> Unit
) {
    var isHovered by remember { mutableStateOf(false) }
    val backgroundColor by animateColorAsState(
        targetValue = if (isHovered) FluentTheme.colors.stroke.control.default.copy(alpha = 0.02f) else Color.Transparent
    )
    val borderColor by animateColorAsState(
        targetValue = if (isHovered) FluentTheme.colors.stroke.control.default.copy(alpha = 0.3f) else FluentTheme.colors.stroke.control.default.copy(
            alpha = 0.1f
        )
    )
    Box(
        modifier = Modifier
            .size(56.dp)
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .border(1.dp, borderColor, CircleShape)
            .background(backgroundColor, CircleShape)
            .pointerHoverIcon(PointerIcon.Hand)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            icon,
            contentDescription = description,
            tint = iconColor,
            modifier = Modifier
                .size(25.dp)
        )
    }
}

/**
 * 媒体源选择框
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun VideoSelectionBox(text: String, onClick: () -> Unit, isSelected: Boolean) {
    var isHovered by remember { mutableStateOf(false) }
    val textColor =
        if (isSelected) Colors.AccentColorDefault else FluentTheme.colors.text.text.primary
    val backgroundColor by animateColorAsState(
        targetValue = if (isHovered) FluentTheme.colors.stroke.control.default.copy(alpha = 0.02f) else Color.Transparent
    )
    val borderColor by animateColorAsState(
        targetValue = if (isSelected) {
            Colors.AccentColorDefault
        } else if (isHovered) FluentTheme.colors.stroke.control.default.copy(alpha = 0.3f) else FluentTheme.colors.stroke.control.default.copy(
            alpha = 0.1f
        )
    )
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .border(
                if (isSelected) 2.dp else 1.dp,
                borderColor,
                RoundedCornerShape(8.dp)
            )
            .background(
                backgroundColor,
                RoundedCornerShape(8.dp)
            )
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .width(128.dp)
            .height(36.dp)
            .clickable(
                interactionSource = remember { MutableInteractionSource() }, // 添加这行
                indication = null,
                onClick = onClick,
            )
            .pointerHoverIcon(PointerIcon.Hand)
    ) {
        Text(
            text = text,
            color = textColor,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
        )
    }
}