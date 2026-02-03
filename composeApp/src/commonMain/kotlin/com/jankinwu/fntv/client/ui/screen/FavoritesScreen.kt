package com.jankinwu.fntv.client.ui.screen

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.convertor.convertToScrollRowItemDataList
import com.jankinwu.fntv.client.data.model.request.Tags
import com.jankinwu.fntv.client.data.model.response.UserInfoResponse
import com.jankinwu.fntv.client.manager.HandleFavoriteResult
import com.jankinwu.fntv.client.manager.HandleWatchedResult
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.EmptyFolder
import com.jankinwu.fntv.client.ui.component.common.FilterBox
import com.jankinwu.fntv.client.ui.component.common.FilterButton
import com.jankinwu.fntv.client.ui.component.common.FilterItem
import com.jankinwu.fntv.client.ui.component.common.MoviePoster
import com.jankinwu.fntv.client.ui.component.common.SortFlyout
import com.jankinwu.fntv.client.ui.component.common.SortItem
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.providable.LocalRefreshState
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalToastManager
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.ui.providable.LocalUserInfo
import com.jankinwu.fntv.client.viewmodel.FavoriteListViewModel
import com.jankinwu.fntv.client.viewmodel.FavoriteTabKey
import com.jankinwu.fntv.client.viewmodel.FavoriteViewModel
import com.jankinwu.fntv.client.viewmodel.GenresViewModel
import com.jankinwu.fntv.client.viewmodel.TagListKey
import com.jankinwu.fntv.client.viewmodel.TagListViewModel
import com.jankinwu.fntv.client.viewmodel.TagViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.UserInfoViewModel
import com.jankinwu.fntv.client.viewmodel.WatchedViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.Text
import io.github.composefluent.component.rememberScrollbarAdapter
import org.koin.compose.viewmodel.koinViewModel

@Suppress("DefaultLocale")
@Composable
fun FavoritesScreen(
    navigator: ComponentNavigator
) {
    val favoriteListViewModel: FavoriteListViewModel = koinViewModel<FavoriteListViewModel>()
    val tabStates by favoriteListViewModel.tabStates.collectAsState()
    val tagListViewModel: TagListViewModel = koinViewModel<TagListViewModel>()
    val tagStates by tagListViewModel.tagStates.collectAsState()
    val genresViewModel: GenresViewModel = koinViewModel<GenresViewModel>()
    val genresUiState by genresViewModel.uiState.collectAsState()
    val tagViewModel: TagViewModel = koinViewModel<TagViewModel>()
    val iso3166State by tagViewModel.iso3166State.collectAsState()
    val userInfoViewModel: UserInfoViewModel = koinViewModel<UserInfoViewModel>()
    val userInfoUiState by userInfoViewModel.uiState.collectAsState()
    val currentUserInfo = when (userInfoUiState) {
        is UiState.Success -> (userInfoUiState as UiState.Success<UserInfoResponse>).data
        else -> UserInfoResponse.Empty
    }
    val gridState = rememberLazyGridState()
    val store = LocalStore.current
    val scaleFactor = store.scaleFactor
    val posterMinWidth = (128 * scaleFactor).dp
    val spacing = 24.dp
    val posterHeight = (253 * scaleFactor).dp
    val refreshState = LocalRefreshState.current
    var isLoadingMore by remember { mutableStateOf(false) }

    val favoriteViewModel: FavoriteViewModel = koinViewModel()
    val favoriteUiState by favoriteViewModel.uiState.collectAsState()

    val watchedViewModel: WatchedViewModel = koinViewModel()
    val watchedUiState by watchedViewModel.uiState.collectAsState()

    val toastManager = rememberToastManager()

    var pendingCallbacks by remember { mutableStateOf(mapOf<String, (Boolean) -> Unit>()) }

    var screenWidthPx by remember { mutableIntStateOf(0) }
    val density = LocalDensity.current

    var selectedFilters by remember { mutableStateOf(mapOf<String, FilterItem>()) }
    var sortColumnState by remember { mutableStateOf("create_time") }
    var sortOrderState by remember { mutableStateOf("DESC") }

    val tabs = listOf("全部", "电影", "电视节目", "单集", "人物")
    var selectedTab by remember { mutableStateOf(tabs[0]) }

    // Helper to get type for API based on tab
    fun getTypesForTab(tab: String): List<String>? {
        return when (tab) {
            "全部" -> null
            "电影" -> listOf("Movie")
            "电视节目" -> listOf("TV", "Season")
            "单集" -> listOf("Episode")
            "人物" -> listOf("Person")
            else -> null
        }
    }
    
    // Helper to get type for Tag API based on tab (single string)
    fun getTypeForTagApi(tab: String): String? {
        return when (tab) {
            "电影" -> "Movie"
            "电视节目" -> "TV"
            "单集" -> "Episode"
            else -> null
        }
    }

    fun buildTagsForTab(tab: String, filters: Map<String, FilterItem>): Tags {
        val builder = Tags.Builder()
        val types = getTypesForTab(tab)
        if (types != null) {
            builder.type(types)
        }

        filters.forEach { (title, filterItem) ->
            when (title) {
                "影视类型" -> {
                    if (filterItem.value != null) {
                        builder.type(listOf(filterItem.value.toString()))
                    }
                }
                "类型" -> {
                    if (filterItem.value != null) {
                        builder.genres(filterItem.value as? Int)
                    }
                }
                "分辨率" -> builder.resolution(filterItem.value as? String)
                "视频动态范围" -> builder.colorRange(filterItem.value as? String)
                "音频规格" -> builder.audioType(filterItem.value as? String)
                "国家和地区" -> builder.locate(filterItem.value as? String)
                "发行年份" -> builder.decade(filterItem.value as? String)
                "匹配状态" -> {
                    if (filterItem.value != null) {
                        builder.recognitionStatus((filterItem.value as? Int).toString())
                    }
                }
                "是否已观看" -> builder.watched(filterItem.value as? String)
            }
        }
        return builder.build()
    }

    fun loadTabData(tab: String, filters: Map<String, FilterItem>, force: Boolean) {
        val tags = buildTagsForTab(tab, filters)
        val key = FavoriteTabKey(tab, tags, sortColumnState, sortOrderState)
        favoriteListViewModel.loadDataForKey(
            key = key,
            pageSize = 50,
            force = force
        )
    }

    fun loadAllTabs(force: Boolean) {
        tabs.forEach { tab ->
            val filters = if (tab == selectedTab) selectedFilters else emptyMap()
            loadTabData(tab, filters, force)
        }
    }

    fun getTagListKey(tab: String): TagListKey? {
        if (tab == "人物") return null
        return TagListKey(
            ancestorGuid = null,
            isFavorite = 1,
            type = getTypeForTagApi(tab)
        )
    }

    fun loadAllTagLists(force: Boolean) {
        tabs.mapNotNull { getTagListKey(it) }
            .distinct()
            .forEach { key ->
                tagListViewModel.loadTagListForKey(key, force)
            }
    }

    fun loadBaseMetadata(force: Boolean) {
        if (force || genresUiState !is UiState.Success) {
            genresViewModel.loadGenres()
        }
        if (force || iso3166State !is UiState.Success) {
            tagViewModel.loadIso3166Tags()
        }
    }

    LaunchedEffect(Unit) {
        loadAllTabs(force = false)
        loadAllTagLists(force = false)
        loadBaseMetadata(force = false)
    }

    LaunchedEffect(selectedTab) {
        selectedFilters = emptyMap()
        gridState.scrollToItem(0)
        loadTabData(selectedTab, emptyMap(), force = false)
    }

    var screenWidth by remember(screenWidthPx, density) {
        mutableStateOf(with(density) { screenWidthPx.toDp() })
    }

    val spanCount = maxOf(1, (screenWidth / (posterMinWidth + spacing)).toInt())

    // Infinite scroll
    val currentTags = buildTagsForTab(selectedTab, selectedFilters)
    val currentKey = FavoriteTabKey(selectedTab, currentTags, sortColumnState, sortOrderState)
    val favoriteListUiState = tabStates[currentKey] ?: UiState.Initial
    val tagListUiState = getTagListKey(selectedTab)?.let { tagStates[it] } ?: UiState.Initial

    LaunchedEffect(gridState, currentKey) {
        snapshotFlow { gridState.layoutInfo }
            .collect { layoutInfo ->
                val totalItems = layoutInfo.totalItemsCount
                val lastVisibleItemIndex = layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0

                if (totalItems > 0 && lastVisibleItemIndex >= totalItems - 5) {
                    val currentState = favoriteListUiState
                    if (currentState !is UiState.Loading && !isLoadingMore && !favoriteListViewModel.isLastPageFor(currentKey)) {
                        isLoadingMore = true
                        favoriteListViewModel.loadMoreDataForKey(
                            key = currentKey,
                            pageSize = 50,
                            isLoadMore = isLoadingMore
                        )
                        kotlinx.coroutines.delay(500)
                        isLoadingMore = false
                    }
                }
            }
    }

    var isFilterButtonSelected by remember { mutableStateOf(false) }
    var filterBoxHeightPx by remember { mutableIntStateOf(0) }
    var headerHeightPx by remember { mutableIntStateOf(0) }
    val currentDensity = LocalDensity.current

    val windowHeightPx = with(currentDensity) { store.windowHeightState.toPx() }.toInt()
    var previousFirstVisibleIndex by remember { mutableIntStateOf(0) }
    var shouldIgnoreScrollCheck by remember { mutableStateOf(false) }

    LaunchedEffect(isFilterButtonSelected) {
        previousFirstVisibleIndex = 0
        if (isFilterButtonSelected) {
            shouldIgnoreScrollCheck = true
            kotlinx.coroutines.delay(300)
            shouldIgnoreScrollCheck = false
        }
    }

    LaunchedEffect(gridState) {
        snapshotFlow { gridState.firstVisibleItemIndex }
            .collect { firstVisibleIndex ->
                if (shouldIgnoreScrollCheck) return@collect
                if (isFilterButtonSelected) {
                    val currentFirstVisibleIndex = gridState.firstVisibleItemIndex
                    val currentFirstVisibleItemOffset = gridState.firstVisibleItemScrollOffset
                    val totalScrollOffset = currentFirstVisibleIndex * 100 + currentFirstVisibleItemOffset
                    val previousTotalScrollOffset = previousFirstVisibleIndex * 100

                    if (totalScrollOffset > previousTotalScrollOffset) {
                        isFilterButtonSelected = false
                    }
                }
                previousFirstVisibleIndex = firstVisibleIndex
            }
    }

    LaunchedEffect(refreshState.refreshKey) {
        if (refreshState.refreshKey.isNotEmpty()) {
            refreshState.onRefresh()
            gridState.scrollToItem(0)
            selectedFilters = emptyMap()
            loadAllTabs(force = true)
            loadAllTagLists(force = true)
            loadBaseMetadata(force = true)
        }
    }

    LaunchedEffect(sortColumnState, sortOrderState) {
        refreshState.onRefresh()
        gridState.scrollToItem(0)
        loadAllTabs(force = true)
    }

    HandleFavoriteResult(
        favoriteUiState = favoriteUiState,
        toastManager = toastManager,
        pendingCallbacks = pendingCallbacks,
        onPendingCallbackHandled = { id ->
            pendingCallbacks = pendingCallbacks - id
            val state = favoriteUiState
            if (state is UiState.Success && state.data.success && state.data.guid == id) {
                loadTabData(selectedTab, selectedFilters, force = true)
                getTagListKey(selectedTab)?.let { key ->
                    tagListViewModel.loadTagListForKey(key, force = true)
                }
            }
        },
        clearError = { favoriteViewModel.clearError() }
    )

    HandleWatchedResult(
        watchedUiState = watchedUiState,
        toastManager = toastManager,
        pendingCallbacks = pendingCallbacks,
        onPendingCallbackHandled = { id -> pendingCallbacks = pendingCallbacks - id },
        clearError = { watchedViewModel.clearError() }
    )

    CompositionLocalProvider(
        LocalUserInfo provides currentUserInfo,
        LocalToastManager provides toastManager,
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .fillMaxHeight()
                    .onSizeChanged { screenWidthPx = it.width },
                horizontalAlignment = Alignment.Start
            ) {
                Column(
                    modifier = Modifier.onGloballyPositioned { coordinates ->
                        headerHeightPx = coordinates.size.height
                    }
                ) {
                    Text(
                        text = "收藏",
                        style = LocalTypography.current.subtitle,
                        color = FluentTheme.colors.text.text.tertiary,
                        modifier = Modifier.padding(top = 36.dp, start = 32.dp, bottom = 24.dp)
                    )

                    // Tabs
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 32.dp, vertical = 8.dp),
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
                                    ) { 
                                        if (selectedTab != tab) {
                                            selectedTab = tab
                                            isFilterButtonSelected = false // Close filter on tab change
                                        }
                                    }
                                    .pointerHoverIcon(PointerIcon.Hand)
                            )
                        }
                    }
                    
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 32.dp)
                            .height(1.dp)
                            .background(FluentTheme.colors.stroke.surface.default.copy(alpha = 0.1f))
                    )
                    
                    Row(
                        modifier = Modifier.padding(start = 32.dp, top = 16.dp, bottom = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        if (selectedTab != "人物") {
                            FilterButton(
                                modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
                                isSelected = isFilterButtonSelected,
                                selectedFilters = selectedFilters,
                                onFilterClear = { title ->
                                    val updatedFilters = selectedFilters.toMutableMap()
                                    if (title in updatedFilters) {
                                        updatedFilters[title] = FilterItem("全部", null)
                                        selectedFilters = updatedFilters.toMap()
                                    } else {
                                        val updatedFilters = selectedFilters.map { (key, _) ->
                                            key to FilterItem("全部", null)
                                        }.toMap()
                                        selectedFilters = updatedFilters
                                    }
                                    loadTabData(selectedTab, selectedFilters, force = true)
                                },
                                onClick = { isFilterButtonSelected = !isFilterButtonSelected }
                            )
                        }
                        
                        SortFlyout(
                            onSortTypeSelected = { sortType -> sortColumnState = sortType },
                            onSortOrderSelected = { sortOrder -> sortOrderState = sortOrder },
                            sortOptions = listOf(
                                SortItem("收藏时间", "create_time"),
                                SortItem("发行年份", "release_date"),
                                SortItem("标题", "sort_title"),
                                SortItem("评分", "vote_average")
                            )
                        )
                    }
                }

                AnimatedVisibility(
                    visible = isFilterButtonSelected,
                    enter = expandVertically(animationSpec = tween(durationMillis = 300)) + fadeIn(animationSpec = tween(durationMillis = 300)),
                    exit = shrinkVertically(animationSpec = tween(durationMillis = 300)) + fadeOut(animationSpec = tween(durationMillis = 300))
                ) {
                    FilterBox(
                        modifier = Modifier
                            .padding(horizontal = 32.dp)
                            .padding(bottom = 16.dp)
                            .fillMaxWidth()
                            .onGloballyPositioned { coordinates ->
                                filterBoxHeightPx = coordinates.size.height
                            },
                        tagListUiState = tagListUiState,
                        genresUiState = genresUiState,
                        iso3166State = iso3166State,
                        initialSelectedFilters = selectedFilters,
                        onFilterChanged = { filters ->
                            selectedFilters = filters
                            loadTabData(selectedTab, selectedFilters, force = true)
                        }
                    )
                }

                // Content
                AnimatedContent(
                    targetState = selectedTab,
                    transitionSpec = {
                        val direction = if (tabs.indexOf(targetState) > tabs.indexOf(initialState)) 1 else -1
                        slideInHorizontally(initialOffsetX = { it * direction }) + fadeIn() togetherWith
                                slideOutHorizontally(targetOffsetX = { -it * direction }) + fadeOut()
                    }
                ) { currentTab ->
                    val tabFilters = if (currentTab == selectedTab) selectedFilters else emptyMap()
                    val tabTags = buildTagsForTab(currentTab, tabFilters)
                    val tabKey = FavoriteTabKey(currentTab, tabTags, sortColumnState, sortOrderState)
                    val tabUiState = tabStates[tabKey] ?: UiState.Initial
                    Box(modifier = Modifier.fillMaxSize()) {
                        when (tabUiState) {
                            is UiState.Loading -> {
                                // Loading indicator if needed, or skeleton
                            }
                            is UiState.Success -> {
                                val itemDataList = remember(tabUiState.data) {
                                    tabUiState.data.list.map { item -> convertToScrollRowItemDataList(item) }
                                }

                                if (itemDataList.isEmpty()) {
                                    EmptyFolder(modifier = Modifier.fillMaxSize(), text = "无数据", imgSize = 150.dp)
                                } else {
                                    ScrollbarContainer(
                                        adapter = rememberScrollbarAdapter(state = gridState),
                                        modifier = Modifier.fillMaxSize()
                                    ) {
                                        LazyVerticalGrid(
                                            columns = GridCells.Fixed(spanCount),
                                            state = gridState,
                                            modifier = Modifier.fillMaxSize().padding(horizontal = 32.dp),
                                            verticalArrangement = Arrangement.spacedBy(spacing),
                                            horizontalArrangement = Arrangement.spacedBy(spacing),
                                        ) {
                                            items(itemDataList) { itemData ->
                                                MoviePoster(
                                                    modifier = Modifier.height(posterHeight),
                                                    title = itemData.title,
                                                    subtitle = itemData.subtitle,
                                                    score = itemData.score,
                                                    posterImg = itemData.posterImg,
                                                    isFavorite = itemData.isFavourite,
                                                    isAlreadyWatched = itemData.isAlreadyWatched,
                                                    resolutions = itemData.resolutions,
                                                    guid = itemData.guid,
                                                    onFavoriteToggle = { guid, currentFavoriteState, resultCallback ->
                                                        pendingCallbacks = pendingCallbacks + (guid to resultCallback)
                                                        favoriteViewModel.toggleFavorite(guid, currentFavoriteState)
                                                    },
                                                    onWatchedToggle = { guid, currentWatchedState, resultCallback ->
                                                        pendingCallbacks = pendingCallbacks + (guid to resultCallback)
                                                        watchedViewModel.toggleWatched(guid, currentWatchedState)
                                                    },
                                                    posterWidth = itemData.posterWidth,
                                                    posterHeight = itemData.posterHeight,
                                                    status = itemData.status,
                                                    navigator = navigator,
                                                    type = itemData.type
                                                )
                                            }

                                            item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(spanCount) }) {
                                                Box(modifier = Modifier.height(32.dp))
                                            }
                                        }
                                    }
                                }
                            }
                            is UiState.Error -> {
                                toastManager.showToast(
                                    "获取收藏列表失败, cause: ${tabUiState.message}",
                                    ToastType.Failed,
                                    10000
                                )
                            }
                            else -> {}
                            }
                        }
                    }
                }
            }
        }
        
        ToastHost(
            toastManager = toastManager,
            modifier = Modifier.fillMaxSize()
        )
    }
