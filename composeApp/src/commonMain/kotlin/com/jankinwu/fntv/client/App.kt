package com.jankinwu.fntv.client

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import coil3.ImageLoader
import coil3.compose.setSingletonImageLoaderFactory
import coil3.disk.DiskCache
import coil3.memory.MemoryCache
import coil3.request.CachePolicy
import coil3.request.crossfade
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.enums.Category
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.CategoryIcon
import com.jankinwu.fntv.client.icons.Home
import com.jankinwu.fntv.client.icons.MediaLibrary
import com.jankinwu.fntv.client.ui.component.common.ComponentItem
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.rememberComponentNavigator
import com.jankinwu.fntv.client.ui.screen.HomePageScreen
import com.jankinwu.fntv.client.ui.screen.MediaDbScreen
import com.jankinwu.fntv.client.ui.screen.SettingsScreen
import com.jankinwu.fntv.client.viewmodel.MediaDbListViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import io.github.composefluent.ExperimentalFluentApi
import io.github.composefluent.FluentTheme
import io.github.composefluent.animation.FluentDuration
import io.github.composefluent.animation.FluentEasing
import io.github.composefluent.component.AutoSuggestBoxDefaults
import io.github.composefluent.component.AutoSuggestionBox
import io.github.composefluent.component.Icon
import io.github.composefluent.component.ListItem
import io.github.composefluent.component.MenuItem
import io.github.composefluent.component.NavigationDefaults
import io.github.composefluent.component.NavigationDisplayMode
import io.github.composefluent.component.NavigationMenuItemScope
import io.github.composefluent.component.NavigationView
import io.github.composefluent.component.SideNavItem
import io.github.composefluent.component.TextBoxButton
import io.github.composefluent.component.TextBoxButtonDefaults
import io.github.composefluent.component.TextField
import io.github.composefluent.component.rememberNavigationState
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.ArrowLeft
import io.github.composefluent.icons.regular.Settings
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.map
import okhttp3.Headers
import okhttp3.Interceptor
import okhttp3.Response
import okio.FileSystem
import org.jetbrains.compose.ui.tooling.preview.Preview
import org.koin.compose.viewmodel.koinViewModel

val components = mutableStateListOf<ComponentItem>()

// 添加刷新状态的 CompositionLocal
val LocalRefreshState = staticCompositionLocalOf<RefreshState> {
    error("RefreshState not provided")
}

// 刷新状态数据类
data class RefreshState(
    val refreshKey: String = "",
    // 全局刷新回调
    val onRefresh: () -> Unit = {}
)

// 刷新状态管理类
class RefreshManager {
    var refreshState: RefreshState by mutableStateOf(RefreshState())

    fun requestRefresh(onRefresh: () -> Unit) {
        // 生成唯一的刷新键来触发刷新
        val newKey = System.currentTimeMillis().toString()
        refreshState = RefreshState(
            refreshKey = newKey,
            onRefresh = onRefresh
        )
    }
}

@OptIn(FlowPreview::class, ExperimentalFluentApi::class)
@Composable
@Preview
fun App(
    navigator: ComponentNavigator = rememberComponentNavigator(),
    windowInset: WindowInsets = WindowInsets(0),
    contentInset: WindowInsets = WindowInsets(0),
    collapseWindowInset: WindowInsets = WindowInsets(0),
    icon: Painter? = null,
    title: String = ""
) {
    CoilSetting()
    Navigation(navigator, windowInset, contentInset, collapseWindowInset, icon, title)
}

@Composable
fun CoilSetting() {
    setSingletonImageLoaderFactory { context ->
        ImageLoader.Builder(context)
            .crossfade(true)
            .memoryCachePolicy(CachePolicy.ENABLED)
            .memoryCache {
                MemoryCache.Builder()
                    .maxSizePercent(context, 0.05)
                    .strongReferencesEnabled(true)
                    .build()
            }
            .diskCachePolicy(CachePolicy.DISABLED)
            .diskCache(
                DiskCache.Builder()
                    .maxSizePercent(0.03)
                    .directory(FileSystem.SYSTEM_TEMPORARY_DIRECTORY / "fntv_coil_cache")
                    .build()
            )
//            .components {
//                add(
//                    OkHttpNetworkFetcherFactory(
//                        callFactory = OkHttpClient.Builder()
//                            .addNetworkInterceptor(RequestHeaderInterceptor())
//                            .build()
//                    )
//                )
//            }
//            .logger(DebugLogger())
            .build()
    }
}

class RequestHeaderInterceptor() : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val headers = Headers.Builder()
            .set("cookie", AccountDataCache.cookieState)
            .build()
        val request = chain.request().newBuilder()
            .headers(headers)
            .build()
        return chain.proceed(request)
    }
}

@OptIn(FlowPreview::class, ExperimentalFluentApi::class)
@Composable
fun Navigation(
    navigator: ComponentNavigator,
    windowInset: WindowInsets,
    contentInset: WindowInsets,
    collapseWindowInset: WindowInsets,
    icon: Painter?,
    title: String
) {
    val homePageItem =
        ComponentItem(
            "首页",
            "首页",
            "首页",
            icon = Home,
            content = { HomePageScreen(navigator) },
            guid = "homePage"
        )
    val homePageIndex = components.indexOfFirst { it.name == "首页" }
    if (homePageIndex < 0) {
        components.add(homePageItem)
        navigator.addStartItem(homePageItem)
    }
    var selectedItemWithContent by remember {
        mutableStateOf(navigator.latestBackEntry)
    }
    LaunchedEffect(navigator.latestBackEntry) {
        val latestBackEntry = navigator.latestBackEntry
        if (selectedItemWithContent == latestBackEntry) return@LaunchedEffect
        if (latestBackEntry == null || latestBackEntry.content != null) {
            selectedItemWithContent = latestBackEntry
        }
    }

    MediaLibraryNavigationComponent()

    var textFieldValue by remember {
        mutableStateOf(TextFieldValue())
    }

    val settingItem = remember(navigator) {
        ComponentItem(
            "Settings",
            group = "",
            description = "",
            icon = Icons.Default.Settings,
            guid = "settings",
        ) { SettingsScreen(navigator) }
    }
    val store = LocalStore.current
    val isCollapsed = store.navigationDisplayMode == NavigationDisplayMode.LeftCollapsed
    NavigationView(
        modifier = Modifier
            .windowInsetsPadding(
                insets = if (isCollapsed) collapseWindowInset else windowInset
            ),
        state = rememberNavigationState(),
        displayMode = store.navigationDisplayMode,
        contentPadding = if (!isCollapsed) {
            PaddingValues()
        } else {
            PaddingValues(top = 48.dp)
        },
        menuItems = {
            components.forEach { navItem ->
                item {
                    MenuItem(
                        navigator.latestBackEntry,
                        navigator::navigate,
                        navItem,
                        navItem.name == "首页"
                    )
                }
            }
        },
        footerItems = {
            item {
                MenuItem(navigator.latestBackEntry, navigator::navigate, settingItem)
            }
        },
        title = {
            if (isCollapsed) {
                if (icon != null) {
                    Image(
                        painter = icon,
                        contentDescription = null,
                        modifier = Modifier.padding(start = 12.dp).size(16.dp)
                    )
                }
                if (title.isNotEmpty()) {
                    io.github.composefluent.component.Text(
                        text = title,
                        style = FluentTheme.typography.caption,
                        modifier = Modifier.padding(start = 12.dp)
                    )
                }
            } else {
                io.github.composefluent.component.Text("")
            }
        },
        backButton = {
            if (isCollapsed) {
                NavigationDefaults.BackButton(
                    onClick = {
                        navigator.navigateUp()
                    },
                    disabled = !navigator.canNavigateUp,
                    icon = { Icon(Icons.Default.ArrowLeft, contentDescription = null) },
                    modifier = Modifier.windowInsetsPadding(contentInset.only(WindowInsetsSides.Start))
                )
            }
        },
        autoSuggestBox = {
            var expandedSuggestion by remember { mutableStateOf(false) }
            AutoSuggestionBox(
                expanded = expandedSuggestion,
                onExpandedChange = { expandedSuggestion = it }
            ) {
                TextField(
                    value = textFieldValue,
                    onValueChange = { textFieldValue = it },
                    placeholder = { io.github.composefluent.component.Text("Search") },
                    trailing = {
                        TextBoxButton(onClick = {}) { TextBoxButtonDefaults.SearchIcon() }
                    },
                    isClearable = true,
                    shape = AutoSuggestBoxDefaults.textFieldShape(expandedSuggestion),
                    modifier = Modifier.fillMaxWidth().focusHandle().flyoutAnchor()
                )
                val searchResult = remember(flatMapComponents) {
                    snapshotFlow {
                        textFieldValue.text
                    }.debounce { if (it.isBlank()) 0 else 200 }
                        .map {
                            flatMapComponents.filter { item ->
                                item.name.contains(
                                    it,
                                    ignoreCase = true
                                ) || item.description.contains(it, ignoreCase = true)
                            }
                        }
                }.collectAsState(flatMapComponents)
                AutoSuggestBoxDefaults.suggestFlyout(
                    expanded = expandedSuggestion,
                    onDismissRequest = { expandedSuggestion = false },
                    modifier = Modifier.flyoutSize(matchAnchorWidth = true),
                    itemsContent = {
                        items(
                            items = searchResult.value,
                            contentType = { "Item" },
                            key = { it.hashCode().toString() }
                        ) {
                            ListItem(
                                onClick = {
                                    navigator.navigate(it)
                                    expandedSuggestion = false
                                },
                                text = {
                                    io.github.composefluent.component.Text(
                                        it.name,
                                        maxLines = 1
                                    )
                                },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                )
            }
        },
        pane = {
            AnimatedContent(selectedItemWithContent, Modifier.fillMaxSize(), transitionSpec = {
                (fadeIn(
                    tween(
                        FluentDuration.ShortDuration,
                        easing = FluentEasing.FadeInFadeOutEasing,
                        delayMillis = FluentDuration.QuickDuration
                    )
                ) + slideInVertically(
                    tween(
                        FluentDuration.MediumDuration,
                        easing = FluentEasing.FastInvokeEasing,
                        delayMillis = FluentDuration.QuickDuration
                    )
                ) { it / 5 }) togetherWith fadeOut(
                    tween(
                        FluentDuration.QuickDuration,
                        easing = FluentEasing.FadeInFadeOutEasing,
                        delayMillis = FluentDuration.QuickDuration
                    )
                )
            }) {
                if (it != null) {
                    it.content?.invoke(it, navigator)
                } else {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        io.github.composefluent.component.Text(
                            "No content selected",
                            style = FluentTheme.typography.bodyStrong
                        )
                    }
                }
            }
        }
    )
}

@Composable
private fun NavigationMenuItemScope.MenuItem(
    selectedItem: ComponentItem?,
    onSelectedItemChanged: (ComponentItem) -> Unit,
    navItem: ComponentItem,
    hasSeparator: Boolean = false
) {
    val expandedItems = remember {
        mutableStateOf(false)
    }
    LaunchedEffect(selectedItem) {
        if (selectedItem == null) return@LaunchedEffect
        if (navItem != selectedItem) {
            val navItemAsGroup = "${navItem.group}/${navItem.name}/"
            if ((selectedItem.group + "/").startsWith(navItemAsGroup))
                expandedItems.value = true
        }
    }
    val flyoutVisible = remember {
        mutableStateOf(false)
    }
    if (!hasSeparator) {
        MenuItem(
            selected = selectedItem == navItem,
            onClick = {
                onSelectedItemChanged(navItem)
                expandedItems.value = !expandedItems.value
                if (navItem.items.isNullOrEmpty()) {
                    flyoutDismissRequest()
                }
            },
            icon = navItem.icon?.let { { Icon(it, navItem.name) } },
            text = { io.github.composefluent.component.Text(navItem.name) },
            expandItems = expandedItems.value || flyoutVisible.value,
            onExpandItemsChanged = { flyoutVisible.value = it },
            items = navItem.items?.let {
                if (it.isNotEmpty()) {
                    {
                        it.forEach { nestedItem ->
                            NavigationItem(
                                selectedItem = selectedItem,
                                onSelectedItemChanged = {
                                    onSelectedItemChanged(nestedItem)
                                },
                                navItem = nestedItem,
                                onFlyoutDismissRequest = {
                                    isFlyoutVisible = false
                                    flyoutDismissRequest()
                                }
                            )
                        }
                    }
                } else {
                    null
                }
            }
        )
    } else {
        MenuItem(
            selected = selectedItem == navItem,
            onClick = {
                onSelectedItemChanged(navItem)
                expandedItems.value = !expandedItems.value
            },
            icon = navItem.icon?.let { { Icon(it, navItem.name) } },
            text = { io.github.composefluent.component.Text(navItem.name) },
            expandItems = expandedItems.value || flyoutVisible.value,
            onExpandItemsChanged = { flyoutVisible.value = it },
            items = navItem.items?.let {
                if (it.isNotEmpty()) {
                    {
                        it.forEach { nestedItem ->
                            NavigationItem(
                                selectedItem = selectedItem,
                                onSelectedItemChanged = {
                                    onSelectedItemChanged(nestedItem)
                                },
                                navItem = nestedItem,
                                onFlyoutDismissRequest = {
                                    isFlyoutVisible = false
                                    flyoutDismissRequest()
                                }
                            )
                        }
                    }
                } else {
                    null
                }
            },
            header = null,
            separatorVisible = true
        )
    }
}

@Composable
private fun NavigationItem(
    selectedItem: ComponentItem?,
    onSelectedItemChanged: (ComponentItem) -> Unit,
    navItem: ComponentItem,
    onFlyoutDismissRequest: () -> Unit = {},
) {
    val expandedItems = remember {
        mutableStateOf(false)
    }
    LaunchedEffect(selectedItem) {
        if (selectedItem == null) return@LaunchedEffect
        if (navItem != selectedItem) {
            val navItemAsGroup = "${navItem.group}/${navItem.name}/"
            if ((selectedItem.group + "/").startsWith(navItemAsGroup))
                expandedItems.value = true
        }
    }
    SideNavItem(
        selectedItem == navItem,
        onClick = {
            onSelectedItemChanged(navItem)
            if (navItem.items == null) {
                onFlyoutDismissRequest()
            } else {
                expandedItems.value = !expandedItems.value
            }
        },
        icon = navItem.icon?.let { { Icon(it, navItem.name, tint = Color.White) } },
        content = { io.github.composefluent.component.Text(navItem.name) },
        expandItems = expandedItems.value,
        items = navItem.items?.let {
            if (it.isNotEmpty()) {
                {
                    it.forEach { nestedItem ->
                        NavigationItem(
                            selectedItem = selectedItem,
                            onSelectedItemChanged = onSelectedItemChanged,
                            navItem = nestedItem,
                            onFlyoutDismissRequest = onFlyoutDismissRequest
                        )
                    }
                }
            } else {
                null
            }
        },
        modifier = Modifier
            .pointerHoverIcon(PointerIcon.Hand)
    )
}

val flatMapComponents: List<ComponentItem> by lazy {
    listOf(
        ComponentItem("测试", "测试组", "测试描述", content = null)
    )
}

//@Composable
//internal fun ReadEnvVariable() {
//    val fnOfficialBaseUrl = System.getenv("FN_OFFICIAL_BASE_URL")
//    if (fnOfficialBaseUrl != null) {
//        println("FN_OFFICIAL_BASE_URL: $fnOfficialBaseUrl")
////        SystemAccountData.fnOfficialBaseUrl = fnOfficialBaseUrl
//    } else {
//        println("FN_OFFICIAL_BASE_URL: null")
//    }
//    val fnTvBackendBaseUrl = System.getenv("FN_TV_BACKEND_BASE_URL")
//    if (fnTvBackendBaseUrl != null) {
//        println("FN_TV_BACKEND_BASE_URL: $fnTvBackendBaseUrl")
//        SystemAccountData.fnTvBackendBaseUrl = fnTvBackendBaseUrl
//    } else {
//        println("FN_TV_BACKEND_BASE_URL: null")
//    }
//    val authorization = System.getenv("AUTHORIZATION")
//    if (authorization != null) {
//        println("AUTHORIZATION: $authorization")
//        SystemAccountData.authorization = authorization
//    }
//    val cookie = System.getenv("COOKIE")
//    if (cookie != null) {
//        println("COOKIE: $cookie")
//        SystemAccountData.cookie = cookie
//    }
//}

@Composable
fun MediaLibraryNavigationComponent() {

    val mediaDbListViewModel: MediaDbListViewModel = koinViewModel<MediaDbListViewModel>()
    val mediaUiState by mediaDbListViewModel.uiState.collectAsState()

    // 动态生成组件列表
    LaunchedEffect(mediaUiState) {
        val categoryItems = listOf(
            ComponentItem(
                name = "全部",
                group = "/分类",
                description = "全部",
                type = FnTvMediaType.getCommonly(),
                guid = "bb042b7d-c038-f9e2-36ed-6e166a20019c",
                content = { navigator ->
                    MediaDbScreen(title = "全部", category = "", navigator = navigator)
                }
            ),
            ComponentItem(
                name = "电视节目",
                group = "/分类",
                description = "电视节目",
                type = FnTvMediaType.getCommonly(),
                guid = "709e30ec-9a51-34ab-b189-8ae6fdd1b0a7",
                content = { navigator ->
                    MediaDbScreen(
                        title = "电视节目",
                        category = Category.TV.value,
                        navigator = navigator
                    )
                }
            ),
            ComponentItem(
                name = "电影",
                group = "/分类",
                description = "电影",
                type = FnTvMediaType.getCommonly(),
                guid = "f1a58953-85c1-ab3f-3bda-d90f50db0d69",
                content = { navigator ->
                    MediaDbScreen(
                        title = "电影",
                        category = Category.MOVIE.value,
                        navigator = navigator
                    )
                }
            ),
            ComponentItem(
                name = "其他",
                group = "/分类",
                description = "其他",
                type = FnTvMediaType.getCommonly(),
                guid = "b192a025-3cc5-a21c-7d68-726b852d02af",
                content = { navigator ->
                    MediaDbScreen(
                        title = "其他",
                        category = Category.OTHERS.value,
                        navigator = navigator
                    )
                }
            ),
        )
        val state = mediaUiState
        // 查找现有的媒体库组件索引
        val mediaLibraryIndex = components.indexOfFirst { it.name == "媒体库" }
        when (state) {
            is UiState.Success -> {
                // 动态生成媒体库组件
                val mediaItems = state.data.map { mediaDb ->
                    ComponentItem(
                        name = mediaDb.title,
                        group = "/媒体库",
                        description = mediaDb.title,
                        guid = mediaDb.guid,
                        type = FnTvMediaType.getCommonly(),
                        content = { navigator ->
                            MediaDbScreen(
                                mediaDb.guid,
                                mediaDb.title,
                                "",
                                navigator = navigator
                            )
                        }
                    )
                }

                // 创建媒体库父组件
                val mediaLibraryComponent = ComponentItem(
                    name = "媒体库",
                    group = "",
                    description = "媒体库",
                    icon = MediaLibrary,
                    content = { /* 这里可能需要调整逻辑 */ },
                    items = mediaItems,
                    guid = "9e63fc61-eb41-0e19-6d09-73f92969fc95"
                )

                // 更新或添加到components列表中
                if (mediaLibraryIndex >= 0) {
                    // 如果已存在，更新它
                    components[mediaLibraryIndex] = mediaLibraryComponent
                } else {
                    // 如果不存在，添加到列表末尾
                    components.add(mediaLibraryComponent)
                }
                val categoryParentComponent = ComponentItem(
                    name = "分类",
                    group = "",
                    description = "分类",
                    icon = CategoryIcon,
                    content = {},
                    items = categoryItems,
                    guid = "62fbfbba-3808-85b8-a09d-3c7766a289b8",
                )
                val categoryIndex = components.indexOfFirst { it.name == "分类" }
                if (categoryIndex < 0) {
                    components.add(categoryParentComponent)
                }
            }

            else -> {
            }

        }
    }

    // 在初始化时加载媒体数据
    LaunchedEffect(Unit) {
        mediaDbListViewModel.loadData()
    }
}