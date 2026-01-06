package com.jankinwu.fntv.client.processor

import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.LoginHistory
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.manager.PreferencesManager
import com.jankinwu.fntv.client.ui.component.common.ToastManager
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.viewmodel.NasAuthViewModel
import com.multiplatform.webview.cookie.Cookie
import com.multiplatform.webview.web.WebViewNavigator
import com.multiplatform.webview.web.WebViewState
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class NetworkMessageProcessor(
    private val nasAuthViewModel: NasAuthViewModel,
    private val toastManager: ToastManager,
    private val webViewState: WebViewState,
    private val navigator: WebViewNavigator,
    private val onLoginSuccess: (LoginHistory) -> Unit,
    private val fnId: String,
    private val autoLoginUsername: String?
) {
    private val logger = Logger.withTag("NetworkMessageProcessor")
    private var isAuthRequested = false
    private var isSysConfigInFlight = false
    private var isSysConfigLoaded = false

    suspend fun process(
        params: String,
        baseUrl: String,
        onBaseUrlChange: (String) -> Unit,
        capturedUsername: String,
        capturedPassword: String,
        capturedRememberPassword: Boolean
    ) {
        logger.i("Intercepted: $params")
        try {
            val json = Json.parseToJsonElement(params).jsonObject
            val type = json["type"]?.jsonPrimitive?.contentOrNull
            val url = json["url"]?.jsonPrimitive?.contentOrNull ?: ""

            if (type == "XHR" && url.contains("/sac/rpcproxy/v1/new-user-guide/status")) {
                handleXhrMessage(json, baseUrl, onBaseUrlChange)
            } else if (type == "Response" && url.contains("/oauthapi/authorize")) {
                handleResponseMessage(json, baseUrl, capturedUsername, capturedPassword, capturedRememberPassword)
            }
        } catch (e: Exception) {
            logger.e("Handler error", e)
        }
    }

    private suspend fun handleXhrMessage(
        json: JsonObject,
        baseUrl: String,
        onBaseUrlChange: (String) -> Unit
    ) {
        val cookie = json["cookie"]?.jsonPrimitive?.contentOrNull
        logger.i("fnos cookie: $cookie")
        if (!cookie.isNullOrBlank()) {
            AccountDataCache.mergeCookieString(cookie)
            if (baseUrl.contains("5ddd.com") || baseUrl.contains("fnos.net")) {
                // 使用 FN Connect 外网访问必加此 Cookie 不然访问不了
                AccountDataCache.insertCookie("mode" to "relay")
            }
            if (!isSysConfigLoaded && !isSysConfigInFlight) {
                isSysConfigInFlight = true
                try {
                    val config = nasAuthViewModel.getSysConfigAndReturn()
                    logger.i("Got sys config: $config")
                    val oauth = config.nasOauth
                    var currentBaseUrl = baseUrl
                    if (oauth.url.isNotBlank() && oauth.url != "://") {
                        currentBaseUrl = oauth.url
                        onBaseUrlChange(currentBaseUrl)
                    }
                    val appId = oauth.appId
                    val redirectUri = "$currentBaseUrl/v/oauth/result"
                    val targetUrl = "$currentBaseUrl/signin?client_id=$appId&redirect_uri=$redirectUri"

                    logger.i("Navigating to OAuth: $targetUrl")
                    val domain = currentBaseUrl.substringAfter("://").substringBefore(":").substringBefore("/")
                    cookie.split(";").forEach {
                        val parts = it.trim().split("=", limit = 2)
                        if (parts.size == 2) {
                            val cookieObj = Cookie(
                                name = parts[0],
                                value = parts[1],
                                domain = domain
                            )
                            webViewState.cookieManager.setCookie(currentBaseUrl, cookieObj)
                        }
                    }
                    isSysConfigLoaded = true
                    navigator.loadUrl(targetUrl)
                } catch (e: Exception) {
                    isSysConfigInFlight = false
                    logger.e("Failed to get sys config", e)
                    toastManager.showToast("获取系统配置失败: ${e.message}", ToastType.Failed)
                }
            }
        }
    }

    private suspend fun handleResponseMessage(
        json: JsonObject,
        baseUrl: String,
        capturedUsername: String,
        capturedPassword: String,
        capturedRememberPassword: Boolean
    ) {
        if (!isAuthRequested) {
            val body = json["body"]?.jsonPrimitive?.contentOrNull
            if (!body.isNullOrBlank()) {
                try {
                    val bodyJson = Json.parseToJsonElement(body).jsonObject
                    val data = bodyJson["data"]?.jsonObject
                    val code = data?.get("code")?.jsonPrimitive?.contentOrNull
                    if (code != null) {
                        isAuthRequested = true
                        try {
                            val response = nasAuthViewModel.authAndReturn(code)
                            val token = response.token
                            if (token.isNotBlank()) {
                                AccountDataCache.authorization = token
                                AccountDataCache.insertCookie("Trim-MC-token" to token)
                                logger.i("cookie: ${AccountDataCache.cookieState}")
                                LoginStateManager.updateLoginStatus(true)
                                toastManager.showToast("登录成功", ToastType.Success)

                                val normalizedUsername = capturedUsername.trim()
                                    .ifBlank { autoLoginUsername?.trim().orEmpty() }
                                if (normalizedUsername.isNotBlank()) {
                                    PreferencesManager.getInstance().addLoginUsernameHistory(normalizedUsername)
                                }
                                val shouldRemember = capturedRememberPassword && capturedPassword.isNotBlank()
                                logger.i("Remember password: $capturedRememberPassword")
                                val history = LoginHistory(
                                    host = "",
                                    port = 0,
                                    username = normalizedUsername,
                                    password = if (shouldRemember) capturedPassword else null,
                                    isHttps = baseUrl.startsWith("https"),
                                    rememberPassword = shouldRemember,
                                    isNasLogin = true,
                                    fnConnectUrl = baseUrl,
                                    fnId = fnId.trim()
                                )
                                onLoginSuccess(history)
                            } else {
                                isAuthRequested = false
                                toastManager.showToast("登录失败: Token 为空", ToastType.Failed)
                            }
                        } catch (e: Exception) {
                            isAuthRequested = false
                            logger.e("OAuth result failed", e)
                            toastManager.showToast("登录失败: ${e.message}", ToastType.Failed)
                        }
                    }
                } catch (e: Exception) {
                    logger.e("Failed to parse OAuth response", e)
                }
            }
        }
    }
}