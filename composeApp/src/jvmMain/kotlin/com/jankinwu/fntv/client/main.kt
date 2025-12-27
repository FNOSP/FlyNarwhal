package com.jankinwu.fntv.client

import androidx.compose.foundation.window.WindowDraggableArea
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.WindowPlacement
import androidx.compose.ui.window.WindowPosition
import androidx.compose.ui.window.WindowState
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.network.apiModule
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.manager.PreferencesManager
import com.jankinwu.fntv.client.manager.ProxyManager
import com.jankinwu.fntv.client.ui.component.common.rememberComponentNavigator
import com.jankinwu.fntv.client.ui.providable.LocalFrameWindowScope
import com.jankinwu.fntv.client.ui.providable.LocalMediaPlayer
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitError
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitialized
import com.jankinwu.fntv.client.ui.providable.LocalWebViewRestartRequired
import com.jankinwu.fntv.client.ui.providable.LocalWindowHandle
import com.jankinwu.fntv.client.ui.providable.LocalWindowState
import com.jankinwu.fntv.client.ui.screen.NasLoginWebViewScreen
import com.jankinwu.fntv.client.ui.screen.FnConnectWindowRequest
import com.jankinwu.fntv.client.ui.screen.LoginScreen
import com.jankinwu.fntv.client.ui.screen.PlayerManager
import com.jankinwu.fntv.client.ui.screen.PlayerOverlay
import com.jankinwu.fntv.client.ui.screen.updateLoginHistory
import com.jankinwu.fntv.client.utils.ConsoleLogWriter
import com.jankinwu.fntv.client.utils.DesktopContext
import com.jankinwu.fntv.client.utils.ExecutableDirectoryDetector
import com.jankinwu.fntv.client.utils.ExtraWindowProperties
import com.jankinwu.fntv.client.utils.FileLogWriter
import com.jankinwu.fntv.client.utils.LocalContext
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.UserInfoViewModel
import com.jankinwu.fntv.client.viewmodel.viewModelModule
import com.jankinwu.fntv.client.window.WindowFrame
import dev.datlag.kcef.KCEF
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.icon
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.KoinApplication
import org.koin.compose.viewmodel.koinViewModel
import org.openani.mediamp.compose.rememberMediampPlayer
import java.awt.Dimension
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

@OptIn(FlowPreview::class)
fun main() {
    val logDir = initializeLoggingDirectory()
    Logger.setLogWriters(ConsoleLogWriter(), FileLogWriter(logDir))
    Logger.withTag("main").i { "Application started. Logs directory: ${logDir.absolutePath}" }

    WebViewBootstrap.start(
        installDir = kcefInstallDir(),
        cacheDir = kcefCacheDir()
    )

    application {
    DisposableEffect(Unit) {
        ProxyManager.start()
        onDispose {
            ProxyManager.stop()
        }
    }

    val webViewInitialized by WebViewBootstrap.initialized.collectAsState()
    val webViewRestartRequired by WebViewBootstrap.restartRequired.collectAsState()
    val webViewInitError by WebViewBootstrap.initError.collectAsState()

    DisposableEffect(Unit) {
        onDispose {
            KCEF.disposeBlocking()
        }
    }

    val (state, title, icon) = createWindowConfiguration()

    // 加载登录信息到缓存
    PreferencesManager.getInstance().loadAllLoginInfo()

    KoinApplication(application = {
        modules(viewModelModule, apiModule)
    }) {
        var fnConnectWindowRequest by remember { mutableStateOf<FnConnectWindowRequest?>(null) }
        Window(
            onCloseRequest = ::exitApplication,
            state = state,
            title = title,
            icon = icon
        ) {
            val isLoggedIn by LoginStateManager.isLoggedIn.collectAsState()
            val navigator = rememberComponentNavigator(isLoggedIn)
            val playerManager = remember { PlayerManager() }
            val player = rememberMediampPlayer()
            val userInfoViewModel: UserInfoViewModel = koinViewModel()
            val userInfoState by userInfoViewModel.uiState.collectAsState()
            LaunchedEffect(Unit) {
                val baseWidth = 1280
                val baseHeight = 720
                window.minimumSize = Dimension(baseWidth, baseHeight)
//                window.size = Dimension(baseWidth, baseHeight)
            }

            // 监听窗口位置变化并自动保存
            LaunchedEffect(state, playerManager.playerState.isVisible) {
                snapshotFlow { state.position to state.size }
                    .debounce(500)
                    .collect { (position, size) ->
                        // 只有当播放器不可见时才保存主窗口位置
                        if (!playerManager.playerState.isVisible) {
                            if (state.placement != WindowPlacement.Fullscreen && state.placement != WindowPlacement.Maximized) {
                                AppSettingsStore.windowWidth = size.width.value
                                AppSettingsStore.windowHeight = size.height.value
                                if (position is WindowPosition.Absolute) {
                                    AppSettingsStore.windowX = position.x.value
                                    AppSettingsStore.windowY = position.y.value
                                }
                            }
                        }
                    }
            }

            val desktopContext = remember(state) {
                val dataDir = logDir.parentFile.resolve("data").apply { if (!exists()) mkdirs() }
                val cacheDir = logDir.parentFile.resolve("cache").apply { if (!exists()) mkdirs() }
                DesktopContext(state, dataDir, cacheDir, logDir, ExtraWindowProperties())
            }

            CompositionLocalProvider(
                LocalContext provides desktopContext,
                LocalPlayerManager provides playerManager,
                LocalMediaPlayer provides player,
                LocalFrameWindowScope provides this@Window,
                LocalWindowState provides state,
                LocalWindowHandle provides window.windowHandle,
                LocalWebViewInitialized provides (webViewInitialized && webViewInitError == null),
                LocalWebViewRestartRequired provides webViewRestartRequired,
                LocalWebViewInitError provides webViewInitError
            ) {
                WindowFrame(
                    onCloseRequest = {
                        if (playerManager.playerState.isVisible) {
                            if (!AppSettingsStore.playerIsFullscreen) {
                                AppSettingsStore.playerWindowWidth = state.size.width.value
                                AppSettingsStore.playerWindowHeight = state.size.height.value
                                // 保存播放器位置
                                val position = state.position
                                if (position is WindowPosition.Absolute) {
                                    AppSettingsStore.playerWindowX = position.x.value
                                    AppSettingsStore.playerWindowY = position.y.value
                                }
                            }
                        } else {
                            if (state.placement != WindowPlacement.Fullscreen && state.placement != WindowPlacement.Maximized) {
                                AppSettingsStore.windowWidth = state.size.width.value
                                AppSettingsStore.windowHeight = state.size.height.value
                                // 保存主窗口位置
                                val position = state.position
                                if (position is WindowPosition.Absolute) {
                                    AppSettingsStore.windowX = position.x.value
                                    AppSettingsStore.windowY = position.y.value
                                }
                            }
                        }
                        player.close() // 关闭播放器
                        exitApplication() // 退出应用
                    },
                    icon = icon,
                    title = title,
                    state = state,
                    backButtonEnabled = navigator.canNavigateUp,
                    backButtonClick = { navigator.navigateUp() },
                    backButtonVisible = false
                ) { windowInset, contentInset ->
                    // 使用LoginStateManagement来管理登录状态
                    LaunchedEffect(isLoggedIn) {
                        if (isLoggedIn) {
                            userInfoViewModel.refresh()
                        }
                    }

                    LaunchedEffect(userInfoState, isLoggedIn) {
                        if (isLoggedIn && userInfoState is UiState.Error) {
                            LoginStateManager.updateLoginStatus(false)
                        }
                    }

                    // 只有在未登录状态下才显示登录界面
                    if (!isLoggedIn) {
                        LoginScreen(
                            navigator = navigator,
                            onOpenFnConnectWindow = { request ->
                                fnConnectWindowRequest = request
                            }
                        )
                    } else {
                        App(
                            windowInset = windowInset,
                            contentInset = contentInset,
                            navigator = navigator,
                            title = title,
                            icon = icon
                        )
                    }
                    // 显示播放器覆盖层
                    if (playerManager.playerState.isVisible) {
                        PlayerOverlay(
                            mediaTitle = playerManager.playerState.mediaTitle,
                            subhead = playerManager.playerState.subhead,
                            isEpisode = playerManager.playerState.isEpisode,
                            onBack = { playerManager.hidePlayer() },
                            mediaPlayer = player,
                            draggableArea = { content -> WindowDraggableArea(content = content) }
                        )
                    }
                }
            }
        }

        val request = fnConnectWindowRequest
        if (request != null) {
            val fnConnectWindowState = rememberWindowState(
                size = DpSize(980.dp, 720.dp),
                position = WindowPosition.Aligned(Alignment.Center)
            )

            Window(
                onCloseRequest = { fnConnectWindowRequest = null },
                state = fnConnectWindowState,
                title = "使用 NAS 登录",
                icon = icon
            ) {
                val desktopContext = remember(fnConnectWindowState) {
                    val dataDir = logDir.parentFile.resolve("data").apply { if (!exists()) mkdirs() }
                    val cacheDir = logDir.parentFile.resolve("cache").apply { if (!exists()) mkdirs() }
                    DesktopContext(fnConnectWindowState, dataDir, cacheDir, logDir, ExtraWindowProperties())
                }

                CompositionLocalProvider(
                    LocalContext provides desktopContext,
                    LocalPlayerManager provides remember { PlayerManager() },
                    LocalFrameWindowScope provides this@Window,
                    LocalWindowState provides fnConnectWindowState,
                    LocalWindowHandle provides window.windowHandle,
                    LocalWebViewInitialized provides (webViewInitialized && webViewInitError == null),
                    LocalWebViewRestartRequired provides webViewRestartRequired,
                    LocalWebViewInitError provides webViewInitError
                ) {
                    AppTheme(
                        displayMicaLayer = true,
                        state = fnConnectWindowState
                    ) {
                        NasLoginWebViewScreen(
                            initialUrl = request.initialUrl,
                            fnId = request.fnId,
                            onBack = { fnConnectWindowRequest = null },
                            onLoginSuccess = { history ->
                                val preferencesManager = PreferencesManager.getInstance()
                                val current = preferencesManager.loadLoginHistory()
                                val updated = updateLoginHistory(current, history)
                                preferencesManager.saveLoginHistory(updated)
                                fnConnectWindowRequest = null
                            },
                            autoLoginUsername = request.autoLoginUsername,
                            autoLoginPassword = request.autoLoginPassword,
                            allowAutoLogin = request.allowAutoLogin,
                            onBaseUrlDetected = if (request.onBaseUrlDetected != null) {
                                {
                                    request.onBaseUrlDetected.invoke(it)
                                    fnConnectWindowRequest = null
                                }
                            } else null
                        )
                    }
                }
            }
        }
    }
}
}

private object WebViewBootstrap {
    private val started = AtomicBoolean(false)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val initialized = MutableStateFlow(false)
    val restartRequired = MutableStateFlow(false)
    val initError = MutableStateFlow<Throwable?>(null)

    fun start(installDir: File, cacheDir: File) {
        if (!started.compareAndSet(false, true)) return

        scope.launch {
            try {
                if (!installDir.exists()) installDir.mkdirs()
                if (!cacheDir.exists()) cacheDir.mkdirs()

                KCEF.init(
                    builder = {
                        installDir(installDir)
                        settings {
                            cachePath = cacheDir.absolutePath
                        }
                        progress {
                            onInitialized {
                                initialized.value = true
                            }
                        }
                    },
                    onError = { throwable ->
                        initError.value = throwable
                    },
                    onRestartRequired = {
                        restartRequired.value = true
                    }
                )
            } catch (t: Throwable) {
                initError.value = t
            }
        }
    }
}

private fun kcefInstallDir(): File {
    val platform = currentPlatformDesktop()
    val baseDir = when (platform) {
        is Platform.Linux -> File(System.getProperty("user.home"), ".local/share/fn-media")
        is Platform.MacOS -> File(System.getProperty("user.home"), "Library/Application Support/fn-media")
        is Platform.Windows -> {
            val localAppData = System.getenv("LOCALAPPDATA")?.takeIf { it.isNotBlank() }
            File(localAppData ?: System.getProperty("user.home"), "FnMedia")
        }
    }
    return File(baseDir, "kcef-bundle")
}

private fun kcefCacheDir(): File {
    val platform = currentPlatformDesktop()
    val baseDir = when (platform) {
        is Platform.Linux -> File(System.getProperty("user.home"), ".local/share/fn-media")
        is Platform.MacOS -> File(System.getProperty("user.home"), "Library/Application Support/fn-media")
        is Platform.Windows -> {
            val localAppData = System.getenv("LOCALAPPDATA")?.takeIf { it.isNotBlank() }
            File(localAppData ?: System.getProperty("user.home"), "FnMedia")
        }
    }
    return File(baseDir, "kcef-cache")
}

/**
 * 初始化日志目录
 * 根据应用程序运行模式（开发模式或打包模式）确定日志目录位置
 */
private fun initializeLoggingDirectory(): File {
    val userDirStr = System.getProperty("user.dir")
    val userDirFile = File(userDirStr)
    
    // Check if we are running in development mode (via Gradle/IDE)
    // We assume dev mode if build.gradle.kts exists in user.dir or user.dir/composeApp
    val isDev = System.getProperty("compose.application.resources.dir") == null ||
            File(userDirFile, "build.gradle.kts").exists()

    val logDir = if (isDev) {
        // Dev mode: try to find project root to place logs there
        if (File(userDirFile.parentFile, "settings.gradle.kts").exists()) {
            File(userDirFile.parentFile, "logs")
        } else {
            File(userDirFile, "logs")
        }
    } else {
        // Packaged mode: use app dir / logs
        val platform = currentPlatformDesktop()
        when (platform) {
            is Platform.Linux -> {
                val userHome = System.getProperty("user.home")
                File(userHome, ".local/share/fn-media/logs")
            }
            is Platform.MacOS -> {
                val userHome = System.getProperty("user.home")
                File(userHome, "Library/Logs/fn-media")
            }
            is Platform.Windows -> {
                val appDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
                File(appDir, "logs")
            }
        }
    }

    if (!logDir.exists()) {
        logDir.mkdirs()
    }
    
    return logDir
}

/**
 * 创建窗口配置
 */
@Composable
private fun createWindowConfiguration(): Triple<WindowState, String, Painter> {
    val windowX = AppSettingsStore.windowX
    val windowY = AppSettingsStore.windowY
    val position = if (!windowX.isNaN() && !windowY.isNaN()) {
        WindowPosition(windowX.dp, windowY.dp)
    } else {
        WindowPosition(Alignment.Center)
    }
    val state = rememberWindowState(
        position = position,
//        size = DpSize.Unspecified
        size = DpSize(AppSettingsStore.windowWidth.dp, AppSettingsStore.windowHeight.dp)
    )
    val title = "飞牛影视"
    val icon = painterResource(Res.drawable.icon)
    return Triple(state, title, icon)
}
