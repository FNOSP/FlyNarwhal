package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.PointerIcon
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
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.data.convertor.convertPersonItemListResponseToScrollRowItemData
import com.jankinwu.fntv.client.data.model.response.PersonItemListQueryResponse
import com.jankinwu.fntv.client.data.model.response.PersonResponse
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.icons.HeartFilled
import com.jankinwu.fntv.client.manager.HandleFavoriteResult
import com.jankinwu.fntv.client.manager.HandleWatchedResult
import com.jankinwu.fntv.client.ui.component.common.BackButton
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingError
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.MoviePoster
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.component.detail.MediaDescriptionDialog
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalToastManager
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.viewmodel.FavoriteViewModel
import com.jankinwu.fntv.client.viewmodel.PersonViewModel
import com.jankinwu.fntv.client.viewmodel.WatchedViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import flynarwhal.composeapp.generated.resources.Res
import flynarwhal.composeapp.generated.resources.person_placeholder
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.rememberScrollbarAdapter
import kotlinx.coroutines.delay
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun PersonDetailScreen(
    guid: String,
    navigator: ComponentNavigator
) {
    val viewModel: PersonViewModel = koinViewModel()
    val personState by viewModel.personUiState.collectAsState()
    val actorItemsState by viewModel.actorItemsUiState.collectAsState()
    val directorItemsState by viewModel.directorItemsUiState.collectAsState()
    val screenplayItemsState by viewModel.screenplayItemsUiState.collectAsState()
    val toastManager = rememberToastManager()
    val favoriteViewModel: FavoriteViewModel = koinViewModel()
    val favoriteUiState by favoriteViewModel.uiState.collectAsState()
    val watchedViewModel: WatchedViewModel = koinViewModel()
    val watchedUiState by watchedViewModel.uiState.collectAsState()
    var pendingCallbacks by remember { mutableStateOf<Map<String, (Boolean) -> Unit>>(emptyMap()) }

    LaunchedEffect(guid) {
        viewModel.loadData(guid)
    }

    val store = LocalStore.current
    val backgroundColor = if (store.darkMode) Colors.BackgroundColorDark else Colors.BackgroundColorLight

    CompositionLocalProvider(LocalToastManager provides toastManager) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(backgroundColor)
        ) {
            val lazyListState = rememberLazyListState()
            ScrollbarContainer(adapter = rememberScrollbarAdapter(lazyListState)) {
                LazyColumn(
                    state = lazyListState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 48.dp, top = 24.dp)
                ) {
                    item {
                        PersonHeader(personState)
                    }

                    item {
                        PersonSection(
                            title = "作为演员",
                            state = actorItemsState,
                            navigator = navigator,
                            onWatchedToggle = { guid, currentWatched, callback ->
                                watchedViewModel.toggleWatched(guid, currentWatched)
                                pendingCallbacks = pendingCallbacks + (guid to callback)
                            },
                            onFavoriteToggle = { guid, currentFavorite, callback ->
                                favoriteViewModel.toggleFavorite(guid, currentFavorite)
                                pendingCallbacks = pendingCallbacks + (guid to callback)
                            }
                        )
                    }

                    item {
                        PersonSection(
                            title = "作为导演",
                            state = directorItemsState,
                            navigator = navigator,
                            onWatchedToggle = { guid, currentWatched, callback ->
                                watchedViewModel.toggleWatched(guid, currentWatched)
                                pendingCallbacks = pendingCallbacks + (guid to callback)
                            },
                            onFavoriteToggle = { guid, currentFavorite, callback ->
                                favoriteViewModel.toggleFavorite(guid, currentFavorite)
                                pendingCallbacks = pendingCallbacks + (guid to callback)
                            }
                        )
                    }

                    item {
                        PersonSection(
                            title = "作为编剧",
                            state = screenplayItemsState,
                            navigator = navigator,
                            onWatchedToggle = { guid, currentWatched, callback ->
                                watchedViewModel.toggleWatched(guid, currentWatched)
                                pendingCallbacks = pendingCallbacks + (guid to callback)
                            },
                            onFavoriteToggle = { guid, currentFavorite, callback ->
                                favoriteViewModel.toggleFavorite(guid, currentFavorite)
                                pendingCallbacks = pendingCallbacks + (guid to callback)
                            }
                        )
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
}

@Composable
private fun PersonHeader(state: UiState<PersonResponse>) {
    val store = LocalStore.current
    val favoriteViewModel: FavoriteViewModel = koinViewModel()
    val favoriteUiState by favoriteViewModel.uiState.collectAsState()
    var showBiographyDialog by remember { mutableStateOf(false) }

    when (state) {
        is UiState.Success -> {
            val person = state.data
            var isFavorite by remember(person.guid, person.isFavorite == 1) { mutableStateOf(person.isFavorite == 1) }
            LaunchedEffect(favoriteUiState, person.guid) {
                when (val favoriteState = favoriteUiState) {
                    is UiState.Success -> {
                        if (favoriteState.data.guid == person.guid) {
                            isFavorite = favoriteState.data.isFavorite
                        }
                    }

                    else -> {}
                }

                if (favoriteUiState is UiState.Success || favoriteUiState is UiState.Error) {
                    delay(2000)
                    favoriteViewModel.clearError()
                }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 48.dp, vertical = 48.dp),
                horizontalArrangement = Arrangement.spacedBy(32.dp)
            ) {
                // Profile Image
                Box(
                    modifier = Modifier
                        .width(214.dp)
                        .aspectRatio(2f / 3f)
                        .clip(RoundedCornerShape(12.dp))
                ) {
                    SubcomposeAsyncImage(
                        model = ImageRequest.Builder(PlatformContext.INSTANCE)
                            .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img${person.profile}${Constants.FN_IMG_URL_PARAM}")
                            .httpHeaders(store.fnImgHeaders)
                            .crossfade(true)
                            .build(),
                        contentDescription = person.name,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                        loading = { ImgLoadingProgressRing() },
                        error = { ImgLoadingError(resource = Res.drawable.person_placeholder) }
                    )
                }

                // Info
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Column {
                        Text(
                            text = person.name,
                            style = LocalTypography.current.title,
                            fontSize = 32.sp,
                            fontWeight = FontWeight.Bold,
                            color = FluentTheme.colors.text.text.primary
                        )
                        person.originalName?.let {
                            Text(
                                text = it,
                                style = LocalTypography.current.body,
                                color = FluentTheme.colors.text.text.secondary
                            )
                        }
                    }

                    // Biography with "More" button
                    Box(modifier = Modifier.fillMaxWidth()) {
                        var isOverflowing by remember { mutableStateOf(false) }
                        val biography = person.biography?.replace("\n\n", "\n") ?: ""
                        
                        Text(
                            text = biography,
                            style = LocalTypography.current.body,
                            color = FluentTheme.colors.text.text.secondary,
                            fontSize = 15.sp,
                            lineHeight = 22.sp,
                            maxLines = 7,
                            overflow = TextOverflow.Ellipsis,
                            onTextLayout = { textLayoutResult ->
                                isOverflowing = textLayoutResult.hasVisualOverflow
                            }
                        )

                        if (isOverflowing) {
                            Text(
                                text = "更多",
                                style = LocalTypography.current.body,
                                color = Colors.AccentColorDefault,
                                fontSize = 15.sp,
                                modifier = Modifier
                                    .align(Alignment.BottomEnd)
//                                    .background(store.getBackgroundColor())
                                    .padding(start = 4.dp)
                                    .offset(x = 30.dp)
                                    .clickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null,
                                        onClick = { showBiographyDialog = true }
                                    )
                                    .pointerHoverIcon(PointerIcon.Hand)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))
                    // Favorite Button
                    CircleIconButton(
                        icon = HeartFilled,
                        description = "收藏",
                        iconColor = if (isFavorite) Colors.DangerDefaultColor else FluentTheme.colors.text.text.primary,
                        onClick = {
                            favoriteViewModel.toggleFavorite(
                                person.guid,
                                isFavorite
                            )
                        }
                    )
                }
            }

            if (showBiographyDialog) {
                MediaDescriptionDialog(
                    title = "演职员简介",
                    content = person.biography?.replace("\n\n", "\n") ?: "",
                    onDismiss = { showBiographyDialog = false }
                )
            }
        }
        is UiState.Loading -> {
            Box(modifier = Modifier.fillMaxWidth().height(300.dp), contentAlignment = Alignment.Center) {
                ImgLoadingProgressRing()
            }
        }
        else -> {}
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PersonSection(
    title: String,
    state: UiState<PersonItemListQueryResponse>,
    navigator: ComponentNavigator,
    onWatchedToggle: (guid: String, currentWatched: Boolean, callback: (Boolean) -> Unit) -> Unit,
    onFavoriteToggle: (guid: String, currentFavorite: Boolean, callback: (Boolean) -> Unit) -> Unit
) {
    val store = LocalStore.current
    val scaleFactor = store.scaleFactor

    when (state) {
        is UiState.Success -> {
            if (state.data.total > 0 && state.data.list.isNotEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 48.dp, vertical = 24.dp)
                ) {
                    Text(
                        text = title,
                        style = LocalTypography.current.title.copy(fontWeight = FontWeight.Medium),
                        fontSize = 16.sp,
                        color = FluentTheme.colors.text.text.primary,
                        modifier = Modifier.padding(bottom = 16.dp)
                    )

                    val posterMinWidth = (128 * scaleFactor).dp
                    val spacing = 16.dp

                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(spacing),
                        verticalArrangement = Arrangement.spacedBy(spacing),
                    ) {
                        state.data.list.forEach { item ->
                            val scrollItem = convertPersonItemListResponseToScrollRowItemData(item)
                            Box(
                                modifier = Modifier
                                    .width(posterMinWidth)
                                    .height((240 * scaleFactor).dp)
                            ) {
                                MoviePoster(
                                    modifier = Modifier.fillMaxSize(),
                                    title = scrollItem.title,
                                    subtitle = scrollItem.subtitle,
                                    score = scrollItem.score,
                                    posterImg = scrollItem.posterImg,
                                    isFavorite = scrollItem.isFavourite,
                                    isAlreadyWatched = scrollItem.isAlreadyWatched,
                                    guid = scrollItem.guid,
                                    navigator = navigator,
                                    type = scrollItem.type,
                                    posterWidth = scrollItem.posterWidth,
                                    posterHeight = scrollItem.posterHeight,
                                    onWatchedToggle = onWatchedToggle,
                                    onFavoriteToggle = onFavoriteToggle
                                )
                            }
                        }
                    }
                }
            }
        }
        else -> {}
    }
}
