package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.currentPlatform
import com.jankinwu.fntv.client.isMacOS
import com.jankinwu.fntv.client.data.model.LoginHistory
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.manager.PreferencesManager
import com.jankinwu.fntv.client.processor.NetworkMessageProcessor
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.component.login.NasLoginAddressBar
import com.jankinwu.fntv.client.ui.component.login.NasLoginWebViewContainer
import com.jankinwu.fntv.client.ui.providable.LocalRefreshState
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitError
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitialized
import com.jankinwu.fntv.client.ui.providable.LocalWebViewRestartRequired
import com.jankinwu.fntv.client.utils.CaptureLoginInfoHandler
import com.jankinwu.fntv.client.utils.NetworkLogHandler
import com.jankinwu.fntv.client.utils.getJsInjectionScript
import com.jankinwu.fntv.client.viewmodel.NasAuthViewModel
import com.saralapps.composemultiplatformwebview.PlatformWebView
import com.saralapps.composemultiplatformwebview.rememberPlatformWebViewState
import com.multiplatform.webview.jsbridge.rememberWebViewJsBridge
import com.multiplatform.webview.web.LoadingState
import com.multiplatform.webview.web.rememberWebViewNavigator
import com.multiplatform.webview.web.rememberWebViewState
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource
import dev.chrisbanes.haze.materials.ExperimentalHazeMaterialsApi
import dev.chrisbanes.haze.materials.FluentMaterials
import dev.chrisbanes.haze.rememberHazeState
import flynarwhal.composeapp.generated.resources.Res
import flynarwhal.composeapp.generated.resources.login_background
import io.ktor.http.decodeURLQueryComponent
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.consumeEach
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.viewmodel.koinViewModel

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
    onBaseUrlDetected: ((String) -> Unit)? = null,
    windowInset: WindowInsets = WindowInsets(0),
    contentInset: WindowInsets = WindowInsets(0)
) {
    val toastManager = rememberToastManager()
    val hazeState = rememberHazeState()
    val nasAuthViewModel: NasAuthViewModel = koinViewModel()
    val refreshState = LocalRefreshState.current
    val isMacPlatform = remember {
        runCatching { currentPlatform().isMacOS() }.getOrNull() == true
    }
    val captionSideInset = remember(contentInset) {
        contentInset.only(WindowInsetsSides.Horizontal)
    }

    var baseUrl by remember { mutableStateOf("") }
    var addressBarValue by remember(initialUrl) { mutableStateOf(initialUrl) }
    val messageChannel = remember { Channel<String>(Channel.UNLIMITED) }
    
    var capturedUsername by remember { mutableStateOf("") }
    var capturedPassword by remember { mutableStateOf("") }
    var capturedRememberPassword by remember { mutableStateOf(false) }

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
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (isMacPlatform) {
                            Modifier
                        } else {
                            Modifier.hazeEffect(
                                state = hazeState,
                                style = FluentMaterials.acrylicDefault(true)
                            )
                        }
                    )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .windowInsetsPadding(windowInset)
                ) {
                    Box(modifier = Modifier.windowInsetsPadding(captionSideInset)) {
                        NasLoginAddressBar(
                            addressBarValue = addressBarValue,
                            onAddressBarValueChange = { addressBarValue = it },
                            onBack = onBack
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    if (isMacPlatform) {
                        MacNasLoginWebViewContent(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxSize()
                                .padding(horizontal = 16.dp),
                            initialUrl = initialUrl,
                            fnId = fnId,
                            refreshState = refreshState,
                            toastManager = toastManager,
                            nasAuthViewModel = nasAuthViewModel,
                            messageChannel = messageChannel,
                            onLoginSuccess = onLoginSuccess,
                            allowAutoLogin = allowAutoLogin,
                            autoLoginUsername = autoLoginUsername,
                            autoLoginPassword = autoLoginPassword,
                            onBaseUrlDetected = onBaseUrlDetected,
                            onAddressBarUrlChange = { addressBarValue = it },
                            onBaseUrlChange = { baseUrl = it },
                            getBaseUrl = { baseUrl },
                            getCapturedUsername = { capturedUsername },
                            getCapturedPassword = { capturedPassword },
                            getCapturedRememberPassword = { capturedRememberPassword },
                            setCapturedUsername = { capturedUsername = it },
                            setCapturedPassword = { capturedPassword = it },
                            setCapturedRememberPassword = { capturedRememberPassword = it }
                        )
                    } else {
                        KcefNasLoginWebViewContent(
                            modifier = Modifier.weight(1f),
                            initialUrl = initialUrl,
                            fnId = fnId,
                            refreshState = refreshState,
                            toastManager = toastManager,
                            nasAuthViewModel = nasAuthViewModel,
                            messageChannel = messageChannel,
                            onLoginSuccess = onLoginSuccess,
                            allowAutoLogin = allowAutoLogin,
                            autoLoginUsername = autoLoginUsername,
                            autoLoginPassword = autoLoginPassword,
                            onBaseUrlDetected = onBaseUrlDetected,
                            onAddressBarUrlChange = { addressBarValue = it },
                            onBaseUrlChange = { baseUrl = it },
                            getBaseUrl = { baseUrl },
                            getCapturedUsername = { capturedUsername },
                            getCapturedPassword = { capturedPassword },
                            getCapturedRememberPassword = { capturedRememberPassword },
                            setCapturedUsername = { capturedUsername = it },
                            setCapturedPassword = { capturedPassword = it },
                            setCapturedRememberPassword = { capturedRememberPassword = it }
                        )
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

internal fun normalizeFnConnectUrl(value: String, isHttps: Boolean): String {
    // Normalize FN Connect host and ensure HTTPS is always used.
    val trimmed = value.trim()
    if (trimmed.isBlank()) return ""

    if (trimmed.startsWith("https://") || trimmed.startsWith("http://")) {
        return trimmed
    }

    val host = trimmed.substringBefore("/")
    val path = trimmed.removePrefix(host)
    val normalizedHost = if (host.contains('.')) host else "5ddd.com/$host"
    val protocolPrefix = if (normalizedHost.contains("5ddd.com") || normalizedHost.contains("fnos.net")) {
        "https://"
    } else {
        if (isHttps) "https://" else "http://"
    }
    return "$protocolPrefix$normalizedHost$path"
}

private fun parseFnBridgeUrl(url: String): Pair<String, String>? {
    val query = when {
        url.startsWith("flynarwhal://bridge") -> url.substringAfter("?", "")
        url.contains("#flynarwhal_bridge?") -> url.substringAfter("#flynarwhal_bridge?", "")
        else -> return null
    }
    if (query.isBlank()) return null

    val params = query.split("&")
        .mapNotNull { part ->
            val idx = part.indexOf("=")
            if (idx <= 0) return@mapNotNull null
            val key = runCatching { part.substring(0, idx).decodeURLQueryComponent() }.getOrNull() ?: return@mapNotNull null
            val value = runCatching { part.substring(idx + 1).decodeURLQueryComponent() }.getOrNull() ?: ""
            key to value
        }
        .toMap()

    val method = params["method"] ?: return null
    return method to (params["params"] ?: "")
}

private fun buildMacWebViewInjectionScript(
    autoLoginUsername: String?,
    autoLoginPassword: String?,
    allowAutoLogin: Boolean,
    usernameHistoryJs: String
): String {
    val shim = """
        (function() {
            if (!window.kmpJsBridge) window.kmpJsBridge = {};
            window.kmpJsBridge.callNative = function(method, params) {
                try {
                    window.location.hash = 'flynarwhal_bridge?method=' + encodeURIComponent(method) + '&params=' + encodeURIComponent(params || '');
                    setTimeout(function() {
                        try {
                            if (window.location.hash && window.location.hash.indexOf('#flynarwhal_bridge') === 0) {
                                history.replaceState(null, '', window.location.pathname + window.location.search);
                            }
                        } catch (e) {}
                    }, 0);
                } catch (e) {}
            };
        })();
    """.trimIndent()
    return shim + "\n" + getJsInjectionScript(
        autoLoginUsername = autoLoginUsername,
        autoLoginPassword = autoLoginPassword,
        allowAutoLogin = allowAutoLogin,
        usernameHistoryJs = usernameHistoryJs
    )
}

private fun buildJsCookie(name: String, value: String, domain: String?): String {
    val cookie = buildString {
        append(name)
        append("=")
        append(value)
        append("; path=/")
        if (!domain.isNullOrBlank()) {
            append("; domain=")
            append(domain)
        }
    }
    return cookie
        .replace("\\", "\\\\")
        .replace("\"", "\\\"")
}

@Composable
private fun MacNasLoginWebViewContent(
    modifier: Modifier,
    initialUrl: String,
    fnId: String,
    refreshState: com.jankinwu.fntv.client.RefreshState,
    toastManager: com.jankinwu.fntv.client.ui.component.common.ToastManager,
    nasAuthViewModel: NasAuthViewModel,
    messageChannel: Channel<String>,
    onLoginSuccess: (LoginHistory) -> Unit,
    allowAutoLogin: Boolean,
    autoLoginUsername: String?,
    autoLoginPassword: String?,
    onBaseUrlDetected: ((String) -> Unit)?,
    onAddressBarUrlChange: (String) -> Unit,
    onBaseUrlChange: (String) -> Unit,
    getBaseUrl: () -> String,
    getCapturedUsername: () -> String,
    getCapturedPassword: () -> String,
    getCapturedRememberPassword: () -> Boolean,
    setCapturedUsername: (String) -> Unit,
    setCapturedPassword: (String) -> Unit,
    setCapturedRememberPassword: (Boolean) -> Unit,
) {
    val cookieScope = rememberCoroutineScope()
    val platformWebViewState = rememberPlatformWebViewState(
        url = initialUrl,
        javaScriptEnabled = true,
        allowsFileAccess = true,
        onNavigating = { url ->
            val bridge = parseFnBridgeUrl(url) ?: return@rememberPlatformWebViewState true
            val (method, params) = bridge
            when (method) {
                "LogNetwork" -> {
                    messageChannel.trySend(params)
                }

                "CaptureLoginInfo" -> {
                    runCatching {
                        val json = Json.parseToJsonElement(params).jsonObject
                        val username = json["username"]?.jsonPrimitive?.contentOrNull ?: ""
                        val password = json["password"]?.jsonPrimitive?.contentOrNull ?: ""
                        val rememberPassword =
                            json["rememberPassword"]?.jsonPrimitive?.booleanOrNull ?: false
                        setCapturedUsername(username)
                        setCapturedPassword(password)
                        setCapturedRememberPassword(rememberPassword)
                    }
                }
            }
            !url.startsWith("flynarwhal://bridge")
        }
    )

    val networkMessageProcessor = remember {
        NetworkMessageProcessor(
            nasAuthViewModel = nasAuthViewModel,
            toastManager = toastManager,
            setCookie = { _, cookie ->
                cookieScope.launch {
                    val cookieString = buildJsCookie(cookie.name, cookie.value, cookie.domain)
                    platformWebViewState.evaluateJavaScript("document.cookie=\"$cookieString\";")
                }
            },
            loadUrl = { url -> platformWebViewState.loadUrl(url) },
            onLoginSuccess = onLoginSuccess,
            fnId = fnId,
            autoLoginUsername = autoLoginUsername,
            preferWebViewSysConfig = true
        )
    }

    LaunchedEffect(Unit) {
        messageChannel.consumeEach { params ->
            networkMessageProcessor.process(
                params = params,
                baseUrl = getBaseUrl(),
                onBaseUrlChange = onBaseUrlChange,
                capturedUsername = getCapturedUsername(),
                capturedPassword = getCapturedPassword(),
                capturedRememberPassword = getCapturedRememberPassword()
            )
        }
    }

    LaunchedEffect(refreshState.refreshKey) {
        if (refreshState.refreshKey.isNotEmpty()) {
            refreshState.onRefresh()
            platformWebViewState.reload()
        }
    }

    LaunchedEffect(platformWebViewState.isLoading, platformWebViewState.currentUrl) {
        if (!platformWebViewState.isLoading) {
            val usernameHistoryJs = PreferencesManager.getInstance()
                .loadLoginUsernameHistory()
                .joinToString(prefix = "[", postfix = "]") { username ->
                    "\"" + username.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
                }
            val jsScript = buildMacWebViewInjectionScript(
                autoLoginUsername = autoLoginUsername,
                autoLoginPassword = autoLoginPassword,
                allowAutoLogin = allowAutoLogin,
                usernameHistoryJs = usernameHistoryJs
            )
            platformWebViewState.evaluateJavaScript(jsScript)
        }
    }

    Box(modifier = modifier) {
        PlatformWebView(
            state = platformWebViewState,
            modifier = Modifier.fillMaxSize(),
            placeholderColor = Color.White,
            onUrlChanged = { url ->
                val bridge = parseFnBridgeUrl(url)
                if (bridge != null) {
                    val (method, params) = bridge
                    when (method) {
                        "LogNetwork" -> {
                            messageChannel.trySend(params)
                        }

                        "CaptureLoginInfo" -> {
                            runCatching {
                                val json = Json.parseToJsonElement(params).jsonObject
                                val username = json["username"]?.jsonPrimitive?.contentOrNull ?: ""
                                val password = json["password"]?.jsonPrimitive?.contentOrNull ?: ""
                                val rememberPassword =
                                    json["rememberPassword"]?.jsonPrimitive?.booleanOrNull ?: false
                                setCapturedUsername(username)
                                setCapturedPassword(password)
                                setCapturedRememberPassword(rememberPassword)
                            }
                        }
                    }
                    cookieScope.launch {
                        platformWebViewState.evaluateJavaScript(
                            "try{history.replaceState(null,'',window.location.pathname+window.location.search)}catch(e){}"
                        )
                    }
                    return@PlatformWebView
                }
                onAddressBarUrlChange(url)
                if (url.contains("/login")) {
                    val baseUrl = url.substringBefore("/login")
                    onBaseUrlChange(baseUrl)
                    AccountDataCache.updateFnOfficialBaseUrlFromUrl(baseUrl)
                    onBaseUrlDetected?.invoke(baseUrl)
                }
            }
        )
    }
}

@Composable
private fun KcefNasLoginWebViewContent(
    modifier: Modifier,
    initialUrl: String,
    fnId: String,
    refreshState: com.jankinwu.fntv.client.RefreshState,
    toastManager: com.jankinwu.fntv.client.ui.component.common.ToastManager,
    nasAuthViewModel: NasAuthViewModel,
    messageChannel: Channel<String>,
    onLoginSuccess: (LoginHistory) -> Unit,
    allowAutoLogin: Boolean,
    autoLoginUsername: String?,
    autoLoginPassword: String?,
    onBaseUrlDetected: ((String) -> Unit)?,
    onAddressBarUrlChange: (String) -> Unit,
    onBaseUrlChange: (String) -> Unit,
    getBaseUrl: () -> String,
    getCapturedUsername: () -> String,
    getCapturedPassword: () -> String,
    getCapturedRememberPassword: () -> Boolean,
    setCapturedUsername: (String) -> Unit,
    setCapturedPassword: (String) -> Unit,
    setCapturedRememberPassword: (Boolean) -> Unit,
) {
    val webViewInitialized = LocalWebViewInitialized.current
    val webViewRestartRequired = LocalWebViewRestartRequired.current
    val webViewInitError = LocalWebViewInitError.current
    var currentUrl by remember(initialUrl) { mutableStateOf(initialUrl) }
    val webViewState = rememberWebViewState(currentUrl)
    val navigator = rememberWebViewNavigator()
    val jsBridge = rememberWebViewJsBridge(navigator)
    val cookieScope = rememberCoroutineScope()

    LaunchedEffect(jsBridge) {
        jsBridge.register(NetworkLogHandler { params ->
            messageChannel.trySend(params)
        })
        jsBridge.register(CaptureLoginInfoHandler { username, password, rememberPassword ->
            setCapturedUsername(username)
            setCapturedPassword(password)
            setCapturedRememberPassword(rememberPassword)
        })
    }

    val networkMessageProcessor = remember {
        NetworkMessageProcessor(
            nasAuthViewModel = nasAuthViewModel,
            toastManager = toastManager,
            setCookie = { url, cookie ->
                cookieScope.launch {
                    webViewState.cookieManager.setCookie(url, cookie)
                }
            },
            loadUrl = { url -> navigator.loadUrl(url) },
            onLoginSuccess = onLoginSuccess,
            fnId = fnId,
            autoLoginUsername = autoLoginUsername
        )
    }

    LaunchedEffect(Unit) {
        messageChannel.consumeEach { params ->
            networkMessageProcessor.process(
                params = params,
                baseUrl = getBaseUrl(),
                onBaseUrlChange = onBaseUrlChange,
                capturedUsername = getCapturedUsername(),
                capturedPassword = getCapturedPassword(),
                capturedRememberPassword = getCapturedRememberPassword()
            )
        }
    }

    LaunchedEffect(refreshState.refreshKey) {
        if (refreshState.refreshKey.isNotEmpty()) {
            refreshState.onRefresh()
            navigator.reload()
        }
    }

    LaunchedEffect(webViewState.lastLoadedUrl) {
        webViewState.lastLoadedUrl?.let { url ->
            if (url.isNotBlank()) {
                onAddressBarUrlChange(url)
                if (url.contains("/login")) {
                    val baseUrl = url.substringBefore("/login")
                    onBaseUrlChange(baseUrl)
                    AccountDataCache.updateFnOfficialBaseUrlFromUrl(baseUrl)
                    onBaseUrlDetected?.invoke(baseUrl)
                }
            }
        }
    }

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

    NasLoginWebViewContainer(
        modifier = modifier,
        webViewInitialized = webViewInitialized,
        webViewRestartRequired = webViewRestartRequired,
        webViewInitError = webViewInitError,
        webViewState = webViewState,
        navigator = navigator,
        jsBridge = jsBridge
    )
}
