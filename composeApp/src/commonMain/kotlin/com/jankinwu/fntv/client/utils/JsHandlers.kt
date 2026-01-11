package com.jankinwu.fntv.client.utils

import com.multiplatform.webview.jsbridge.IJsMessageHandler
import com.multiplatform.webview.jsbridge.JsMessage
import com.multiplatform.webview.web.WebViewNavigator
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class NetworkLogHandler(private val onMessage: (String) -> Unit) : IJsMessageHandler {
    override fun methodName(): String = "LogNetwork"

    override fun handle(message: JsMessage, navigator: WebViewNavigator?, callback: (String) -> Unit) {
        onMessage(message.params)
        callback("OK")
    }
}

class CaptureLoginInfoHandler(private val onCapture: (String, String, Boolean) -> Unit) : IJsMessageHandler {
    override fun methodName(): String = "CaptureLoginInfo"

    override fun handle(message: JsMessage, navigator: WebViewNavigator?, callback: (String) -> Unit) {
        try {
            val json = Json.parseToJsonElement(message.params).jsonObject
            val username = json["username"]?.jsonPrimitive?.contentOrNull ?: ""
            val password = json["password"]?.jsonPrimitive?.contentOrNull ?: ""
            val rememberPassword = json["rememberPassword"]?.jsonPrimitive?.booleanOrNull ?: false
            onCapture(username, password, rememberPassword)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        callback("OK")
    }
}
