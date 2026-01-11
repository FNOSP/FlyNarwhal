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
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class NetworkMessageProcessor(
    private val nasAuthViewModel: NasAuthViewModel,
    private val toastManager: ToastManager,
    private val setCookie: (String, Cookie) -> Unit,
    private val loadUrl: (String) -> Unit,
    private val onLoginSuccess: (LoginHistory) -> Unit,
    private val fnId: String,
    private val autoLoginUsername: String?,
    private val preferWebViewSysConfig: Boolean = false
) {
    private val logger = Logger.withTag("NetworkMessageProcessor")
    private var isAuthRequested = false
    private var isSysConfigInFlight = false
    private var isSysConfigLoaded = false
    
    private fun extractCookieValue(json: JsonObject): String? {
        val directCookie = json["cookie"]?.jsonPrimitive?.contentOrNull
        if (!directCookie.isNullOrBlank()) return directCookie
        
        val headers = json["headers"]?.jsonObject ?: return null
        headers.entries.firstOrNull { (key, _) -> key.equals("cookie", ignoreCase = true) }
            ?.value
            ?.jsonPrimitive
            ?.contentOrNull
            ?.let { cookieValue ->
                if (cookieValue.isNotBlank()) return cookieValue
            }
        
        return null
    }

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
            } else if (type == "SysConfig") {
                handleSysConfigMessage(json, baseUrl, onBaseUrlChange)
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
        val cookie = extractCookieValue(json)
        logger.i("fnos cookie: $cookie")
        if (!cookie.isNullOrBlank()) {
            AccountDataCache.mergeCookieString(cookie)
            if (baseUrl.contains("5ddd.com") || baseUrl.contains("fnos.net")) {
                // 使用 FN Connect 外网访问必加此 Cookie 不然访问不了
                AccountDataCache.insertCookie("mode" to "relay")
            }
            if (preferWebViewSysConfig) {
                if (!isSysConfigLoaded && !isSysConfigInFlight) {
                    isSysConfigInFlight = true
                }
                return
            }
            if (!isSysConfigLoaded && !isSysConfigInFlight) {
                isSysConfigInFlight = true
                try {
                    val config = nasAuthViewModel.getSysConfigAndReturn()
                    if (isSysConfigLoaded) return
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
                            setCookie(currentBaseUrl, cookieObj)
                        }
                    }
                    isSysConfigLoaded = true
                    loadUrl(targetUrl)
                } catch (e: Exception) {
                    isSysConfigInFlight = false
                    logger.e("Failed to get sys config", e)
                    toastManager.showToast("获取系统配置失败: ${e.message}", ToastType.Failed)
                }
            }
        }
    }

    private fun normalizeBaseUrlFromPageUrl(pageUrl: String): String? {
        val trimmed = pageUrl.trim()
        if (trimmed.isBlank()) return null
        val protocolSplit = trimmed.split("://")
        if (protocolSplit.size < 2) return null
        val protocol = protocolSplit[0]
        val authority = protocolSplit[1].substringBefore("/").substringBefore("#").substringBefore("?")
        if (authority.isBlank()) return null
        return "$protocol://$authority"
    }

    private suspend fun handleSysConfigMessage(
        json: JsonObject,
        baseUrl: String,
        onBaseUrlChange: (String) -> Unit
    ) {
        if (isSysConfigLoaded) return
        val body = json["body"]?.jsonPrimitive?.contentOrNull ?: return

        val bodyJson = runCatching { Json.parseToJsonElement(body).jsonObject }.getOrNull() ?: return
        val data = bodyJson["data"]?.jsonObject ?: return
        val oauth = data["nas_oauth"]?.jsonObject ?: return
        val appId = oauth["app_id"]?.jsonPrimitive?.contentOrNull ?: return
        val oauthUrl = oauth["url"]?.jsonPrimitive?.contentOrNull.orEmpty()

        val cookie = extractCookieValue(json)
        if (!cookie.isNullOrBlank()) {
            AccountDataCache.mergeCookieString(cookie)
            if (baseUrl.contains("5ddd.com") || baseUrl.contains("fnos.net")) {
                AccountDataCache.insertCookie("mode" to "relay")
            }
        }

        var currentBaseUrl = baseUrl
        if (currentBaseUrl.isBlank()) {
            val pageUrl = json["pageUrl"]?.jsonPrimitive?.contentOrNull.orEmpty()
            normalizeBaseUrlFromPageUrl(pageUrl)?.let { currentBaseUrl = it }
        }
        if (oauthUrl.isNotBlank() && oauthUrl != "://") {
            currentBaseUrl = oauthUrl
            onBaseUrlChange(currentBaseUrl)
        }

        if (currentBaseUrl.isBlank()) return

        val redirectUri = "$currentBaseUrl/v/oauth/result"
        val targetUrl = "$currentBaseUrl/signin?client_id=$appId&redirect_uri=$redirectUri"
        val domain = currentBaseUrl.substringAfter("://").substringBefore(":").substringBefore("/")

        if (!cookie.isNullOrBlank()) {
            cookie.split(";").forEach {
                val parts = it.trim().split("=", limit = 2)
                if (parts.size == 2) {
                    val cookieObj = Cookie(
                        name = parts[0],
                        value = parts[1],
                        domain = domain
                    )
                    setCookie(currentBaseUrl, cookieObj)
                }
            }
        }

        isSysConfigLoaded = true
        isSysConfigInFlight = false
        loadUrl(targetUrl)
    }

    private suspend fun handleResponseMessage(
        json: JsonObject,
        baseUrl: String,
        capturedUsername: String,
        capturedPassword: String,
        capturedRememberPassword: Boolean
    ) {
        if (!isAuthRequested) {
            val directCode = json["code"]?.jsonPrimitive?.contentOrNull
            val code = if (!directCode.isNullOrBlank()) {
                directCode
            } else {
                val body = json["body"]?.jsonPrimitive?.contentOrNull
                if (body.isNullOrBlank()) return
                runCatching {
                    val bodyJson = Json.parseToJsonElement(body).jsonObject
                    bodyJson["data"]?.jsonObject?.get("code")?.jsonPrimitive?.contentOrNull
                }.getOrNull()
            }

            if (!code.isNullOrBlank()) {
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
        }
    }
}
