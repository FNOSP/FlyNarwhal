package com.jankinwu.fntv.client.data.store

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf

object AccountDataCache {

    var authorization: String = ""

    private var cookieMap: MutableMap<String, String> = mutableMapOf()
    
    private var _cookieState = mutableStateOf("")
    val cookieState: String by _cookieState

    var userName: String = ""

    var password: String = ""

    var isHttps: Boolean = false

    var host: String = ""

    var displayHost: String = ""

    var displayPort: Int = 0

    var port: Int = 0

    var isLoggedIn: Boolean = false

    var rememberPassword: Boolean = false

    var isNasLogin: Boolean = false

    var fnId: String = ""

    fun getFnOfficialBaseUrl(): String {
        var endpoint = host
        if (port != 0) {
            endpoint = "$endpoint:$port"
        }
        return if (isHttps) {
            "https://$endpoint"
        } else {
            "http://$endpoint"
        }
    }

    fun getProxyBaseUrl(): String {
        return "http://127.0.0.1:1999"
    }

    private fun getCookie(): String {
        return cookieMap.entries.joinToString("; ") { "${it.key}=${it.value}" }
    }
    
    fun insertCookie(pair: Pair<String, String>) {
        cookieMap[pair.first] = pair.second
        _cookieState.value = getCookie()
    }

    fun insertCookies(cookies: Map<String, String>) {
        cookieMap.putAll(cookies)
        _cookieState.value = getCookie()
    }

    fun updateFnOfficialBaseUrlFromUrl(url: String) {
        try {
            val protocolSplit = url.split("://")
            if (protocolSplit.size < 2) return

            val protocol = protocolSplit[0]
            isHttps = protocol.equals("https", ignoreCase = true)

            val afterProtocol = protocolSplit[1]
            val authority = afterProtocol.substringBefore("/")

            if (authority.contains(":")) {
                val hostPort = authority.split(":")
                host = hostPort[0]
                port = hostPort[1].toIntOrNull() ?: 0
            } else {
                host = authority
                port = 0
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun clearCookie() {
        cookieMap.clear()
        _cookieState.value = ""
    }

    fun removeCookie(key: String) {
        cookieMap.remove(key)
        _cookieState.value = getCookie()
    }

    fun refreshCookie() {
        _cookieState.value = getCookie()
    }

    fun parseCookie(cookie: String) {
        cookieMap = cookie.split("; ").associate {
            val (key, value) = it.split("=", limit = 2)
            key to value
        } as MutableMap<String, String>
    }

    fun mergeCookieString(cookie: String) {
        if (cookie.isBlank()) return
        try {
            val map = cookie.split(";").associate {
                val parts = it.trim().split("=", limit = 2)
                if (parts.size == 2) {
                    parts[0] to parts[1]
                } else {
                    parts[0] to ""
                }
            }
            insertCookies(map)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}