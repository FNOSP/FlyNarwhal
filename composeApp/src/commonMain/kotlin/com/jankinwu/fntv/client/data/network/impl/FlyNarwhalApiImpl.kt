package com.jankinwu.fntv.client.data.network.impl

import co.touchlab.kermit.Logger
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import com.jankinwu.fntv.client.data.model.request.AnalyzeRequest
import com.jankinwu.fntv.client.data.model.response.AnalysisStatus
import com.jankinwu.fntv.client.data.model.response.EpisodeSegmentsResponse
import com.jankinwu.fntv.client.data.model.response.SmartAnalysisResult
import com.jankinwu.fntv.client.data.network.FlyNarwhalApi
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.jackson.jackson
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders

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

    override suspend fun getStatus(type: String, guid: String): SmartAnalysisResult<AnalysisStatus> {
        return get("/api/analysis/status", mapOf("type" to type, "guid" to guid))
    }

    override suspend fun getSegments(episodeGuid: String): SmartAnalysisResult<EpisodeSegmentsResponse> {
        return get("/api/analysis/segments", mapOf("episodeGuid" to episodeGuid))
    }

    private suspend inline fun <reified T> get(
        url: String,
        parameters: Map<String, Any?>? = null,
        noinline block: (HttpRequestBuilder.() -> Unit)? = null
    ): SmartAnalysisResult<T> {
        val baseUrl = AppSettingsStore.smartAnalysisBaseUrl
        if (baseUrl.isBlank()) {
            throw IllegalArgumentException("智能分析服务URL未配置")
        }
        val fullUrl = if (baseUrl.endsWith("/")) "$baseUrl${url.removePrefix("/")}" else "$baseUrl$url"
        logger.i { "GET request: $fullUrl, params: $parameters" }

        try {
            val response = client.get(fullUrl) {
                parameters?.forEach { (key, value) ->
                    if (value != null) {
                        parameter(key, value)
                    }
                }
                block?.invoke(this)
            }
            val responseString = response.bodyAsText()
            logger.i { "GET request, url: $url, Response: $responseString" }
            return mapper.readValue<SmartAnalysisResult<T>>(responseString)
        } catch (e: Exception) {
            logger.e(e) { "GET request failed" }
            throw e
        }
    }

    private suspend inline fun <reified T> post(
        url: String,
        body: Any? = emptyMap<String, Any>(),
        noinline block: (HttpRequestBuilder.() -> Unit)? = null
    ): SmartAnalysisResult<T> {
        val baseUrl = AppSettingsStore.smartAnalysisBaseUrl
        if (baseUrl.isBlank()) {
            throw IllegalArgumentException("智能分析服务URL未配置")
        }
        val fullUrl = if (baseUrl.endsWith("/")) "$baseUrl${url.removePrefix("/")}" else "$baseUrl$url"
        logger.i { "POST request: $fullUrl, body: $body" }

        try {
            val response = client.post(fullUrl) {
                header(HttpHeaders.ContentType, "application/json; charset=utf-8")
                if (body != null) {
                    setBody(body)
                }
                block?.invoke(this)
            }
            val responseString = response.bodyAsText()
            logger.i { "Response: $responseString" }
            return mapper.readValue<SmartAnalysisResult<T>>(responseString)
        } catch (e: Exception) {
            logger.e(e) { "POST request failed" }
            throw e
        }
    }
}
