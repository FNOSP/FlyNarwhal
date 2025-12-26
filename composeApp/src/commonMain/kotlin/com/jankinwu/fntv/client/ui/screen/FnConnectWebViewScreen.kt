package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowLeft
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.consumeEach
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.model.request.AuthRequest
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitError
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitialized
import com.jankinwu.fntv.client.ui.providable.LocalWebViewRestartRequired
import com.multiplatform.webview.cookie.Cookie
import com.multiplatform.webview.jsbridge.IJsMessageHandler
import com.multiplatform.webview.jsbridge.JsMessage
import com.multiplatform.webview.jsbridge.rememberWebViewJsBridge
import com.multiplatform.webview.web.LoadingState
import com.multiplatform.webview.web.WebView
import com.multiplatform.webview.web.WebViewNavigator
import com.multiplatform.webview.web.rememberWebViewNavigator
import com.multiplatform.webview.web.rememberWebViewState
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource
import dev.chrisbanes.haze.materials.ExperimentalHazeMaterialsApi
import dev.chrisbanes.haze.materials.FluentMaterials
import dev.chrisbanes.haze.rememberHazeState
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.login_background
import org.jetbrains.compose.resources.painterResource

private val logger = Logger.withTag("FnConnectWebViewScreen")

@OptIn(ExperimentalHazeMaterialsApi::class, ExperimentalMaterial3Api::class)
@Composable
fun FnConnectWebViewScreen(
    initialUrl: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val toastManager = rememberToastManager()
    val hazeState = rememberHazeState()
    val scope = rememberCoroutineScope()
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

    LaunchedEffect(jsBridge) {
        jsBridge.register(NetworkLogHandler { params ->
            messageChannel.trySend(params)
        })
    }

    LaunchedEffect(Unit) {
        var isAuthRequested = false
        messageChannel.consumeEach { params ->
            logger.i("Intercepted: $params")
            try {
                val json = Json.parseToJsonElement(params).jsonObject
                val type = json["type"]?.jsonPrimitive?.contentOrNull
                val url = json["url"]?.jsonPrimitive?.contentOrNull ?: ""

                if (type == "XHR" && url.contains("/sac/rpcproxy/v1/new-user-guide/status")) {
                    val cookie = json["cookie"]?.jsonPrimitive?.contentOrNull
                    if (!cookie.isNullOrBlank()) {
                        AccountDataCache.mergeCookieString(cookie)
                        launch {
                            try {
                                val config = fnOfficialApi.getSysConfig()
                                logger.i("Got sys config: $config")
                                val oauth = config.nasOauth
                                if (oauth.url.isNotBlank() && oauth.url != "://") {
                                    baseUrl = oauth.url
                                }
                                val appId = oauth.appId
                                val redirectUri = "$baseUrl/v/oauth/result"
                                val targetUrl = "$baseUrl/signin?client_id=$appId&redirect_uri=$redirectUri"

                                logger.i("Navigating to OAuth: $targetUrl")
                                val domain = baseUrl.substringAfter("://").substringBefore(":").substringBefore("/")
                                cookie.split(";").forEach {
                                    val parts = it.trim().split("=", limit = 2)
                                    if (parts.size == 2) {
                                        val cookieObj = Cookie(
                                            name = parts[0],
                                            value = parts[1],
                                            domain = domain
                                        )
                                        webViewState.cookieManager.setCookie(baseUrl, cookieObj)
                                    }
                                }
                                navigator.loadUrl(targetUrl)
                            } catch (e: Exception) {
                                logger.e("Failed to get sys config", e)
                                toastManager.showToast("获取系统配置失败: ${e.message}", ToastType.Failed)
                            }
                        }
                    }
                } else if (type == "Response" && url.contains("/oauthapi/authorize")) {
                    if (!isAuthRequested) {
                        val body = json["body"]?.jsonPrimitive?.contentOrNull
                        if (!body.isNullOrBlank()) {
                            try {
                                val bodyJson = Json.parseToJsonElement(body).jsonObject
                                val data = bodyJson["data"]?.jsonObject
                                val code = data?.get("code")?.jsonPrimitive?.contentOrNull
                                if (code != null) {
                                    isAuthRequested = true
                                    launch {
                                        try {
                                            val response = fnOfficialApi.auth(AuthRequest("Trim-NAS", code))
                                            val token = response.token
                                            if (token.isNotBlank()) {
                                                AccountDataCache.authorization = token
                                                AccountDataCache.insertCookie("Trim-MC-token" to token)
                                                logger.i("cookie: ${AccountDataCache.cookieState}")
                                                LoginStateManager.updateLoginStatus(true)
                                                toastManager.showToast("授权成功", ToastType.Success)
                                                onBack()
                                            } else {
                                                isAuthRequested = false
                                                toastManager.showToast("授权失败: Token 为空", ToastType.Failed)
                                            }
                                        } catch (e: Exception) {
                                            isAuthRequested = false
                                            logger.e("OAuth result failed", e)
                                            toastManager.showToast("授权失败: ${e.message}", ToastType.Failed)
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                logger.e("Failed to parse OAuth response", e)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                logger.e("Handler error", e)
            }
        }
    }

    LaunchedEffect(webViewState.lastLoadedUrl) {
        webViewState.lastLoadedUrl?.let { url ->
            if (url.isNotBlank()) {
                addressBarValue = url
                logger.i("Loaded url: $url")
                if (url.contains("/login")) {
                    baseUrl = url.substringBefore("/login")
                    logger.i("Base url: $baseUrl")
                }
//                if (url == baseUrl) {
//                    AccountDataCache.updateFnOfficialBaseUrlFromUrl(url)
////                    AccountDataCache.isLoggedIn = true
//                    try {
//                        val cookies = webViewState.cookieManager.getCookies(url)
//                        val cookieMap = cookies.associate { it.name to it.value }
//                        AccountDataCache.insertCookies(cookieMap)
//                        logger.i("Cookies: $cookies")
//                        val token = cookieMap["Trim-MC-token"] ?: cookieMap["Authorization"]
//                        if (!token.isNullOrBlank()) {
//                            AccountDataCache.authorization = token
//                            logger.i("Token: $token")
//                        }
//                        // LoginStateManager.updateLoginStatus(true)
//                        // onBack()
//                        // toastManager.showToast("登录成功", ToastType.Success)
//                    } catch (e: Exception) {
//                        e.printStackTrace()
//                        toastManager.showToast("获取登录信息失败: ${e.message}", ToastType.Failed)
//                    }
//                }
            }
        }
    }

    // 注入 JS 拦截器以监听 XHR 和 Fetch 请求并打印请求头
    LaunchedEffect(webViewState.loadingState) {
        if (webViewState.loadingState is LoadingState.Finished) {
            val jsScript = """
                (function() {
                    console.log("Injecting Network Interceptor...");
                    
                    function logToNative(type, url, method, headers, body) {
                        if (window.kmpJsBridge) {
                            window.kmpJsBridge.callNative("LogNetwork", JSON.stringify({
                                type: type,
                                url: url,
                                method: method,
                                headers: headers,
                                cookie: document.cookie,
                                body: body
                            }));
                        }
                    }

                    // Hook XMLHttpRequest
                    var originalOpen = XMLHttpRequest.prototype.open;
                    XMLHttpRequest.prototype.open = function(method, url) {
                        this._method = method;
                        this._url = url;
                        this._headers = {};
                        // console.log("[Intercepted XHR] " + method + " " + url);
                        return originalOpen.apply(this, arguments);
                    };
                    
                    var originalSetRequestHeader = XMLHttpRequest.prototype.setRequestHeader;
                    XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
                        this._headers[header] = value;
                        // console.log("[Intercepted XHR Header] " + this._url + " : " + header + " = " + value);
                        return originalSetRequestHeader.apply(this, arguments);
                    };

                    var originalSend = XMLHttpRequest.prototype.send;
                    XMLHttpRequest.prototype.send = function(body) {
                        var self = this;
                        var originalOnReadyStateChange = self.onreadystatechange;
                        self.onreadystatechange = function() {
                            if (self.readyState === 4) {
                                if (self._url && self._url.indexOf("/oauthapi/authorize") !== -1) {
                                    logToNative("Response", self._url, self._method, {}, self.responseText);
                                }
                            }
                            if (originalOnReadyStateChange) {
                                originalOnReadyStateChange.apply(this, arguments);
                            }
                        }
                        
                        logToNative("XHR", this._url, this._method, this._headers, null);
                        return originalSend.apply(this, arguments);
                    };

                    // Hook Fetch
                    var originalFetch = window.fetch;
                    window.fetch = function(input, init) {
                        var url = input;
                        if (typeof input === 'object' && input.url) {
                            url = input.url;
                        }
                        var method = (init && init.method) ? init.method : 'GET';
                        
                        var headers = {};
                        if (init && init.headers) {
                            var h = init.headers;
                            if (h instanceof Headers) {
                                h.forEach(function(value, key) {
                                    headers[key] = value;
                                });
                            } else {
                                for (var key in h) {
                                    if (h.hasOwnProperty(key)) {
                                        headers[key] = h[key];
                                    }
                                }
                            }
                        }
                        
                        logToNative("Fetch", url, method, headers, null);
                        return originalFetch.apply(this, arguments).then(function(response) {
                            if (url && url.indexOf("/oauthapi/authorize") !== -1) {
                                var clone = response.clone();
                                clone.text().then(function(text) {
                                     logToNative("Response", url, method, {}, text);
                                });
                            }
                            return response;
                        });
                    };
                    console.log("Network Interceptor Injected Successfully.");
                })();
            """.trimIndent()
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
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 48.dp, end = 12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
//                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        IconButton(
                            onClick = onBack,
                            modifier = Modifier.pointerHoverIcon(PointerIcon.Hand)
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowLeft,
                                contentDescription = "Back",
                                tint = Colors.TextSecondaryColor
                            )
                        }

                        BasicTextField(
                            value = addressBarValue,
                            onValueChange = { addressBarValue = it },
                            modifier = Modifier
                                .height(30.dp)
                                .weight(1f),
                            singleLine = true,
                            textStyle = LocalTextStyle.current.copy(
                                fontSize = 14.sp,
                                color = Colors.TextSecondaryColor
                            ),
                            cursorBrush = SolidColor(Colors.AccentColorDefault),
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Uri,
                                imeAction = ImeAction.Go
                            ),
                            keyboardActions = KeyboardActions(
                                onGo = {
                                    val target = normalizeFnConnectUrl(addressBarValue)
                                    if (target.isNotBlank()) {
                                        currentUrl = target
                                        addressBarValue = target
                                    } else {
                                        toastManager.showToast("请输入有效地址", ToastType.Info)
                                    }
                                }
                            ),
                            decorationBox = { innerTextField ->
                                OutlinedTextFieldDefaults.DecorationBox(
                                    value = addressBarValue,
                                    innerTextField = innerTextField,
                                    enabled = true,
                                    singleLine = true,
                                    visualTransformation = VisualTransformation.None,
                                    interactionSource = remember { MutableInteractionSource() },
                                    placeholder = {
                                        Text(
                                            "请输入地址",
                                            fontSize = 14.sp,
                                            color = Color.White.copy(alpha = 0.6f)
                                        )
                                    },
                                    colors = getTextFieldColors(),
                                    container = {
                                        OutlinedTextFieldDefaults.ContainerBox(
                                            enabled = true,
                                            isError = false,
                                            interactionSource = remember { MutableInteractionSource() },
                                            colors = getTextFieldColors(),
                                            shape = RoundedCornerShape(8.dp),
                                            focusedBorderThickness = 1.dp,
                                            unfocusedBorderThickness = 1.dp
                                        )
                                    },
                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp)
                                )
                            }
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White)
                    ) {
                        when {
                            webViewInitialized -> {
                                WebView(
                                    state = webViewState,
                                    modifier = Modifier.fillMaxSize(),
                                    navigator = navigator,
                                    webViewJsBridge = jsBridge
                                )
                            }

                            webViewRestartRequired -> {
                                Text(
                                    text = "WebView 初始化完成，但需要重启应用后生效。",
                                    color = Color.Black,
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }

                            webViewInitError != null -> {
                                Text(
                                    text = "WebView 初始化失败：${webViewInitError.message ?: "未知错误"}",
                                    color = Color.Black,
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }

                            else -> {
                                Text(
                                    text = "WebView 初始化中，请稍候…",
                                    color = Color.Black,
                                    modifier = Modifier.align(Alignment.Center)
                                )
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
}

@Composable
private fun getTextFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = Colors.AccentColorDefault,
    unfocusedBorderColor = Color.White.copy(alpha = 0.35f),
    focusedLabelColor = Colors.AccentColorDefault,
    unfocusedLabelColor = Color.White.copy(alpha = 0.6f),
    cursorColor = Colors.AccentColorDefault,
    focusedTextColor = Colors.TextSecondaryColor,
    unfocusedTextColor = Colors.TextSecondaryColor
)

internal fun normalizeFnConnectUrl(value: String): String {
    // Normalize FN Connect host and ensure HTTPS is always used.
    val trimmed = value.trim()
    if (trimmed.isBlank()) return ""

    if (trimmed.startsWith("https://") || trimmed.startsWith("http://")) {
        return trimmed
    }

    val host = trimmed.substringBefore("/")
    val path = trimmed.removePrefix(host)
    val normalizedHost = if (host.contains('.')) host else "$host.5ddd.com"
    return "https://$normalizedHost$path"
}

class NetworkLogHandler(private val onMessage: (String) -> Unit) : IJsMessageHandler {
    override fun methodName(): String = "LogNetwork"

    override fun handle(message: JsMessage, navigator: WebViewNavigator?, callback: (String) -> Unit) {
        onMessage(message.params)
        callback("OK")
    }
}

