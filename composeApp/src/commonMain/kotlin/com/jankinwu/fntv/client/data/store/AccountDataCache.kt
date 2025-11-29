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

    var port: Int = 0

    var isLoggedIn: Boolean = false

    var rememberMe: Boolean = false

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

    fun clearCookie() {
        cookieMap.clear()
        _cookieState.value = ""
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
}