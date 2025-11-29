package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
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
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
import com.jankinwu.fntv.client.data.model.response.ItemResponse
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.ui.component.common.BackButton
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingError
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.component.detail.ImdbLink
import com.jankinwu.fntv.client.ui.providable.IsoTagData
import com.jankinwu.fntv.client.ui.providable.LocalIsoTagData
import com.jankinwu.fntv.client.ui.providable.LocalRefreshState
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalToastManager
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.viewmodel.EpisodeListViewModel
import com.jankinwu.fntv.client.viewmodel.GenresViewModel
import com.jankinwu.fntv.client.viewmodel.ItemViewModel
import com.jankinwu.fntv.client.viewmodel.PlayInfoViewModel
import com.jankinwu.fntv.client.viewmodel.TagViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.rememberScrollbarAdapter
import org.koin.compose.viewmodel.koinViewModel

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
    var episodeList: List<EpisodeListResponse> by remember { mutableStateOf(emptyList()) }

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

    LaunchedEffect(Unit) {
        itemViewModel.loadData(guid)
        playInfoViewModel.loadData(guid)
        episodeListViewModel.loadData(guid)

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
            episodeListViewModel.loadData(guid)
            tagViewModel.loadIso6392Tags()
            tagViewModel.loadIso3166Tags()
            genresViewModel.loadGenres()
        }
    }
    LaunchedEffect(itemUiState) {
        if (itemUiState is UiState.Success) {
            itemData = (itemUiState as UiState.Success<ItemResponse>).data
        }
    }
    LaunchedEffect(playInfoUiState) {
        if (playInfoUiState is UiState.Success) {
            playInfoResponse = (playInfoUiState as UiState.Success<PlayInfoResponse>).data
        }
    }
    LaunchedEffect(episodeListState) {
        println("seasonListState: $episodeListState")
        if (episodeListState is UiState.Success) {
            episodeList = (episodeListState as UiState.Success<List<EpisodeListResponse>>).data
            println("seasonList2: $episodeList")
        }
    }

    LaunchedEffect(iso6391State, iso6392State, iso3166State) {
        val newIso6391Map = if (iso6391State is UiState.Success) {
            (iso6391State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
        } else emptyMap()

        val newIso6392Map = if (iso6392State is UiState.Success) {
            (iso6392State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
        } else emptyMap()

        val newIso3166Map = if (iso3166State is UiState.Success) {
            (iso3166State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
        } else emptyMap()

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
        TvEpisodeBody(
            itemData = itemData,
            playInfoResponse = playInfoResponse,
            guid = guid,
            episodeList = episodeList,
            navigator = navigator
        )
    }
}

@Composable
fun TvEpisodeBody(
    itemData: ItemResponse?,
    playInfoResponse: PlayInfoResponse?,
    guid: String,
    episodeList: List<EpisodeListResponse>,
    navigator: ComponentNavigator,
) {
    val store = LocalStore.current
    val windowHeight = store.windowHeightState
    val toastManager = LocalToastManager.current
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
                                    .fillMaxWidth()
                                    .blur(10.dp),
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
    }
}