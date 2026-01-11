package com.jankinwu.fntv.client.data.network.impl

import co.touchlab.kermit.Logger
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import com.jankinwu.fntv.client.data.model.request.AnalyzeRequest
import com.jankinwu.fntv.client.data.model.request.SetFnBaseUrlRequest
import com.jankinwu.fntv.client.data.model.request.UpdateSeasonStatusRequest
import com.jankinwu.fntv.client.data.model.response.AnalysisStatus
import com.jankinwu.fntv.client.data.model.response.Danmaku
import com.jankinwu.fntv.client.data.model.response.EpisodeSegmentsResponse
import com.jankinwu.fntv.client.data.model.response.SmartAnalysisResult
import com.jankinwu.fntv.client.data.network.FlyNarwhalApi
import com.jankinwu.fntv.client.data.network.impl.FnApiHelper.genAuthx
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.plugins.timeout
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.prepareGet
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsChannel
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.serialization.jackson.jackson
import io.ktor.utils.io.readUTF8Line

class FlyNarwhalApiImpl : FlyNarwhalApi {
    private val logger = Logger.withTag("FlyNarwhalApiImpl")

    private val client = HttpClient {
        install(ContentNegotiation) {
            jackson {
                disable(SerializationFeature.INDENT_OUTPUT)
                disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
                disable(SerializationFeature.WRITE_NULL_MAP_VALUES)
            }
        }
        install(HttpTimeout) {
            requestTimeoutMillis = 30000
            connectTimeoutMillis = 10000
            socketTimeoutMillis = 30000
        }
        // 添加公共请求头
        defaultRequest {
            header(HttpHeaders.Authorization, AccountDataCache.authorization)
            header(HttpHeaders.Accept, "application/json")
            if (AccountDataCache.cookieState.isNotBlank()) {
                header(HttpHeaders.Cookie, AccountDataCache.cookieState)
            }
            header(HttpHeaders.UserAgent, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36")
        }
    }

    companion object {
        val mapper = jacksonObjectMapper().apply {
            disable(SerializationFeature.INDENT_OUTPUT)
            disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            disable(SerializationFeature.WRITE_NULL_MAP_VALUES)
        }
    }

    override suspend fun analyze(request: AnalyzeRequest): SmartAnalysisResult<String> {
        return post("/api/analysis/analyze", request)
    }

    override suspend fun updateSeasonStatus(request: UpdateSeasonStatusRequest): SmartAnalysisResult<String> {
        return post("/api/analysis/season/status", request)
    }

    override suspend fun getStatus(type: String, guid: String): SmartAnalysisResult<AnalysisStatus> {
        return get("/api/analysis/status", mapOf("type" to type, "guid" to guid))
    }

    override suspend fun getSegments(episodeGuid: String): SmartAnalysisResult<EpisodeSegmentsResponse> {
        return get("/api/analysis/segments", mapOf("episodeGuid" to episodeGuid))
    }

    override suspend fun setFnBaseUrl(request: SetFnBaseUrlRequest): SmartAnalysisResult<String> {
        return post("/api/config/fn-base-url", request)
    }

    override suspend fun getDanmaku(
        doubanId: String,
        episodeNumber: Int,
        episodeTitle: String,
        title: String,
        seasonNumber: Int,
        season: Boolean,
        guid: String,
        parentGuid: String
    ): Map<String, List<Danmaku>> {
        val parameters = mapOf(
            "douban_id" to doubanId,
            "episode_number" to episodeNumber,
            "episode_title" to episodeTitle,
            "title" to title,
            "season_number" to seasonNumber,
            "season" to season,
            "guid" to guid,
            "parent_guid" to parentGuid
        )

        return try {
            sseGet("/api/danmu/get", parameters) { response ->
                readDanmakuFromSse(response)
            }
        } catch (e: Exception) {
            logger.e(e) { "Failed to get danmaku" }
            emptyMap()
        }
    }

    private suspend fun readDanmakuFromSse(response: HttpResponse): Map<String, List<Danmaku>> {
        val channel = response.bodyAsChannel()
        var eventName: String? = null
        val dataLines = mutableListOf<String>()

        while (!channel.isClosedForRead) {
            val line = channel.readUTF8Line() ?: break

            if (line.isEmpty()) {
                val name = eventName
                val data = dataLines.joinToString("\n")
                eventName = null
                dataLines.clear()

                when (name?.lowercase()) {
                    "danmu" -> return parseDanmakuPayload(data)
                    "error" -> throw IllegalStateException(data.ifBlank { "SSE error" })
                    else -> Unit
                }

                continue
            }

            if (line.startsWith(":")) {
                continue
            }

            when {
                line.startsWith("event:") -> eventName = line.removePrefix("event:").trim()
                line.startsWith("data:") -> dataLines += line.removePrefix("data:").trimStart()
                else -> Unit
            }
        }

        throw IllegalStateException("SSE stream ended without danmu payload")
    }

    private fun parseDanmakuPayload(payload: String): Map<String, List<Danmaku>> {
        val trimmed = payload.trim()
        if (trimmed.isBlank()) return emptyMap()

        return try {
            mapper.readValue<Map<String, List<Danmaku>>>(trimmed)
        } catch (_: Exception) {
            val list = mapper.readValue<List<Danmaku>>(trimmed)
            mapOf("default" to list)
        }
    }

    private suspend inline fun <reified T> get(
        url: String,
        parameters: Map<String, Any?>? = null,
        noinline block: (HttpRequestBuilder.() -> Unit)? = null
    ): T {
        val fullUrl = buildFullUrl(url)
        logger.i { "GET request: $fullUrl, params: $parameters" }
        val authx = genAuthx(url, parameters)

        try {
            val response = client.get(fullUrl) {
                header("Authx", authx)
                parameters?.forEach { (key, value) ->
                    if (value != null) {
                        parameter(key, value)
                    }
                }
                block?.invoke(this)
            }
            val responseString = response.bodyAsText()
            logger.i { "GET request, url: $url, Response: $responseString" }
            return mapper.readValue<T>(responseString)
        } catch (e: Exception) {
            logger.e(e) { "GET request failed" }
            throw e
        }
    }

    /**
     * Executes a GET request for Server-Sent Events (SSE).
     */
    private suspend fun <T> sseGet(
        url: String,
        parameters: Map<String, Any?>? = null,
        handleResponse: suspend (HttpResponse) -> T
    ): T {
        val fullUrl = buildFullUrl(url)
        val authx = genAuthx(url, parameters)
        logger.i { "GET SSE request: $fullUrl, params: $parameters" }

        return client.prepareGet(fullUrl) {
            header(HttpHeaders.Accept, "text/event-stream")
            header("Authx", authx)
            parameters?.forEach { (key, value) ->
                if (value != null) {
                    parameter(key, value)
                }
            }
            timeout {
                requestTimeoutMillis = 240_000
                connectTimeoutMillis = 15_000
                socketTimeoutMillis = 240_000
            }
        }.execute { response ->
            handleResponse(response)
        }
    }

    private suspend inline fun <reified T> post(
        url: String,
        body: Any? = emptyMap<String, Any>(),
        noinline block: (HttpRequestBuilder.() -> Unit)? = null
    ): T {
        val fullUrl = buildFullUrl(url)
        val authx = genAuthx(url, data = body)
        logger.i { "POST request: $fullUrl, body: $body" }

        try {
            val response = client.post(fullUrl) {
                header(HttpHeaders.ContentType, "application/json; charset=utf-8")
                header("Authx", authx)
                if (body != null) {
                    setBody(body)
                }
                block?.invoke(this)
            }
            val responseString = response.bodyAsText()
            logger.i { "Response: $responseString" }
            return mapper.readValue<T>(responseString)
        } catch (e: Exception) {
            logger.e(e) { "POST request failed" }
            throw e
        }
    }

    /**
     * Builds the full URL using the configured base URL.
     */
    private fun buildFullUrl(url: String): String {
        val baseUrl = AppSettingsStore.flyNarwhalServerBaseUrl
        if (baseUrl.isBlank()) {
            throw IllegalArgumentException("飞鲸影视服务端 URL 未配置")
        }
        return if (baseUrl.endsWith("/")) "$baseUrl${url.removePrefix("/")}" else "$baseUrl$url"
    }
}
