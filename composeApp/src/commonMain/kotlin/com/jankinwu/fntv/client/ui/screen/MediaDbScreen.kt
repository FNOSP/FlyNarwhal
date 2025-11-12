package com.jankinwu.fntv.client.ui.screen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.LocalRefreshState
import com.jankinwu.fntv.client.LocalStore
import com.jankinwu.fntv.client.LocalTypography
import com.jankinwu.fntv.client.data.convertor.convertToScrollRowItemData
import com.jankinwu.fntv.client.data.model.request.Tags
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.FilterBox
import com.jankinwu.fntv.client.ui.component.common.FilterButton
import com.jankinwu.fntv.client.ui.component.common.FilterItem
import com.jankinwu.fntv.client.ui.component.common.MoviePoster
import com.jankinwu.fntv.client.ui.component.common.SortFlyout
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.viewmodel.FavoriteViewModel
import com.jankinwu.fntv.client.viewmodel.GenresViewModel
import com.jankinwu.fntv.client.viewmodel.ItemListViewModel
import com.jankinwu.fntv.client.viewmodel.TagListViewModel
import com.jankinwu.fntv.client.viewmodel.TagViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.WatchedViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.Text
import io.github.composefluent.component.rememberScrollbarAdapter
import org.koin.compose.viewmodel.koinViewModel

@Suppress("DefaultLocale")
@Composable
fun MediaDbScreen(
    mediaDbGuid: String? = null,
    title: String,
    category: String,
    navigator: ComponentNavigator
) {
    val itemListViewModel: ItemListViewModel = koinViewModel<ItemListViewModel>()
    val itemListUiState by itemListViewModel.uiState.collectAsState()
    val tagListViewModel: TagListViewModel = koinViewModel<TagListViewModel>()
    val tagListUiState by tagListViewModel.uiState.collectAsState()
    val genresViewModel: GenresViewModel = koinViewModel<GenresViewModel>()
    val genresUiState by genresViewModel.uiState.collectAsState()
    val tagViewModel: TagViewModel = koinViewModel<TagViewModel>()
    val iso3166State by tagViewModel.iso3166State.collectAsState()
    val gridState = rememberLazyGridState()
    val store = LocalStore.current
    val scaleFactor = store.scaleFactor
    val posterMinWidth = (128 * scaleFactor).dp
    val spacing = 24.dp
    val posterHeight = (253 * scaleFactor).dp
    val refreshState = LocalRefreshState.current
    var isLoadingMore by remember { mutableStateOf(false) }
    var screenWidthPx by remember { mutableIntStateOf(0) } // 以像素为单位存储宽度
    val density = LocalDensity.current // 获取当前密度
    val toastManager = rememberToastManager()
    val favoriteViewModel: FavoriteViewModel = koinViewModel<FavoriteViewModel>()
    val favoriteUiState by favoriteViewModel.uiState.collectAsState()
    val watchedViewModel: WatchedViewModel = koinViewModel<WatchedViewModel>()
    val watchedUiState by watchedViewModel.uiState.collectAsState()
    var pendingCallbacks by remember { mutableStateOf<Map<String, (Boolean) -> Unit>>(emptyMap()) }
    var selectedFilters by remember { mutableStateOf<Map<String, FilterItem>>(emptyMap()) }
    var sortColumnState by remember { mutableStateOf("create_time") }
    var sortOrderState by remember { mutableStateOf("DESC") }
    fun buildTagsFromFilters(): Tags {
        val builder = Tags.Builder().type(FnTvMediaType.getByCategory(category))
        selectedFilters.forEach { (title, filterItem) ->
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
                "分辨率" -> {
                    builder.resolution(filterItem.value as? String)
                }
                "视频动态范围" -> {
                    builder.colorRange(filterItem.value as? String)
                }
                "音频规格" -> {
                    builder.audioType(filterItem.value as? String)
                }
                "国家和地区" -> {
                    builder.locate(filterItem.value as? String)
                }
                "发行年份" -> {
                    builder.decade(filterItem.value as? String)
                }
                "匹配状态" -> {
                    if (filterItem.value != null) {
                        builder.recognitionStatus((filterItem.value as? Int).toString())
                    }
                }
                "是否已观看" -> {
                    builder.watched(filterItem.value as? String)
                }
            }
        }

        return builder.build()
    }

    // 计算 screenWidth（dp单位）
    var screenWidth by remember(screenWidthPx, density) {
        mutableStateOf(with(density) { screenWidthPx.toDp() })
    }

    // 计算每行显示的海报数量
    val spanCount = maxOf(1, (screenWidth / (posterMinWidth + spacing)).toInt())

    LaunchedEffect(mediaDbGuid) {
        // 初始加载第一页数据
        itemListViewModel.loadData(
            guid = mediaDbGuid,
            tags = Tags(type = FnTvMediaType.getByCategory(category)),
            pageSize = 50,
            sortColumn = "create_time",
            sortOrder = "DESC"
        )
        tagListViewModel.loadTagList(mediaDbGuid, 0, null)
        genresViewModel.loadGenres()
        tagViewModel.loadIso3166Tags()
    }
    // 监听滚动位置，实现懒加载
    LaunchedEffect(gridState) {
        snapshotFlow { gridState.layoutInfo }
            .collect { layoutInfo ->
                val totalItems = layoutInfo.totalItemsCount
                val lastVisibleItemIndex = layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0

                // 当滚动到距离底部还有5个item时加载下一页
                if (totalItems > 0 && lastVisibleItemIndex >= totalItems - 5) {
                    // 检查是否已经在加载或已到最后一页
                    val currentState = itemListUiState
                    if (currentState !is UiState.Loading && !isLoadingMore && !itemListViewModel.isLastPage) {
                        isLoadingMore = true
                        val tags = buildTagsFromFilters()
                        itemListViewModel.loadMoreData(
                            guid = mediaDbGuid,
                            tags = tags,
                            pageSize = 50,
                            isLoadMore = isLoadingMore,
                            sortColumn = sortColumnState,
                            sortOrder = sortOrderState
                        )
                        // 延迟重置加载状态，避免过于频繁的请求
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

    // 获取窗口高度
    val windowHeightPx = with(currentDensity) { store.windowHeightState.toPx()}.toInt()
    var previousFirstVisibleIndex by remember { mutableIntStateOf(0) }
    var shouldIgnoreScrollCheck by remember { mutableStateOf(false) }


    // 当筛选框展开/收起状态改变时，重置滚动检查相关状态
    LaunchedEffect(isFilterButtonSelected) {
        previousFirstVisibleIndex = 0
        if (isFilterButtonSelected) {
            // 筛选框刚展开时，忽略滚动检查一段时间
            shouldIgnoreScrollCheck = true
            kotlinx.coroutines.delay(100) // 等待筛选框完全展开
            shouldIgnoreScrollCheck = false
        }
    }

    // 监听滚动并判断是否需要收起筛选框
    LaunchedEffect(gridState, isFilterButtonSelected, filterBoxHeightPx, headerHeightPx, windowHeightPx) {
        if (!isFilterButtonSelected || filterBoxHeightPx == 0) return@LaunchedEffect

        snapshotFlow { gridState.firstVisibleItemIndex }
            .collect { firstVisibleIndex ->
                // 只有在滚动过程中才检查（当前索引与之前索引不同，且都不是0）
                if (!shouldIgnoreScrollCheck &&
                    firstVisibleIndex != previousFirstVisibleIndex &&
                    (previousFirstVisibleIndex > 0 || firstVisibleIndex > 0)) {

                    // 获取当前筛选框的底部位置（相对于窗口）
                    val filterBoxBottom = headerHeightPx + filterBoxHeightPx

                    // 计算筛选框底部到窗口底部的距离
                    val distanceToBottom = windowHeightPx - filterBoxBottom

                    // 获取海报高度的像素值
                    val posterHeightPx = with(currentDensity) { posterHeight.toPx() }.toInt()
                    val spacingPx = with(currentDensity) { spacing.toPx() }.toInt()

                    // 如果距离不足显示一行 MoviePoster，则收起筛选框
                    if (distanceToBottom < posterHeightPx + spacingPx) {
                        isFilterButtonSelected = false
                    }
                }

                previousFirstVisibleIndex = firstVisibleIndex
            }
    }

    // 监听刷新状态变化
    LaunchedEffect(refreshState.refreshKey) {
        // 当刷新状态变化时执行刷新逻辑
        if (refreshState.refreshKey.isNotEmpty()) {
            refreshState.onRefresh()
            // 重置滚动位置到顶部
            gridState.scrollToItem(0)
            // 执行当前页面的特定刷新逻辑
            itemListViewModel.loadData(
                guid = mediaDbGuid,
                tags = Tags(type = FnTvMediaType.getByCategory(category)),
                pageSize = 50,
                sortColumn = sortColumnState,
                sortOrder = sortOrderState
            )
            tagListViewModel.loadTagList(mediaDbGuid, 0, null)
            genresViewModel.loadGenres()
            tagViewModel.loadIso3166Tags()
            selectedFilters = emptyMap()
        }
    }

    // 监听排序变化
    LaunchedEffect(sortColumnState, sortOrderState) {
        // 当排序变化时执行刷新逻辑
        refreshState.onRefresh()
        // 重置滚动位置到顶部
        gridState.scrollToItem(0)
        // 执行当前页面的特定刷新逻辑
        itemListViewModel.loadData(
            guid = mediaDbGuid,
            tags = Tags(type = FnTvMediaType.getByCategory(category)),
            pageSize = 50,
            sortColumn = sortColumnState,
            sortOrder = sortOrderState
        )
        tagListViewModel.loadTagList(mediaDbGuid, 0, null)
        genresViewModel.loadGenres()
        tagViewModel.loadIso3166Tags()
        selectedFilters = emptyMap()
    }

    // 监听收藏操作结果并显示提示
    LaunchedEffect(favoriteUiState) {
        when (val state = favoriteUiState) {
            is UiState.Success -> {
                toastManager.showToast(state.data.message, state.data.success)
                // 调用对应的回调函数
                pendingCallbacks[state.data.guid]?.invoke(state.data.success)
                // 从 pendingCallbacks 中移除已处理的回调
                pendingCallbacks = pendingCallbacks - state.data.guid
            }

            is UiState.Error -> {
                // 显示错误提示
                toastManager.showToast("操作失败，${state.message}", false)
                state.operationId?.let {
                    pendingCallbacks[state.operationId]?.invoke(false)
                    // 从 pendingCallbacks 中移除已处理的回调
                    pendingCallbacks = pendingCallbacks - state.operationId
                }
            }

            else -> {}
        }

        // 清除状态
        if (favoriteUiState is UiState.Success || favoriteUiState is UiState.Error) {
            kotlinx.coroutines.delay(2000) // 2秒后清除状态
            favoriteViewModel.clearError()
        }
    }

    // 监听已观看操作结果并显示提示
    LaunchedEffect(watchedUiState) {
        when (val state = watchedUiState) {
            is UiState.Success -> {
                toastManager.showToast(state.data.message, state.data.success)
                // 调用对应的回调函数
                pendingCallbacks[state.data.guid]?.invoke(state.data.success)
                // 从 pendingCallbacks 中移除已处理的回调
                pendingCallbacks = pendingCallbacks - state.data.guid
            }

            is UiState.Error -> {
                // 显示错误提示
                toastManager.showToast("操作失败，${state.message}", false)
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
            kotlinx.coroutines.delay(2000) // 2秒后清除状态
            watchedViewModel.clearError()
        }
    }
    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxHeight()
                .onSizeChanged {
                    screenWidthPx = it.width
                },
            horizontalAlignment = Alignment.Start
        ) {
            Column(
                modifier = Modifier
                    .onGloballyPositioned { coordinates ->
                        headerHeightPx = coordinates.size.height
                    }
            ) {
                Text(
                    text = title,
                    style = LocalTypography.current.subtitle,
                    color = FluentTheme.colors.text.text.tertiary,
                    modifier = Modifier
                        .padding(top = 36.dp, start = 32.dp, bottom = 32.dp)
                )
                Row(
                    modifier = Modifier.padding(start = 32.dp, bottom = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterButton(
                        modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
                        isSelected = isFilterButtonSelected,
                        selectedFilters = selectedFilters,
                        onFilterClear = { title ->
                            // 创建一个新的 map，将指定标题的筛选项重置为"全部"
                            val updatedFilters = selectedFilters.toMutableMap()
                            if (title in updatedFilters) {
                                updatedFilters[title] = FilterItem("全部", null) // "全部"选项
                                selectedFilters = updatedFilters.toMap()
                            } else {
                                // 如果标题不在 selectedFilters 中，则创建一个新的 map，将所有选项重置为"全部"
                                val updatedFilters = selectedFilters.map { (key, _) ->
                                    key to FilterItem("全部", null)
                                }.toMap()
                                selectedFilters = updatedFilters
                            }

                            // 重新加载数据
                            val tags = buildTagsFromFilters()
                            itemListViewModel.loadData(
                                guid = mediaDbGuid,
                                tags = tags,
                                pageSize = 50,
                                sortColumn = sortColumnState,
                                sortOrder = sortOrderState
                            )
                        },
                        onClick = {
                            isFilterButtonSelected = !isFilterButtonSelected
                        }
                    )
                    SortFlyout(
                        onSortTypeSelected = { sortType ->
                            sortColumnState = sortType
                        },
                        onSortOrderSelected = { sortOrder ->
                            sortOrderState = sortOrder
                        },
                    )
                }
            }

            // 当筛选框展开时显示筛选框组件，直接嵌入到内容流中
            AnimatedVisibility(
                visible = isFilterButtonSelected,
                enter = expandVertically(
                    animationSpec = tween(durationMillis = 300)
                ) + fadeIn(
                    animationSpec = tween(durationMillis = 300)
                ),
                exit = shrinkVertically(
                    animationSpec = tween(durationMillis = 300)
                ) + fadeOut(
                    animationSpec = tween(durationMillis = 300)
                )
            ) {
                FilterBox(
                    modifier = Modifier
                        .padding(horizontal = 32.dp)
                        .padding(bottom = 16.dp)
                        .fillMaxWidth()
                        .onGloballyPositioned { coordinates ->
                            // 记录筛选框的高度和顶部位置
                            filterBoxHeightPx = coordinates.size.height
                        },
                    tagListUiState = tagListUiState,
                    genresUiState = genresUiState,
                    iso3166State = iso3166State,
                    initialSelectedFilters = selectedFilters,
                    onFilterChanged = { filters ->
                        selectedFilters = filters
                        // 当筛选条件改变时，重新加载数据
                        val tags = buildTagsFromFilters()
                        itemListViewModel.loadData(
                            guid = mediaDbGuid,
                            tags = tags,
                            pageSize = 50
                        )
                    },
                    onFilterBoxCollapse = {
                        isFilterButtonSelected = false
                    }
                )
            }

            ScrollbarContainer(
                adapter = rememberScrollbarAdapter(gridState)
            ) {
                when (val state = itemListUiState) {
                    is UiState.Success -> {
                        val mediaItems = state.data.list

                        LazyVerticalGrid(
                            columns = GridCells.Fixed(spanCount),
                            state = gridState,
                            modifier = Modifier
                                .padding(start = 32.dp, end = 32.dp, bottom = 16.dp)
                            ,
                            horizontalArrangement = Arrangement.spacedBy(spacing),
                            verticalArrangement = Arrangement.spacedBy(spacing)
                        ) {
                            items(mediaItems) { mediaItem ->
                                val itemData = convertToScrollRowItemData(mediaItem)
                                Box(
                                    modifier = Modifier
                                        .height(posterHeight)
                                        .fillMaxSize(),
                                    contentAlignment = Alignment.Center
                                ) {
                                    MoviePoster(
                                        modifier = Modifier
                                            .fillMaxHeight(),
                                        title = itemData.title,
                                        subtitle = itemData.subtitle,
                                        score = itemData.score,
                                        posterImg = itemData.posterImg,
                                        isFavorite = itemData.isFavourite,
                                        isAlreadyWatched = itemData.isAlreadyWatched,
                                        resolutions = itemData.resolutions,
                                        guid = itemData.guid,
                                        onFavoriteToggle = { guid, currentFavoriteState, resultCallback ->
                                            // 保存回调函数
                                            pendingCallbacks =
                                                pendingCallbacks + (guid to resultCallback)
                                            // 调用 ViewModel 方法
                                            favoriteViewModel.toggleFavorite(
                                                guid,
                                                currentFavoriteState
                                            )
                                        },
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
                                        posterWidth = itemData.posterWidth,
                                        posterHeight = itemData.posterHeight,
                                        status = itemData.status,
                                        navigator = navigator,
                                        type = itemData.type
                                    )
                                }

                            }
                        }
                    }

                    is UiState.Error -> {
                        // 显示错误信息
                        toastManager.showToast(
                            "获取媒体列表失败, cause: ${state.message}",
                            false,
                            10000
                        )
                    }

                    else -> {
                        // 初始状态或其他状态
                    }
                }
            }
        }
        ToastHost(
            toastManager = toastManager,
            modifier = Modifier.fillMaxSize()
        )
    }
}
