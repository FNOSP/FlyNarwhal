package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.BiasAlignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import coil3.PlatformContext
import coil3.compose.SubcomposeAsyncImage
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.crossfade
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.response.GenresResponse
import com.jankinwu.fntv.client.data.model.response.MediaItem
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.Search
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.screen.MovieDetailScreen
import com.jankinwu.fntv.client.ui.screen.PersonDetailScreen
import com.jankinwu.fntv.client.ui.screen.TvDetailScreen
import com.jankinwu.fntv.client.viewmodel.GenresViewModel
import com.jankinwu.fntv.client.viewmodel.SearchViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import flynarwhal.composeapp.generated.resources.Res
import flynarwhal.composeapp.generated.resources.no_search_result
import flynarwhal.composeapp.generated.resources.person_placeholder
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.Icon
import io.github.composefluent.component.Text
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun CapsuleSearchBox(
    value: String,
    onValueChange: (String) -> Unit,
    navigator: ComponentNavigator,
    modifier: Modifier = Modifier,
    collapsedWidth: Dp = 130.dp,
    expandedWidth: Dp = 360.dp,
    height: Dp = 32.dp,
    placeholder: String = "搜索片名、演员",
    textStyle: TextStyle = FluentTheme.typography.caption,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isHovered by interactionSource.collectIsHoveredAsState()
    val isFocused by interactionSource.collectIsFocusedAsState()
    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val viewModel: SearchViewModel = koinViewModel()
    val searchUiState by viewModel.uiState.collectAsState()
    var searchBoxBounds by remember { mutableStateOf<Rect?>(null) }

    LaunchedEffect(value) {
        viewModel.search(value)
    }

    val animatedWidth by animateDpAsState(
        targetValue = if (isFocused) expandedWidth else collapsedWidth,
        animationSpec = tween(300),
        label = "capsuleSearchBoxWidth"
    )
    val backgroundColor by animateColorAsState(
        targetValue = if (isHovered || isFocused) FluentTheme.colors.stroke.control.default else Color.Transparent,
        animationSpec = tween(300),
        label = "capsuleSearchBoxBackground"
    )
    val placeholderBias by animateFloatAsState(
        targetValue = if (isFocused) -1f else 0f,
        animationSpec = tween(200),
        label = "capsuleSearchBoxPlaceholderBias"
    )

    Box(
        modifier = modifier
            .width(animatedWidth)
            .height(height)
            .clip(CircleShape)
            .border(1.dp, Color.Gray.copy(alpha = 0.4f), CircleShape)
            .background(backgroundColor)
            .hoverable(interactionSource)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = { focusRequester.requestFocus() }
            )
            .padding(horizontal = 10.dp)
            .onGloballyPositioned { coordinates ->
                searchBoxBounds = coordinates.boundsInWindow()
            }
    ) {
        Icon(
            imageVector = Search,
            contentDescription = "Search",
            tint = FluentTheme.colors.text.text.tertiary,
            modifier = Modifier
                .align(Alignment.CenterStart)
                .size(14.dp)
        )
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = textStyle.copy(color = FluentTheme.colors.text.text.primary),
            cursorBrush = SolidColor(FluentTheme.colors.text.text.primary),
            interactionSource = interactionSource,
            modifier = Modifier
                .fillMaxSize()
                .padding(start = 20.dp)
                .focusRequester(focusRequester),
            decorationBox = { innerTextField ->
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.CenterStart
                ) {
                    if (value.isEmpty()) {
                        Text(
                            text = placeholder,
                            style = textStyle,
                            color = FluentTheme.colors.text.text.tertiary,
                            maxLines = 1,
                            modifier = Modifier.align(
                                BiasAlignment(
                                    horizontalBias = placeholderBias,
                                    verticalBias = 0f
                                )
                            )
                        )
                    }
                    innerTextField()
                }
            }
        )
    }

    if (isFocused && value.isNotEmpty()) {
        Popup(
            alignment = Alignment.TopCenter,
            offset = IntOffset(0, 40),
            onDismissRequest = {
                focusManager.clearFocus()
                onValueChange("")
                viewModel.clearSearch()
            }
        ) {
            Box(
                modifier = Modifier
                    .width(expandedWidth)
                    .height(500.dp)
                    .padding(top = 4.dp)
            ) {
                SearchResultDropdown(
                    uiState = searchUiState,
                    navigator = navigator,
                    onItemClick = {
                        focusManager.clearFocus()
                        onValueChange("")
                        viewModel.clearSearch()
                    }
                )
            }
        }
    }
}

@Composable
private fun SearchResultDropdown(
    uiState: UiState<List<MediaItem>>,
    navigator: ComponentNavigator,
    onItemClick: () -> Unit
) {
    var selectedTab by remember { mutableStateOf("全部") }
    val tabs = listOf("全部", "电影", "电视剧", "人物", "其他")
    val genresViewModel: GenresViewModel = koinViewModel()
    val genresUiState by genresViewModel.uiState.collectAsState()
    val genresMap = remember(genresUiState) {
        when (genresUiState) {
            is UiState.Success -> {
                (genresUiState as UiState.Success<List<GenresResponse>>)
                    .data.associateBy { it.id }
            }
            else -> emptyMap()
        }
    }
    val lazyListState = rememberLazyListState()

    LaunchedEffect(genresUiState) {
        if (genresUiState is UiState.Initial) {
            genresViewModel.loadGenres()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .shadow(8.dp, RoundedCornerShape(8.dp))
            .background(FluentTheme.colors.background.solid.base, RoundedCornerShape(8.dp))
            .border(1.dp, FluentTheme.colors.stroke.surface.flyout, RoundedCornerShape(8.dp))
            .clip(RoundedCornerShape(8.dp))
    ) {
        Column {
            // Tabs
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .border(
                        width = 0.dp,
                        color = Color.Transparent,
                        shape = RoundedCornerShape(0.dp)
                    ), // Just for layout
                horizontalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                tabs.forEach { tab ->
                    val isSelected = selectedTab == tab
                    Text(
                        text = tab,
                        style = FluentTheme.typography.body.copy(
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            color = if (isSelected) Colors.AccentColorDefault else FluentTheme.colors.text.text.secondary
                        ),
                        modifier = Modifier
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null
                            ) { selectedTab = tab }
                            .pointerHoverIcon(PointerIcon.Hand)
                    )
                }
            }
            
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(FluentTheme.colors.stroke.surface.default.copy(alpha = 0.1f))
            )

            // Content
            when (uiState) {
                is UiState.Success -> {
                    val allItems = uiState.data
                    val filteredItems = remember(allItems, selectedTab) {
                        if (selectedTab == "全部") {
                            allItems
                        } else {
                            allItems.filter { item ->
                                when (selectedTab) {
                                    "电影" -> item.type == "Movie"
                                    "电视剧" -> item.type == "TV"
                                    "人物" -> item.type == "Person"
                                    "其他" -> item.type != "Movie" && item.type != "TV" && item.type != "Person"
                                    else -> true
                                }
                            }
                        }
                    }

                    if (filteredItems.isEmpty()) {
                        EmptySearchResult()
                    } else {
                        AnimatedScrollbarLazyColumn(
                            listState = lazyListState,
                            modifier = Modifier.fillMaxSize(),
                            scrollbarWidth = 6.dp,
                            scrollbarOffsetX = (-4).dp,
                            autoHidden = true
                        ) {
                            items(filteredItems) { item ->
                                SearchResultItem(item, navigator, onItemClick, genresMap)
                            }
                        }
                    }
                }
                is UiState.Loading -> {
                }
                else -> {
                    EmptySearchResult()
                }
            }
        }
    }
}

@Composable
private fun EmptySearchResult() {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Image(
            painter = painterResource(Res.drawable.no_search_result),
            contentDescription = "No Result",
            modifier = Modifier.size(120.dp),
            contentScale = ContentScale.Fit
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "搜索无结果",
            style = FluentTheme.typography.body,
            color = FluentTheme.colors.text.text.secondary
        )
    }
}

@Composable
@OptIn(ExperimentalComposeUiApi::class)
private fun SearchResultItem(
    item: MediaItem,
    navigator: ComponentNavigator,
    onItemClick: () -> Unit,
    genresMap: Map<Int, GenresResponse>
) {
    val isPerson = item.type == "Person"
    var isHovered by remember { mutableStateOf(false) }
    val store = LocalStore.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(80.dp)
            .hoverable(remember { MutableInteractionSource() }) // For hover effect if needed
            .pointerHoverIcon(PointerIcon.Hand)
            .background(if (isHovered) FluentTheme.colors.subtleFill.secondary else Color.Transparent)
            .clickable {
                onItemClick()
                when (item.type) {
                    "Movie" -> navigator.navigate(
                        ComponentItem(
                            name = item.title,
                            group = "MovieDetail",
                            description = "",
                            guid = item.guid,
                            content = { MovieDetailScreen(item.guid, it) }
                        )
                    )
                    "TV" -> navigator.navigate(
                        ComponentItem(
                            name = item.title,
                            group = "TvDetail",
                            description = "",
                            guid = item.guid,
                            content = { TvDetailScreen(item.guid, it) }
                        )
                    )
                    "Person" -> navigator.navigate(
                        ComponentItem(
                            name = item.title,
                            group = "PersonDetail",
                            description = "",
                            guid = item.guid,
                            content = { PersonDetailScreen(item.guid, it) }
                        )
                    )
                    "Video" -> navigator.navigate(
                        ComponentItem(
                            name = item.title,
                            group = "MovieDetail",
                            description = "",
                            guid = item.guid,
                            content = { MovieDetailScreen(item.guid, it) }
                        )
                    )
                    else -> navigator.navigate(
                        ComponentItem(
                            name = item.title,
                            group = "MovieDetail",
                            description = "",
                            guid = item.guid,
                            content = { MovieDetailScreen(item.guid, it) }
                        )
                    )
                }
            }
            .onPointerEvent(androidx.compose.ui.input.pointer.PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(androidx.compose.ui.input.pointer.PointerEventType.Exit) { isHovered = false }
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Poster / Profile Image
        val imageUrl = "${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img${item.poster}${Constants.FN_IMG_URL_PARAM}"

        SubcomposeAsyncImage(
            model = ImageRequest.Builder(PlatformContext.INSTANCE)
                .data(imageUrl)
                .httpHeaders(store.fnImgHeaders)
                .crossfade(true)
                .build(),
            contentDescription = item.title,
            modifier = Modifier
                .height(80.dp)
                .border(1.dp, Color.Gray.copy(alpha = 0.5f), RoundedCornerShape(4.dp))
                .clip(RoundedCornerShape(4.dp))
                .width(80.dp * 11 / 17),
            contentScale = ContentScale.FillWidth,
            loading = { ImgLoadingProgressRing() },
            error = { ImgLoadingError(resource = Res.drawable.person_placeholder) }
        )

        Spacer(modifier = Modifier.width(16.dp))

        Column(
            verticalArrangement = if (item.type != FnTvMediaType.VIDEO.value) Arrangement.spacedBy(6.dp, Alignment.Top) else Arrangement.Center,
            modifier = Modifier
                .fillMaxHeight()
                .weight(1f)
        ) {
            Text(
                text = item.title, // For person, title field in MediaItem might be populated with name or title
                style = FluentTheme.typography.bodyStrong,
                color = FluentTheme.colors.text.text.primary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
//            Spacer(modifier = Modifier.height(4.dp))
            
            if (isPerson) {
                 Text(
                    text = "${item.numberOfItem ?: 0} 个作品",
                    style = FluentTheme.typography.caption,
                    color = FluentTheme.colors.text.text.secondary
                )
            } else {
                val voteAverage = item.voteAverage?.takeIf { it.isNotBlank() && it != "0" }?.let {
                    FnDataConvertor.formatVoteAverage(it)
                }
                val genresText = item.genres?.mapNotNull { genreId ->
                    genresMap[genreId]?.value?.takeIf { it.isNotBlank() }
                }?.joinToString(" / ")
                val year = item.releaseDate?.take(4) ?: item.firstAirDate?.take(4) ?: ""

                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (!voteAverage.isNullOrBlank()) {
                        Text(
                            text = voteAverage,
                            style = FluentTheme.typography.body,
                            color = Color(0xFFFACC15)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "分",
                            style = FluentTheme.typography.caption,
                            color = FluentTheme.colors.text.text.secondary
                        )
                        Spacer(modifier = Modifier.width(16.dp))
                    }

                    if (!genresText.isNullOrBlank()) {
                        Text(
                            text = genresText,
                            style = FluentTheme.typography.caption,
                            color = FluentTheme.colors.text.text.secondary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }

                if (year.isNotEmpty() || (item.type == "TV" && (item.numberOfEpisodes ?: 0) > 0)) {
//                    Spacer(modifier = Modifier.height(4.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (year.isNotEmpty() && item.type != FnTvMediaType.VIDEO.value) {
                            Text(
                                text = year,
                                style = FluentTheme.typography.caption,
                                color = FluentTheme.colors.text.text.secondary
                            )
                        }

                        if (item.type == "TV" && (item.numberOfEpisodes ?: 0) > 0) {
                            if (year.isNotEmpty()) {
                                Spacer(modifier = Modifier.width(8.dp))
                            }
                            Text(
                                text = "共 ${item.numberOfEpisodes} 集",
                                style = FluentTheme.typography.caption,
                                color = FluentTheme.colors.text.text.secondary
                            )
                        }
                    }
                }
            }
        }
    }
}
