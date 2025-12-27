package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.LoginHistory
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.manager.PreferencesManager
import com.jankinwu.fntv.client.processor.NetworkMessageProcessor
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.component.login.NasLoginAddressBar
import com.jankinwu.fntv.client.ui.component.login.FnConnectWebViewContainer
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitError
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitialized
import com.jankinwu.fntv.client.ui.providable.LocalWebViewRestartRequired
import com.jankinwu.fntv.client.utils.CaptureLoginInfoHandler
import com.jankinwu.fntv.client.utils.NetworkLogHandler
import com.jankinwu.fntv.client.utils.getJsInjectionScript
import com.multiplatform.webview.jsbridge.rememberWebViewJsBridge
import com.multiplatform.webview.web.LoadingState
import com.multiplatform.webview.web.rememberWebViewNavigator
import com.multiplatform.webview.web.rememberWebViewState
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource
import dev.chrisbanes.haze.materials.ExperimentalHazeMaterialsApi
import dev.chrisbanes.haze.materials.FluentMaterials
import dev.chrisbanes.haze.rememberHazeState
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.login_background
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.consumeEach
import org.jetbrains.compose.resources.painterResource

private val logger = Logger.withTag("FnConnectWebViewScreen")

@OptIn(ExperimentalHazeMaterialsApi::class, ExperimentalMaterial3Api::class)
@Composable
fun NasLoginWebViewScreen(
    modifier: Modifier = Modifier,
    initialUrl: String,
    fnId: String,
    onBack: () -> Unit,
    onLoginSuccess: (LoginHistory) -> Unit,
    autoLoginUsername: String? = null,
    autoLoginPassword: String? = null,
    allowAutoLogin: Boolean = false,
    onBaseUrlDetected: ((String) -> Unit)? = null
) {
    val toastManager = rememberToastManager()
    val hazeState = rememberHazeState()
    val fnOfficialApi = remember { FnOfficialApiImpl() }

    val webViewInitialized = LocalWebViewInitialized.current
    val webViewRestartRequired = LocalWebViewRestartRequired.current
    val webViewInitError = LocalWebViewInitError.current
    var baseUrl by remember { mutableStateOf("") }
    var addressBarValue by remember(initialUrl) { mutableStateOf(initialUrl) }
    var currentUrl by remember(initialUrl) { mutableStateOf(initialUrl) }
    val webViewState = rememberWebViewState(currentUrl)
    val navigator = rememberWebViewNavigator()
    val jsBridge = rememberWebViewJsBridge(navigator)
    val messageChannel = remember { Channel<String>(Channel.UNLIMITED) }
    
    var capturedUsername by remember { mutableStateOf("") }
    var capturedPassword by remember { mutableStateOf("") }
    var capturedRememberPassword by remember { mutableStateOf(false) }

    LaunchedEffect(jsBridge) {
        jsBridge.register(NetworkLogHandler { params ->
            messageChannel.trySend(params)
        })
        jsBridge.register(CaptureLoginInfoHandler { username, password, rememberPassword ->
            capturedUsername = username
            capturedPassword = password
            capturedRememberPassword = rememberPassword
            logger.i("Captured login info: user=$username, remember=$rememberPassword")
        })
    }

    val networkMessageProcessor = remember {
        NetworkMessageProcessor(
            fnOfficialApi = fnOfficialApi,
            toastManager = toastManager,
            webViewState = webViewState,
            navigator = navigator,
            onLoginSuccess = onLoginSuccess,
            fnId = fnId,
            autoLoginUsername = autoLoginUsername
        )
    }

    LaunchedEffect(Unit) {
        messageChannel.consumeEach { params ->
            networkMessageProcessor.process(
                params = params,
                baseUrl = baseUrl,
                onBaseUrlChange = { baseUrl = it },
                capturedUsername = capturedUsername,
                capturedPassword = capturedPassword,
                capturedRememberPassword = capturedRememberPassword
            )
        }
    }

    LaunchedEffect(webViewState.lastLoadedUrl) {
        webViewState.lastLoadedUrl?.let { url ->
            if (url.isNotBlank()) {
                addressBarValue = url
                logger.i("Loaded url: $url")
                if (url.contains("/login")) {
                    baseUrl = url.substringBefore("/login")
                    AccountDataCache.updateFnOfficialBaseUrlFromUrl(baseUrl)
                    logger.i("Base url: $baseUrl")
                    if (onBaseUrlDetected != null) {
                        onBaseUrlDetected(baseUrl)
                        return@LaunchedEffect
                    }
                }
            }
        }
    }

    // 注入 JS 拦截器以监听 XHR 和 Fetch 请求并打印请求头
    LaunchedEffect(webViewState.loadingState) {
        if (webViewState.loadingState is LoadingState.Finished) {
            val usernameHistoryJs = PreferencesManager.getInstance()
                .loadLoginUsernameHistory()
                .joinToString(prefix = "[", postfix = "]") { username ->
                    "\"" + username.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
                }
            val jsScript = getJsInjectionScript(
                autoLoginUsername = autoLoginUsername,
                autoLoginPassword = autoLoginPassword,
                allowAutoLogin = allowAutoLogin,
                usernameHistoryJs = usernameHistoryJs
            )
            navigator.evaluateJavaScript(jsScript)
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        Image(
            painterResource(Res.drawable.login_background),
            contentDescription = "Login background",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .hazeSource(state = hazeState)
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF14171A).copy(alpha = 0.6f)),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                color = Color.Transparent,
                shape = RoundedCornerShape(0.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .hazeEffect(
                        state = hazeState,
                        style = FluentMaterials.acrylicDefault(true)
                    )
            ) {
                // Window Draggable Area
//                draggableArea {
//                    Box(
//                        modifier = Modifier
//                            .fillMaxWidth()
//                            .height(48.dp)
//                            .align(Alignment.TopCenter)
//                    )
//                }
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 12.dp)
                ) {
                    NasLoginAddressBar(
                        addressBarValue = addressBarValue,
                        onAddressBarValueChange = { addressBarValue = it },
                        onBack = onBack
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    FnConnectWebViewContainer(
                        modifier = Modifier.weight(1f),
                        webViewInitialized = webViewInitialized,
                        webViewRestartRequired = webViewRestartRequired,
                        webViewInitError = webViewInitError,
                        webViewState = webViewState,
                        navigator = navigator,
                        jsBridge = jsBridge
                    )
                }
            }
        }

        ToastHost(
            toastManager = toastManager,
            modifier = Modifier.fillMaxSize()
        )
    }
}

internal fun normalizeFnConnectUrl(value: String, isHttps: Boolean): String {
    // Normalize FN Connect host and ensure HTTPS is always used.
    val trimmed = value.trim()
    if (trimmed.isBlank()) return ""

    if (trimmed.startsWith("https://") || trimmed.startsWith("http://")) {
        return trimmed
    }

    val host = trimmed.substringBefore("/")
    val path = trimmed.removePrefix(host)
    val normalizedHost = if (host.contains('.')) host else "$host.5ddd.com"
    val protocolPrefix = if (normalizedHost.contains("5ddd.com")) {
        "https://"
    } else {
        if (isHttps) "https://" else "http://"
    }
    return "$protocolPrefix$normalizedHost$path"
}
