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
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.network.apiModule
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore
import com.jankinwu.fntv.client.jna.windows.User32Extend
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.manager.PreferencesManager
import com.jankinwu.fntv.client.manager.ProxyManager
import com.jankinwu.fntv.client.ui.component.common.rememberComponentNavigator
import com.jankinwu.fntv.client.ui.dialog.KcefInitErrorDialog
import com.jankinwu.fntv.client.ui.providable.LocalFrameWindowScope
import com.jankinwu.fntv.client.ui.providable.LocalMediaPlayer
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitError
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitialized
import com.jankinwu.fntv.client.ui.providable.LocalWebViewRestartRequired
import com.jankinwu.fntv.client.ui.providable.LocalWindowHandle
import com.jankinwu.fntv.client.ui.providable.LocalWindowState
import com.jankinwu.fntv.client.ui.screen.FnConnectWindowRequest
import com.jankinwu.fntv.client.ui.screen.LoginScreen
import com.jankinwu.fntv.client.ui.screen.NasLoginWebViewScreen
import com.jankinwu.fntv.client.ui.screen.PlayerManager
import com.jankinwu.fntv.client.ui.screen.PlayerOverlay
import com.jankinwu.fntv.client.ui.screen.updateLoginHistory
import com.jankinwu.fntv.client.ui.window.PipPlayerWindow
import com.jankinwu.fntv.client.ui.window.SplashScreen
import com.jankinwu.fntv.client.utils.ComposeViewModelStoreOwner
import com.jankinwu.fntv.client.utils.ConsoleLogWriter
import com.jankinwu.fntv.client.utils.DesktopContext
import com.jankinwu.fntv.client.utils.DesktopLogExporter
import com.jankinwu.fntv.client.utils.ExecutableDirectoryDetector
import com.jankinwu.fntv.client.utils.ExtraWindowProperties
import com.jankinwu.fntv.client.utils.FileLogWriter
import com.jankinwu.fntv.client.utils.LocalContext
import com.jankinwu.fntv.client.utils.LocalLogExporter
import com.jankinwu.fntv.client.utils.WebViewBootstrap
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.UserInfoViewModel
import com.jankinwu.fntv.client.viewmodel.viewModelModule
import com.jankinwu.fntv.client.window.WindowFrame
import com.jankinwu.fntv.client.window.findSkiaLayer
import com.sun.jna.Pointer
import com.sun.jna.platform.win32.Kernel32
import com.sun.jna.platform.win32.WinDef.HWND
import com.sun.jna.platform.win32.WinUser
import dev.datlag.kcef.KCEF
import flynarwhal.composeapp.generated.resources.Res
import flynarwhal.composeapp.generated.resources.icon
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.debounce
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.KoinApplication
import org.koin.compose.viewmodel.koinViewModel
import org.openani.mediamp.PlaybackState
import org.openani.mediamp.compose.rememberMediampPlayer
import java.awt.Dimension
import java.awt.event.ComponentAdapter
import java.awt.event.ComponentEvent
import java.io.File

private object WindowsDisplaySleepBlocker {
    private const val ES_SYSTEM_REQUIRED = 0x00000001
    private const val ES_DISPLAY_REQUIRED = 0x00000002
    private const val ES_CONTINUOUS = 0x80000000.toInt()

    private val logger = Logger.withTag("WindowsDisplaySleepBlocker")

    fun setEnabled(enabled: Boolean) {
        if (!currentPlatform().isWindows()) return
        try {
            val flags = if (enabled) {
                ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED
            } else {
                ES_CONTINUOUS
            }
            val previous = Kernel32.INSTANCE.SetThreadExecutionState(flags)
            if (previous == 0) {
                logger.w { "SetThreadExecutionState returned 0 (failed), enabled=$enabled" }
            }
        } catch (t: Throwable) {
            logger.w(t) { "Failed to set execution state, enabled=$enabled" }
        }
    }
}

@OptIn(FlowPreview::class)
fun main() {
    val logDir = initializeLoggingDirectory()
    Logger.setLogWriters(ConsoleLogWriter(), FileLogWriter(logDir))
    val logger = Logger.withTag("main")
    logger.i { "Application started. Logs directory: ${logDir.absolutePath}" }

    // Cleanup old KCEF directories
    val baseDir = kcefBaseDir()
    val installDir = File(baseDir, "kcef-bundle-${BuildConfig.VERSION_NAME}")
    val cacheDir = File(baseDir, "kcef-cache-${BuildConfig.VERSION_NAME}")
    cleanupOldKcefDirs(baseDir)
    logger.i { "KCEF base directory: ${baseDir.absolutePath}" }
    logger.i { "KCEF install directory: ${installDir.absolutePath}" }
    logger.i { "KCEF cache directory: ${cacheDir.absolutePath}" }

    application {
        LaunchedEffect(Unit) {
            WebViewBootstrap.start(
                installDir = installDir,
                cacheDir = cacheDir,
                logDir = logDir
            )
        }

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

        // 加载登录信息到缓存
        PreferencesManager.getInstance().loadAllLoginInfo()

        KoinApplication(application = {
            modules(viewModelModule, apiModule)
        }) {
            val viewModelStoreOwner = remember { ComposeViewModelStoreOwner() }
            DisposableEffect(viewModelStoreOwner) {
                onDispose { viewModelStoreOwner.dispose() }
            }

            CompositionLocalProvider(LocalViewModelStoreOwner provides viewModelStoreOwner) {
                val isLoggedIn by LoginStateManager.isLoggedIn.collectAsState()
                val navigator = rememberComponentNavigator(isLoggedIn)
                val playerManager = remember { PlayerManager() }
                val player = rememberMediampPlayer()
                val userInfoViewModel: UserInfoViewModel = koinViewModel()
                val userInfoState by userInfoViewModel.uiState.collectAsState()

                var fnConnectWindowRequest by remember {
                    mutableStateOf<FnConnectWindowRequest?>(
                        null
                    )
                }
                val (mainState, title, icon) = createWindowConfiguration()
                val savedPlayerX = AppSettingsStore.playerWindowX
                val savedPlayerY = AppSettingsStore.playerWindowY
                val playerPosition = if (!savedPlayerX.isNaN() && !savedPlayerY.isNaN()) {
                    WindowPosition(savedPlayerX.dp, savedPlayerY.dp)
                } else {
                    WindowPosition.Aligned(Alignment.Center)
                }
                val playerState = rememberWindowState(
                    position = playerPosition,
                    size = DpSize(
                        AppSettingsStore.playerWindowWidth.dp,
                        AppSettingsStore.playerWindowHeight.dp
                    )
                )

                // 监听窗口位置变化并自动保存 (主窗口)
                LaunchedEffect(mainState, playerManager.playerState.isVisible) {
                    snapshotFlow { mainState.position to mainState.size }
                        .debounce(500)
                        .collect { (position, size) ->
                            if (mainState.placement != WindowPlacement.Fullscreen && mainState.placement != WindowPlacement.Maximized) {
                                AppSettingsStore.windowWidth = size.width.value
                                AppSettingsStore.windowHeight = size.height.value
                                AppSettingsStore.isWindowMaximized = false
                                if (position is WindowPosition.Absolute) {
                                    AppSettingsStore.windowX = position.x.value
                                    AppSettingsStore.windowY = position.y.value
                                }
                            }else if (mainState.placement == WindowPlacement.Maximized) {
                                AppSettingsStore.isWindowMaximized = true
                            }
                        }
                }

                val desktopContext = remember(mainState) {
                    val dataDir =
                        logDir.parentFile.resolve("data").apply { if (!exists()) mkdirs() }
                    val cacheDir =
                        logDir.parentFile.resolve("cache").apply { if (!exists()) mkdirs() }
                    DesktopContext(mainState, dataDir, cacheDir, logDir, ExtraWindowProperties())
                }

                val logExporter = remember { DesktopLogExporter(logDir) }

                val playerDesktopContext = remember(playerState) {
                    val dataDir =
                        logDir.parentFile.resolve("data").apply { if (!exists()) mkdirs() }
                    val cacheDir =
                        logDir.parentFile.resolve("cache").apply { if (!exists()) mkdirs() }
                    DesktopContext(playerState, dataDir, cacheDir, logDir, ExtraWindowProperties())
                }

                val osName = System.getProperty("os.name").lowercase()
                val isMacOS = osName.contains("mac")

                if (isMacOS && !webViewInitialized && webViewInitError == null) {
                    Window(
                        onCloseRequest = ::exitApplication,
                        title = title,
                        state = rememberWindowState(
                            width = 400.dp,
                            height = 200.dp,
                            position = WindowPosition(Alignment.Center)
                        ),
                        undecorated = true,
                        transparent = true,
                        icon = icon
                    ) {
                        SplashScreen(
                            icon = icon,
                            title = title,
                            error = webViewInitError
                        )
                    }
                } else {
                    // 主窗口
                    Window(
                        onCloseRequest = ::exitApplication,
                        state = mainState,
                        title = title,
                        icon = icon,
                        visible = !playerManager.playerState.isVisible
                    ) {
                        val shouldStartMaximized = remember { AppSettingsStore.isWindowMaximized }
                        DisposableEffect(shouldStartMaximized) {
                            if (!shouldStartMaximized) return@DisposableEffect onDispose {}

                            var applied = false
                            val listener = object : ComponentAdapter() {
                                override fun componentShown(e: ComponentEvent) {
                                    if (applied) return
                                    applied = true

                                    if (currentPlatform().isWindows()) {
                                        val hWnd = HWND(Pointer(window.windowHandle))
                                        User32Extend.instance?.ShowWindow(hWnd, WinUser.SW_MAXIMIZE)
                                        User32Extend.instance?.RedrawWindow(
                                            hWnd,
                                            null,
                                            null,
                                            WinUser.RDW_INVALIDATE or
                                                WinUser.RDW_UPDATENOW or
                                                WinUser.RDW_FRAME or
                                                WinUser.RDW_ALLCHILDREN or
                                                WinUser.RDW_ERASE
                                        )
                                    }

                                    mainState.placement = WindowPlacement.Maximized
                                    window.findSkiaLayer()?.apply {
                                        invalidate()
                                        revalidate()
                                        repaint()
                                    }
                                    window.invalidate()
                                    window.validate()
                                    window.repaint()
                                }
                            }

                            window.addComponentListener(listener)
                            onDispose { window.removeComponentListener(listener) }
                        }
                        LaunchedEffect(Unit) {
                            val baseWidth = 1280
                            val baseHeight = 720
                            window.minimumSize = Dimension(baseWidth, baseHeight)
                        }

                        CompositionLocalProvider(
                            LocalViewModelStoreOwner provides viewModelStoreOwner,
                            LocalContext provides desktopContext,
                            LocalLogExporter provides logExporter,
                            LocalPlayerManager provides playerManager,
                            LocalMediaPlayer provides player,
                            LocalFrameWindowScope provides this@Window,
                            LocalWindowState provides mainState,
                            LocalWindowHandle provides window.windowHandle,
                            LocalWebViewInitialized provides (webViewInitialized && webViewInitError == null),
                            LocalWebViewRestartRequired provides webViewRestartRequired,
                            LocalWebViewInitError provides webViewInitError
                        ) {
                            var errorDialogDismissed by remember { mutableStateOf(false) }
                            if (webViewInitError != null && !errorDialogDismissed) {
                                KcefInitErrorDialog(
                                    error = webViewInitError,
                                    onDismiss = { errorDialogDismissed = true }
                                )
                            }

                            WindowFrame(
                                onCloseRequest = ::exitApplication,
                                icon = icon,
                                title = title,
                                state = mainState,
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
                            }
                        }
                    }

                    // 播放器窗口
                    if (playerManager.playerState.isVisible && !playerManager.isPipMode) {
                        Window(
                            onCloseRequest = {
                                if (PlayingSettingsStore.playerIsFullscreen) {
                                    playerState.placement = WindowPlacement.Floating
                                    PlayingSettingsStore.playerIsFullscreen = false
                                }
                                playerManager.hidePlayer()
                                player.stopPlayback()
                            },
                            state = playerState,
                            title = playerManager.playerState.mediaTitle,
                            icon = icon,
                            undecorated = false
                        ) {
                            val playState by player.playbackState.collectAsState()
                            val shouldBlockDisplaySleep = playState == PlaybackState.PLAYING

                            DisposableEffect(shouldBlockDisplaySleep) {
                                WindowsDisplaySleepBlocker.setEnabled(shouldBlockDisplaySleep)
                                onDispose {
                                    WindowsDisplaySleepBlocker.setEnabled(false)
                                }
                            }

                            LaunchedEffect(Unit) {
                                val baseWidth = 600
                                val baseHeight = 400
                                window.minimumSize = Dimension(baseWidth, baseHeight)
                            }

                            CompositionLocalProvider(
                                LocalViewModelStoreOwner provides viewModelStoreOwner,
                                LocalContext provides playerDesktopContext,
                                LocalLogExporter provides logExporter,
                                LocalPlayerManager provides playerManager,
                                LocalMediaPlayer provides player,
                                LocalFrameWindowScope provides this@Window,
                                LocalWindowState provides playerState,
                                LocalWindowHandle provides window.windowHandle,
                                LocalWebViewInitialized provides (webViewInitialized && webViewInitError == null),
                                LocalWebViewRestartRequired provides webViewRestartRequired,
                                LocalWebViewInitError provides webViewInitError
                            ) {
                                WindowFrame(
                                    onCloseRequest = {
                                        if (PlayingSettingsStore.playerIsFullscreen) {
                                            playerState.placement = WindowPlacement.Floating
                                            PlayingSettingsStore.playerIsFullscreen = false
                                        }
                                        playerManager.hidePlayer()
                                        player.stopPlayback()
                                    },
                                    icon = icon,
                                    title = playerManager.playerState.mediaTitle,
                                    state = playerState,
                                    backButtonVisible = false,
                                    backButtonEnabled = false,
                                    backButtonClick = {
                                        if (PlayingSettingsStore.playerIsFullscreen) {
                                            playerState.placement = WindowPlacement.Floating
                                            PlayingSettingsStore.playerIsFullscreen = false
                                        }
                                        playerManager.hidePlayer()
                                        player.stopPlayback()
                                    }
                                ) { _, _ ->
                                    PlayerOverlay(
                                        mediaTitle = playerManager.playerState.mediaTitle,
                                        subhead = playerManager.playerState.subhead,
                                        isEpisode = playerManager.playerState.isEpisode,
                                        onBack = {
                                            if (PlayingSettingsStore.playerIsFullscreen) {
                                                playerState.placement = WindowPlacement.Floating
                                                PlayingSettingsStore.playerIsFullscreen = false
                                            }
                                            playerManager.hidePlayer()
                                            // 停止播放
                                            player.stopPlayback()
                                        },
                                        mediaPlayer = player,
                                        draggableArea = { content -> WindowDraggableArea(content = content) }
                                    )
                                }
                            }
                        }
                    }

                    // 小窗模式
                    if (playerManager.isPipMode) {
                        // 如果处于全屏模式，退出全屏
                        if (PlayingSettingsStore.playerIsFullscreen) {
                            LaunchedEffect(Unit) {
                                playerState.placement = WindowPlacement.Floating
                                PlayingSettingsStore.playerIsFullscreen = false
                            }
                        }

                        CompositionLocalProvider(
                            LocalViewModelStoreOwner provides viewModelStoreOwner,
                            LocalContext provides desktopContext, // PIP use main context?
                            LocalPlayerManager provides playerManager,
                            LocalMediaPlayer provides player,
                            LocalWindowState provides mainState, // PIP might not need this, but providing just in case
                            LocalWebViewInitialized provides (webViewInitialized && webViewInitError == null),
                            LocalWebViewRestartRequired provides webViewRestartRequired,
                            LocalWebViewInitError provides webViewInitError
                        ) {
                            PipPlayerWindow(
                                onClose = {
                                    player.stopPlayback()
                                    playerManager.hidePlayer()
                                    playerManager.isPipMode = false
                                },
                                onExitPip = {
                                    playerManager.isPipMode = false
                                }
                            )
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
                            val fnConnectContext = remember(fnConnectWindowState) {
                                val dataDir = logDir.parentFile.resolve("data")
                                    .apply { if (!exists()) mkdirs() }
                                val cacheDir = logDir.parentFile.resolve("cache")
                                    .apply { if (!exists()) mkdirs() }
                                DesktopContext(
                                    fnConnectWindowState,
                                    dataDir,
                                    cacheDir,
                                    logDir,
                                    ExtraWindowProperties()
                                )
                            }

                            CompositionLocalProvider(
                                LocalViewModelStoreOwner provides viewModelStoreOwner,
                                LocalContext provides fnConnectContext,
                                LocalLogExporter provides logExporter,
                                LocalPlayerManager provides remember { PlayerManager() },
                                LocalFrameWindowScope provides this@Window,
                                LocalWindowState provides fnConnectWindowState,
                                LocalWindowHandle provides window.windowHandle,
                                LocalWebViewInitialized provides (webViewInitialized && webViewInitError == null),
                                LocalWebViewRestartRequired provides webViewRestartRequired,
                                LocalWebViewInitError provides webViewInitError
                            ) {
                                var errorDialogDismissed by remember { mutableStateOf(false) }
                                if (webViewInitError != null && !errorDialogDismissed) {
                                    KcefInitErrorDialog(
                                        error = webViewInitError,
                                        onDismiss = { errorDialogDismissed = true }
                                    )
                                }

                                WindowFrame(
                                    onCloseRequest = { fnConnectWindowRequest = null },
                                    icon = icon,
                                    title = "使用 NAS 登录",
                                    state = fnConnectWindowState,
                                    backButtonVisible = false
                                ) { windowInset, contentInset ->
                                    NasLoginWebViewScreen(
                                        initialUrl = request.initialUrl,
                                        fnId = request.fnId,
                                        onBack = { fnConnectWindowRequest = null },
                                        onLoginSuccess = { history ->
                                            val preferencesManager =
                                                PreferencesManager.getInstance()
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
                                        } else null,
                                        windowInset = windowInset,
                                        contentInset = contentInset
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


private fun kcefBaseDir(): File {
    val platform = currentPlatformDesktop()
    return when (platform) {
        is Platform.Linux -> File(System.getProperty("user.home"), ".local/share/fly-narwhal")
        is Platform.MacOS -> File(
            System.getProperty("user.home"),
            "Library/Application Support/fly-narwhal"
        )

        is Platform.Windows -> {
            val exeDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
            File(exeDir, "app/resources")
        }
    }
}

private fun kcefInstallDir(): File {
    return File(kcefBaseDir(), "kcef-bundle-${BuildConfig.VERSION_NAME}")
}

private fun kcefCacheDir(): File {
    return File(kcefBaseDir(), "kcef-cache-${BuildConfig.VERSION_NAME}")
}

private fun cleanupOldKcefDirs(baseDir: File) {
    val currentVersion = BuildConfig.VERSION_NAME
    val keep = setOf(
        "kcef-bundle-$currentVersion",
        "kcef-cache-$currentVersion",
    )

    baseDir.listFiles()?.forEach { file ->
        if (!file.isDirectory) return@forEach
        val name = file.name
        val isKcefDir = name == "kcef-bundle" ||
            name == "kcef-cache" ||
            name.startsWith("kcef-bundle-") ||
            name.startsWith("kcef-cache-")

        if (!isKcefDir) return@forEach
        if (name in keep) return@forEach

        try {
            file.deleteRecursively()
            Logger.withTag("main").i { "Deleted old KCEF directory: $name" }
        } catch (e: Exception) {
            Logger.withTag("main").e(e) { "Failed to delete old KCEF directory: $name" }
        }
    }
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
                File(userHome, ".local/share/fly-narwhal/logs")
            }

            is Platform.MacOS -> {
                val userHome = System.getProperty("user.home")
                File(userHome, "Library/Logs/fly-narwhal")
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
        placement = WindowPlacement.Floating,
        size = DpSize(AppSettingsStore.windowWidth.dp, AppSettingsStore.windowHeight.dp)
    )
    val title = "飞鲸影视"
    val icon = painterResource(Res.drawable.icon)
    return Triple(state, title, icon)
}
