package com.jankinwu.fntv.client.data.network.impl

import co.touchlab.kermit.Logger
import com.fasterxml.jackson.module.kotlin.readValue
import com.jankinwu.fntv.client.data.model.request.ProxyInfoRequest
import com.jankinwu.fntv.client.data.model.response.FnBaseResponse
import com.jankinwu.fntv.client.data.network.ProxyApi
import com.jankinwu.fntv.client.data.network.fnOfficialClient
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl.Companion.mapper
import com.jankinwu.fntv.client.data.store.AccountDataCache
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders

class ProxyApiImpl(): ProxyApi {

    override suspend fun setProxyInfo(request: ProxyInfoRequest): Boolean {
        return post("/proxy/info", request)
    }

    private suspend inline fun <reified T> post(
        url: String,
        body: Any? = emptyMap<String, Any>(),
        noinline block: (HttpRequestBuilder.() -> Unit)? = null
    ): T {
        return try {
            // 校验 baseURL 是否存在
            if (AccountDataCache.getProxyBaseUrl().isBlank()) {
                throw IllegalArgumentException("飞牛影视代理 URL 未配置")
            }

            Logger.i { "proxy POST request, url: ${AccountDataCache.getProxyBaseUrl()}$url, body: $body" }

            val response = fnOfficialClient.post("${AccountDataCache.getProxyBaseUrl()}$url") {
                header(HttpHeaders.ContentType, "application/json; charset=utf-8")
                if (body != null) {
                    setBody(body)
                }
                block?.invoke(this)
            }

            val responseString = response.bodyAsText()
            Logger.i { "url: $url POST response content: $responseString" }

            // 解析为对象
            val responseBody = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (responseBody.code != 0) {
                Logger.e { "请求异常: ${responseBody.msg}, url: $url, request body: $body" }
                throw Exception("请求失败, url: $url, code: ${responseBody.code}, msg: ${responseBody.msg}")
            }

            responseBody.data ?: throw Exception("返回数据为空")
        } catch (e: java.net.UnknownHostException) {
            throw Exception("网络连接失败，请检查网络设置", e)
        } catch (e: io.ktor.client.network.sockets.ConnectTimeoutException) {
            throw Exception("连接超时，请稍后重试", e)
        } catch (e: io.ktor.client.plugins.ClientRequestException) {
            throw Exception("请求失败: ${e.message}", e)
        } catch (e: Exception) {
            if (e.message?.contains("302") == true) {
                val response = fnOfficialClient.get("${AccountDataCache.getFnOfficialBaseUrl()}/v")
                Logger.e(e) { "302 response: ${response.bodyAsText()}" }
            }
            throw Exception("请求失败: ${e.message}", e)
        }
    }
}