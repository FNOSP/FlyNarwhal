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
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ProgressIndicatorDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import coil3.PlatformContext
import coil3.compose.SubcomposeAsyncImage
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.crossfade
import coil3.size.Precision
import coil3.size.Size
import com.jankinwu.fntv.client.LocalRefreshState
import com.jankinwu.fntv.client.LocalStore
import com.jankinwu.fntv.client.LocalTypography
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.convertor.convertPersonToScrollRowItemData
import com.jankinwu.fntv.client.data.convertor.formatSeconds
import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import com.jankinwu.fntv.client.data.model.response.AudioStream
import com.jankinwu.fntv.client.data.model.response.ItemResponse
import com.jankinwu.fntv.client.data.model.response.PersonList
import com.jankinwu.fntv.client.data.model.response.PersonListResponse
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.model.response.StreamListResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.enums.MediaQualityTagEnums
import com.jankinwu.fntv.client.icons.ArrowLeft
import com.jankinwu.fntv.client.icons.ArrowUp
import com.jankinwu.fntv.client.icons.HeartFilled
import com.jankinwu.fntv.client.ui.component.common.CastScrollRow
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingError
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.ToastManager
import com.jankinwu.fntv.client.ui.component.detail.StreamOptionItem
import com.jankinwu.fntv.client.ui.component.detail.StreamSelector
import com.jankinwu.fntv.client.ui.component.detail.noDisplayStream
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.viewmodel.FavoriteViewModel
import com.jankinwu.fntv.client.viewmodel.GenresViewModel
import com.jankinwu.fntv.client.viewmodel.ItemViewModel
import com.jankinwu.fntv.client.viewmodel.PersonListViewModel
import com.jankinwu.fntv.client.viewmodel.PlayInfoViewModel
import com.jankinwu.fntv.client.viewmodel.StreamListViewModel
import com.jankinwu.fntv.client.viewmodel.TagViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.UserInfoViewModel
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
    val userInfoViewModel: UserInfoViewModel = koinViewModel()
    val userInfoUiState by userInfoViewModel.uiState.collectAsState()
    val playInfoViewModel: PlayInfoViewModel = koinViewModel()
    val playInfoUiState by playInfoViewModel.uiState.collectAsState()
    val store = LocalStore.current
    val windowHeight = store.windowHeightState
    val toastManager = rememberToastManager()
    val personListViewModel: PersonListViewModel = koinViewModel()
    val personListState by personListViewModel.uiState.collectAsState()
    var personList: List<PersonList> by remember { mutableStateOf(emptyList()) }
    var scrollRowItemList by remember { mutableStateOf(emptyList<ScrollRowItemData>()) }
    var playInfoResponse: PlayInfoResponse? by remember { mutableStateOf(null) }
    val tagViewModel: TagViewModel = koinViewModel<TagViewModel>()
    val iso6392State by tagViewModel.iso6392State.collectAsState()
    val iso3166State by tagViewModel.iso3166State.collectAsState()
    val genresViewModel: GenresViewModel = koinViewModel<GenresViewModel>()
    val refreshState = LocalRefreshState.current

    LaunchedEffect(Unit) {
        itemViewModel.loadData(guid)
        streamListViewModel.loadData(guid)
        personListViewModel.loadData(guid)
        playInfoViewModel.loadData(guid)
        if (iso6392State !is UiState.Success) {
            tagViewModel.loadIso6392Tags()
        }
        if (iso3166State !is UiState.Success) {
            tagViewModel.loadIso3166Tags()
        }
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
                println("message: ${(itemUiState as UiState.Error).message}")
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
                println("message: ${(streamUiState as UiState.Error).message}")
            }

            else -> {}
        }
    }
    LaunchedEffect(personListState) {
        when (personListState) {
            is UiState.Success -> {
                personList = (personListState as UiState.Success<PersonListResponse>).data.list
                scrollRowItemList = convertPersonToScrollRowItemData(personList)
                print("scrollRowItemList: $scrollRowItemList")
            }

            is UiState.Error -> {
                println("message: ${(personListState as UiState.Error).message}")
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
                println("message: ${(playInfoUiState as UiState.Error).message}")
            }

            else -> {}
        }
    }
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
                    if (itemData != null) {
                        Box(
                            modifier = Modifier
                                .height((windowHeight / 2.dp).dp)
                                .fillMaxWidth(),
                            contentAlignment = Alignment.TopCenter
                        ) {
                            val backdropsImg =
                                if (!itemData?.backdrops.isNullOrBlank()) itemData?.backdrops else itemData?.posters
                            // 背景图
                            SubcomposeAsyncImage(
                                model = ImageRequest.Builder(PlatformContext.INSTANCE)
                                    .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img${backdropsImg}")
                                    .httpHeaders(store.fnImgHeaders)
                                    .crossfade(true)
                                    .size(Size.ORIGINAL)
                                    .build(),
                                contentDescription = itemData?.title,
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
                            // 渐变遮罩层
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(
                                        brush = Brush.verticalGradient(
                                            colors = listOf(
                                                Color.Transparent,
                                                if (store.darkMode) Colors.BackgroundColorDark else Colors.BackgroundColorLight
                                            ),
                                            startY = (windowHeight / 4.dp).dp.value, // 开始渐变的位置
                                            endY = (windowHeight / 2.dp).dp.value    // 结束渐变的位置
                                        )
                                    )
                            )
                            // 标题
                            if (itemData?.logos != null) {
                                var imageHeight by remember { mutableStateOf(90.dp) }
                                SubcomposeAsyncImage(
                                    model = ImageRequest.Builder(PlatformContext.INSTANCE)
                                        .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img${itemData?.logos}")
                                        .httpHeaders(store.fnImgHeaders)
                                        .crossfade(true)
//                                        .size(Size.ORIGINAL)
                                        .precision(Precision.EXACT)
                                        .build(),
                                    contentDescription = itemData?.title,
                                    modifier = Modifier
                                        .align(Alignment.BottomStart)
                                        .height(imageHeight)
                                        .padding(start = 48.dp, bottom = 12.dp),
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
//                                            println("width: $width, height: $height, actualWidth: $actualWidth")
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
                                        .padding(start = 48.dp, end = 48.dp, bottom = 12.dp)
                                ) {
                                    itemData?.title?.let {
                                        Text(
                                            text = it,
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
                }
                item {
                    val currentItem = itemData
                    val currentStream = streamData
                    val playInfoResponse = playInfoResponse
                    if (currentItem != null && currentStream != null && playInfoResponse != null) {
                        MediaInfo(
                            currentItem,
                            currentStream,
                            guid,
                            toastManager,
                            playInfoResponse,
                            iso6392State,
                            iso3166State
                        )
                    }
                }
                item {
                    CastScrollRow(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                        scrollRowItemList
                    )
                }
            }
        }
        // 返回按钮
        IconButton(
            onClick = { navigator.navigateUp() },
            modifier = Modifier
                .padding(16.dp)
                .align(Alignment.TopStart)
                .pointerHoverIcon(PointerIcon.Hand)
        ) {
            Icon(
                imageVector = ArrowLeft,
                contentDescription = "返回",
                tint = Color.White,
                modifier = Modifier.size(24.dp)
            )
        }
        ToastHost(
            toastManager = toastManager,
            modifier = Modifier.fillMaxSize()
        )
    }
}

@Composable
fun MediaInfo(
    itemData: ItemResponse,
    streamData: StreamListResponse,
    guid: String,
    toastManager: ToastManager,
    playInfoResponse: PlayInfoResponse,
    iso6392State: UiState<List<QueryTagResponse>>,
    iso3166State: UiState<List<QueryTagResponse>>
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
    var totalDuration by remember { mutableIntStateOf(0) }
    val reminingDuration = totalDuration.minus(itemData.watchedTs)
    val formatReminingDuration = formatSeconds(reminingDuration)
    val formatTotalDuration = formatSeconds(totalDuration)
    
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
        currentSubtitleStreamList = currentSubtitleStreamList + noDisplayStream
        currentSubtitleStreamGuid = mediaGuidSubTitleGuidMap[currentMediaGuid]
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
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 48.dp, vertical = 24.dp)
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

        MiddleControls(
            modifier = Modifier.padding(bottom = 16.dp),
            itemData,
            formatTotalDuration,
            guid,
            toastManager,
            currentMediaGuid,
            selectedVideoStreamIndex,
            streamData,
            currentAudioStream,
            currentAudioStreamList,
            currentSubtitleStream,
            currentSubtitleStreamList,
            iso6392State,
            iso3166State,
            onAudioSelected = {
                currentAudioStreamGuid = it
                mediaGuidAudioGuidMap[currentMediaGuid] = it
            },
            onSubtitleSelected = {
                currentSubtitleStreamGuid = it
                mediaGuidSubTitleGuidMap[currentMediaGuid] = it
            }
        )

        if (streamData.videoStreams.size > 1) {
            MediaSourceBoxes(modifier = Modifier.padding(bottom = 16.dp), streamData, onClick = {
                selectedVideoStreamIndex = it
            }, selectedVideoStreamIndex)
        }

        MediaDescription(modifier = Modifier.padding(bottom = 32.dp), itemData)
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
    Row(
        modifier = modifier
            .padding(top = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.CenterVertically
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
            color = Colors.PrimaryColor, // 蓝色
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
    formatTotalDuration: String,
    guid: String,
    toastManager: ToastManager,
    mediaGuid: String,
    selectedVideoStreamIndex: Int,
    streamData: StreamListResponse,
    currentAudioStream: AudioStream?,
    currentAudioStreamList: List<AudioStream>,
    currentSubtitleStream: SubtitleStream?,
    currentSubtitleStreamList: List<SubtitleStream>,
    iso6392State: UiState<List<QueryTagResponse>>,
    iso3166State: UiState<List<QueryTagResponse>>,
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
    // 监听收藏操作结果并显示提示
    LaunchedEffect(favoriteUiState) {
        when (val state = favoriteUiState) {
            is UiState.Success -> {
                isFavorite = !isFavorite
                toastManager.showToast(state.data.message, state.data.success)

            }

            is UiState.Error -> {
                // 显示错误提示
                toastManager.showToast("操作失败，${state.message}", false)
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
                toastManager.showToast(state.data.message, state.data.success)
            }

            is UiState.Error -> {
                // 显示错误提示
                toastManager.showToast("操作失败，${state.message}", false)
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
            Button(
                onClick = {
                    playMedia()
                },
                colors = ButtonDefaults.buttonColors(containerColor = Colors.PrimaryColor), // 蓝色背景
                shape = CircleShape, // 圆角
                modifier = Modifier.height(56.dp).width(160.dp).pointerHoverIcon(PointerIcon.Hand)
            ) {
                if (itemData.watchedTs == 0) {
                    Text(
                        "▶  播放",
                        style = LocalTypography.current.title,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                } else {
                    Text(
                        "▶  继续播放",
                        style = LocalTypography.current.title,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
            // 收藏按钮
            CircleIconButton(
                icon = HeartFilled,
                description = "收藏",
                iconColor = if (isFavorite) Colors.DangerColor else FluentTheme.colors.text.text.primary,
                onClick = {
                    favoriteViewModel.toggleFavorite(
                        guid,
                        isFavorite
                    )
                })

            // 是否已观看按钮
            CircleIconButton(
                icon = Icons.Regular.Checkmark, description = "已观看",
                iconColor = if (isWatched) Colors.PrimaryColor else FluentTheme.colors.text.text.primary,
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
            FlowRow(
                modifier = Modifier, // 占据右侧约 60% 宽度
                horizontalArrangement = Arrangement.spacedBy(
                    8.dp,
                    Alignment.End
                ),
                verticalArrangement = Arrangement.Center
            ) {
                val voteAverage = itemData.voteAverage.toDoubleOrNull()?.let {
                    "%.1f".format(it)
                } ?: ""
                if (voteAverage.isNotEmpty() && voteAverage != "0.0") {
                    Text(
                        "$voteAverage 分",
                        color = Color(0xFFFACC15),
                        fontWeight = FontWeight.Normal,
                        fontSize = 14.sp,
//                        modifier = Modifier.offset(y = (-3).dp)
                    )
                    Separator()
                }
                val contentRatings = itemData.contentRatings ?: ""
                if (contentRatings.isNotEmpty()) {
                    Text(
                        contentRatings,
                        color = FluentTheme.colors.text.text.secondary,
                        fontSize = 14.sp
                    )
                    Separator()
                }
                val year = itemData.airDate?.take(4) ?: ""
                if (year.isNotEmpty()) {
                    Text(
                        year,
                        color = FluentTheme.colors.text.text.secondary,
                        fontSize = 14.sp
                    )
                    Separator()
                }
                val genresViewModel: GenresViewModel = koinViewModel<GenresViewModel>()
                val genresUiState = genresViewModel.uiState.collectAsState().value
                LaunchedEffect(genresUiState) {
                    if (genresUiState !is UiState.Success) {
                        genresViewModel.loadGenres()
                    }
                }
                if (genresUiState is UiState.Success) {
                    val genresMap = genresUiState.data.associateBy { it.id }
                    val genresText = itemData.genres?.joinToString(" ") { genreId ->
                        genresMap[genreId]?.value ?: ""
                    }
                    if (!genresText.isNullOrBlank()) {
                        Text(
                            genresText,
                            color = FluentTheme.colors.text.text.secondary,
                            fontSize = 14.sp
                        )
                    }
                    Separator()
                }
                if (iso3166State is UiState.Success) {
                    val iso3166Map = iso3166State.data.associateBy { it.key }
                    val countriesText = itemData.productionCountries?.joinToString(" ") { locate ->
                        iso3166Map[locate]?.value ?: locate
                    }
                    if (!countriesText.isNullOrBlank()) {
                        Text(
                            countriesText,
                            color = FluentTheme.colors.text.text.secondary,
                            fontSize = 14.sp
                        )
                    }
                    Separator()
                }
                Text(
                    formatTotalDuration,
                    color = FluentTheme.colors.text.text.secondary,
                    fontSize = 14.sp
                )
                Separator()
                Text(
                    itemData.ancestorName,
                    color = FluentTheme.colors.text.text.secondary,
                    fontSize = 14.sp
                )

            }
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
                    iso6392State,
                    guid
                )
                AudioSelector(
                    currentAudioStreamList,
                    currentAudioStream,
                    onAudioSelected,
                    iso6392State
                )


//                MediaQualityTag(streamData.videoStreams[selectedVideoStreamIndex].resolutionType)
//                MediaQualityTag(streamData.videoStreams[selectedVideoStreamIndex].colorRangeType)
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
    iso6392State: UiState<List<QueryTagResponse>>
) {
    var iso6392Map: Map<String, QueryTagResponse> by remember { mutableStateOf(mapOf()) }

    if (iso6392State is UiState.Success<List<QueryTagResponse>>) {
        iso6392Map = iso6392State.data.associateBy { it.key }
    }

    val selectorOptions by remember(currentAudioStreamList, iso6392Map, currentAudioStream) {
        derivedStateOf {
            currentAudioStreamList.map { audioStream ->
                val language: String =
                    if (audioStream.language in listOf("", "und", "zxx", "qaa-qtz")) {
                        "未知"
                    } else {
                        iso6392Map[audioStream.language]?.value ?: audioStream.language
                    }
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
    val selectedLanguage: String =
        if (currentAudioStream?.language in listOf("", "und", "zxx", "qaa-qtz")) {
            "未知音频"
        } else if (currentAudioStream?.language == null) {
            "未知音频"
        } else {
            (iso6392Map[currentAudioStream.language]?.value
                ?: currentAudioStream.language) + "音频"
        }
    StreamSelector(
        selectorOptions,
        selectedLanguage,
        onAudioSelected,
    )
}

@Composable
fun SubtitleSelector(
    currentSubtitleStreamList: List<SubtitleStream>,
    currentSubtitleStream: SubtitleStream?,
    onSubtitleSelected: (String) -> Unit,
    iso6392State: UiState<List<QueryTagResponse>>,
    guid: String =  ""
) {
    var iso6392Map: Map<String, QueryTagResponse> by remember { mutableStateOf(mapOf()) }

    if (iso6392State is UiState.Success<List<QueryTagResponse>>) {
        iso6392Map = iso6392State.data.associateBy { it.key }
    }

    val selectorOptions by remember(currentSubtitleStreamList, iso6392Map, currentSubtitleStream) {
        derivedStateOf {
            currentSubtitleStreamList.map { subtitleStream ->
                val language: String =
                    if (subtitleStream.language in listOf("", "und", "zxx", "qaa-qtz")) {
                        "未知"
                    } else {
                        iso6392Map[subtitleStream.language]?.value ?: subtitleStream.language
                    }
                StreamOptionItem(
                    optionGuid = subtitleStream.guid,
                    title = language,
                    subtitle1 = subtitleStream.format.uppercase(),
                    subtitle3 = subtitleStream.title,
//                    subtitle2 = "",
                    isDefault = subtitleStream.isDefault == 1,
                    isSelected = subtitleStream.guid == currentSubtitleStream?.guid
                )
            }
        }
    }
    val selectedLanguage: String =
        when (currentSubtitleStream?.language) {
            in listOf("", "und", "zxx", "qaa-qtz") -> {
                "未知字幕"
            }
            null -> {
                "未知字幕"
            }
            else -> {
                (iso6392Map[currentSubtitleStream.language]?.value
                    ?: currentSubtitleStream.language) + "字幕"
            }
        }
    StreamSelector(selectorOptions, selectedLanguage, onSubtitleSelected, true,
        currentSubtitleStream?.mediaGuid ?: "", guid
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

@Composable
fun MediaDescription(modifier: Modifier = Modifier, itemData: ItemResponse?) {
    val processedOverview = itemData?.overview?.replace("\n\n", "\n") ?: ""
    Text(
        text = processedOverview,
        style = LocalTypography.current.body,
        color = FluentTheme.colors.text.text.secondary,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        modifier = modifier.fillMaxWidth()
    )
}

/**
 *
 */
@Composable
fun InfoIconText(text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(text = text, color = FluentTheme.colors.text.text.secondary, fontSize = 14.sp)
        Icon(
            imageVector = ArrowUp,
            contentDescription = text,
            tint = FluentTheme.colors.text.text.tertiary,
            modifier = Modifier.size(16.dp)
        )
    }
}

/**
 * 质量标签
 */
@Composable
fun MediaQualityTag(qualityTag: String) {
    val store = LocalStore.current
    if (qualityTag.endsWith("k")) {
        Box(
            modifier = Modifier
//                .padding(2.dp)
//                .height(16.dp)
                .background(
                    color = FluentTheme.colors.stroke.control.default.copy(alpha = 0.5f),
                    shape = RoundedCornerShape(4.dp)
                )
                .padding(
                    horizontal = 6.dp,
//                    vertical = 1.dp
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = qualityTag.uppercase(),
                style = LocalTypography.current.body,
                color = if (store.darkMode) Colors.BackgroundColorDark else Colors.BackgroundColorLight,
                fontSize = 14.sp,
//                lineHeight = 5.sp,
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
//                .height(16.dp)
                .border(
                    1.5.dp,
                    FluentTheme.colors.stroke.control.default.copy(alpha = 0.5f),
                    RoundedCornerShape(4.dp)
                )
                .padding(
                    start = 4.dp, end = 4.dp, bottom = 2.dp
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = qualityTag,
                style = LocalTypography.current.body,
                color = FluentTheme.colors.stroke.control.default.copy(alpha = 0.5f),
                fontSize = 13.sp,
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
                    .height(24.dp),
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
    val textColor = if (isSelected) Colors.PrimaryColor else FluentTheme.colors.text.text.primary
    val backgroundColor by animateColorAsState(
        targetValue = if (isHovered) FluentTheme.colors.stroke.control.default.copy(alpha = 0.02f) else Color.Transparent
    )
    val borderColor by animateColorAsState(
        targetValue = if (isSelected) {
            Colors.PrimaryColor
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