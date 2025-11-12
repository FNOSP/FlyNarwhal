package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.LocalRefreshState
import com.jankinwu.fntv.client.LocalTypography
import com.jankinwu.fntv.client.components
import com.jankinwu.fntv.client.data.convertor.convertMediaDbListResponseToScrollRowItem
import com.jankinwu.fntv.client.data.convertor.convertPlayDetailToScrollRowItemData
import com.jankinwu.fntv.client.data.convertor.convertToScrollRowItemData
import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import com.jankinwu.fntv.client.data.model.request.Tags
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.MediaLibCardRow
import com.jankinwu.fntv.client.ui.component.common.MediaLibGallery
import com.jankinwu.fntv.client.ui.component.common.RecentlyWatched
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.viewmodel.FavoriteViewModel
import com.jankinwu.fntv.client.viewmodel.ItemListViewModel
import com.jankinwu.fntv.client.viewmodel.MediaDbListViewModel
import com.jankinwu.fntv.client.viewmodel.PlayListViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.WatchedViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.Text
import io.github.composefluent.component.rememberScrollbarAdapter
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun HomePageScreen(navigator: ComponentNavigator) {
    val mediaDbListViewModel: MediaDbListViewModel = koinViewModel<MediaDbListViewModel>()
    val mediaDbUiState by mediaDbListViewModel.uiState.collectAsState()
    val playListViewModel: PlayListViewModel = koinViewModel<PlayListViewModel>()
    val playListUiState by playListViewModel.uiState.collectAsState()
    val favoriteViewModel: FavoriteViewModel = koinViewModel<FavoriteViewModel>()
    val favoriteUiState by favoriteViewModel.uiState.collectAsState()
    val watchedViewModel: WatchedViewModel = koinViewModel<WatchedViewModel>()
    val watchedUiState by watchedViewModel.uiState.collectAsState()
    val lazyListState = rememberLazyListState()
    val toastManager = rememberToastManager()
    val playerManager = LocalPlayerManager.current
    val mediaLibRefreshKeys = remember { mutableMapOf<String, String>() }
    // 存储回调函数
    var pendingCallbacks by remember { mutableStateOf<Map<String, (Boolean) -> Unit>>(emptyMap()) }
    // 缓存最近观看的项目列表状态
    var recentlyWatchedItems by remember {
        mutableStateOf<List<ScrollRowItemData>>(emptyList())
    }
    // 跟踪需要移除的项目
    var itemsToBeRemoved by remember {
        mutableStateOf<Set<String>>(emptySet())
    }
    val refreshState = LocalRefreshState.current
    val recentlyWatchedListState = rememberLazyListState()

    // 监听刷新状态变化
    LaunchedEffect(refreshState.refreshKey) {
        // 当刷新状态变化时执行刷新逻辑
        if (refreshState.refreshKey.isNotEmpty()) {
            refreshState.onRefresh()
            // 执行当前页面的特定刷新逻辑
            playListViewModel.refresh()
            mediaDbListViewModel.refresh()
        }
    }

    LaunchedEffect(Unit) {
        // 检查数据是否已加载，避免重复请求
        if (playListUiState !is UiState.Success) {
            playListViewModel.loadData()
        }
//        if (mediaDbUiState !is UiState.Success) {
//            mediaDbListViewModel.loadData()
//        }
    }

    // 当从播放器返回首页时刷新最近播放列表
    LaunchedEffect(playerManager.playerState) {
        if (!playerManager.playerState.isVisible) {
            playListViewModel.loadData()
        }
    }

    LaunchedEffect(playListUiState) {
        if (playListUiState is UiState.Success) {
            val playListData = (playListUiState as UiState.Success).data
            recentlyWatchedItems = playListData.map { item ->
                convertPlayDetailToScrollRowItemData(item)
            }
//            recentlyWatchedListState.scrollToItem(0)
            // 重置移除列表
            itemsToBeRemoved = emptySet()
        }
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
        Column(horizontalAlignment = Alignment.Start) {
            Text(
                text = "首页",
                style = LocalTypography.current.subtitle,
                color = FluentTheme.colors.text.text.tertiary,
                modifier = Modifier
//                .alignHorizontalSpace()
                    .padding(top = 36.dp, start = 32.dp, bottom = 32.dp)
            )
            ScrollbarContainer(
                adapter = rememberScrollbarAdapter(lazyListState)
            ) {
                LazyColumn(
                    state = lazyListState,
                    horizontalAlignment = Alignment.Start,
                    verticalArrangement = Arrangement.spacedBy(32.dp, Alignment.Top),
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .padding(bottom = 16.dp)
                ) {
                    item {
                        when (val mediaDbState = mediaDbUiState) {
                            is UiState.Success -> {
                                // 转换 MediaItem 到 MediaData
                                val mediaData = mediaDbState.data.map { item ->
                                    convertMediaDbListResponseToScrollRowItem(item)
                                }
                                MediaLibCardRow(
                                    mediaLibs = mediaData,
                                    title = "媒体库",
                                    onItemClick = { mediaDataItem ->
                                        // 查找对应的 ComponentItem (子组件)
                                        val targetComponent = components
                                            .firstOrNull { it.name == "媒体库" } // 找到"媒体库"父组件
                                            ?.items // 获取其子组件列表
                                            ?.firstOrNull { it.guid == mediaDataItem.guid } // 找到匹配的子组件

                                        targetComponent?.let {
                                            navigator.navigate(it)
                                        }
                                    }
                                )
                            }

                            else -> {}
                        }
                    }
                    // 过滤掉标记为移除的项目
                    val recentlyWatchedItemsFiltered = recentlyWatchedItems.filter {
                        !itemsToBeRemoved.contains(it.guid)
                    }
                    if (recentlyWatchedItemsFiltered.isNotEmpty()) {
                        item {
                            when (val playListState = playListUiState) {
                                is UiState.Success -> {
                                    RecentlyWatched(
                                        title = "继续观看",
                                        movies = recentlyWatchedItemsFiltered,
                                        recentlyWatchedListState = recentlyWatchedListState,
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
                                        onItemRemoved = { guid ->
                                            // 当项目动画结束时，将其添加到移除列表中
                                            itemsToBeRemoved = itemsToBeRemoved + guid
                                        },
                                        navigator = navigator
                                    )
                                }

                                is UiState.Error -> {
                                    toastManager.showToast(
                                        "获取最近观看列表失败，cause: ${playListState.message}",
                                        false,
                                        10000
                                    )
                                }

                                else -> {}
                            }
                        }
                    }
                    // 动态生成媒体库组件列表
                    when (val mediaDbState = mediaDbUiState) {
                        is UiState.Success -> {
                            items(mediaDbState.data) { mediaLib ->
                                val itemListViewModel: ItemListViewModel =
                                    koinViewModel(key = mediaLib.guid)
                                val itemListUiState =
                                    itemListViewModel.uiState.collectAsState().value
                                // 只在数据未加载时请求数据
                                LaunchedEffect(mediaLib.guid) {
                                    if (itemListUiState !is UiState.Success) {
                                        itemListViewModel.loadData(
                                            mediaLib.guid,
                                            Tags(type = FnTvMediaType.getCommonly())
                                        )
                                    }
                                }

                                // 监听刷新状态变化，触发数据重新加载
                                LaunchedEffect(refreshState.refreshKey) {
                                    val lastRefreshKey = mediaLibRefreshKeys[mediaLib.guid] ?: ""
                                    if (refreshState.refreshKey.isNotEmpty()
                                        && itemListUiState is UiState.Success
                                        && refreshState.refreshKey != lastRefreshKey
                                    ) {
                                        itemListViewModel.loadData(
                                            mediaLib.guid,
                                            Tags(type = FnTvMediaType.getCommonly())
                                        )
                                        // 更新 lastRefreshKey
                                        mediaLibRefreshKeys[mediaLib.guid] = refreshState.refreshKey
                                    }
                                }

                                // 转换 MediaItem 到 MediaData
                                val mediaDataList = when (val listState = itemListUiState) {
                                    is UiState.Success -> {
                                        listState.data.list.map { item ->
                                            convertToScrollRowItemData(item)
                                        }
                                    }

                                    else -> emptyList()
                                }
                                if (mediaDataList.isNotEmpty()) {
                                    MediaLibGallery(
                                        title = mediaLib.title,
                                        guid = mediaLib.guid,
                                        movies = mediaDataList,
                                        onFavoriteToggle = { guid, currentFavoriteState, resultCallback ->
                                            // 保存回调函数
                                            pendingCallbacks =
                                                pendingCallbacks + (guid to resultCallback)
                                            // 调用 ViewModel 方法
                                            favoriteViewModel.toggleFavorite(guid, currentFavoriteState)
                                        },
                                        onWatchedToggle = { guid, currentWatchedState, resultCallback ->
                                            // 保存回调函数
                                            pendingCallbacks =
                                                pendingCallbacks + (guid to resultCallback)
                                            // 调用 ViewModel 方法
                                            watchedViewModel.toggleWatched(guid, currentWatchedState)
                                        },
                                        navigator = navigator
                                    )
                                }
                            }
                        }

                        is UiState.Error -> {
                            item {
                                toastManager.showToast(
                                    "获取媒体库列表失败, cause: ${mediaDbState.message}",
                                    false,
                                    10000
                                )
                            }
                        }

                        else -> {
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

}