package com.jankinwu.fntv.client.data.network.impl

import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.jankinwu.fntv.client.BuildConfig
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import korlibs.crypto.MD5
import korlibs.crypto.SHA256
import kotlin.random.Random
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

object FnApiHelper {
    private const val API_KEY = "NDzZTVxnRKP8Z0jXg1VAMonaG8akvh"
    private const val API_SECRET = "16CCEB3D-AB42-077D-36A1-F355324E4237"

    val mapper = jacksonObjectMapper().apply {
        // 禁止格式化输出
        disable(SerializationFeature.INDENT_OUTPUT)
        // 忽略未知字段
        disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
        // 不序列化null值
        disable(SerializationFeature.WRITE_NULL_MAP_VALUES)
//            setSerializationInclusion(JsonInclude.Include.NON_NULL)
    }

    @OptIn(ExperimentalTime::class)
    fun genAuthxForOfficial(
        url: String,
        parameters: Map<String, Any?>? = null,
        data: Any? = null,
    ): String {
        return genAuthxInternal(
            url = url,
            parameters = parameters,
            data = data,
            apiSecret = API_SECRET
        )
    }

    @OptIn(ExperimentalTime::class)
    fun genAuthxForFlyNarwhal(
        url: String,
        parameters: Map<String, Any?>? = null,
        data: Any? = null,
    ): String {
        val configuredSecret = BuildConfig.FLY_NARWHAL_API_SECRET.trim()
        return genAuthxInternal(
            url = url,
            parameters = parameters,
            data = data,
            apiSecret = configuredSecret.ifBlank { API_SECRET }
        )
    }

    @OptIn(ExperimentalTime::class)
    fun genAuthx(
        url: String,
        parameters: Map<String, Any?>? = null,
        data: Any? = null,
    ): String {
        return genAuthxForFlyNarwhal(url = url, parameters = parameters, data = data)
    }

    @OptIn(ExperimentalTime::class)
    private fun genAuthxInternal(
        url: String,
        parameters: Map<String, Any?>?,
        data: Any?,
        apiSecret: String
    ): String {
        val nonce = generateRandomDigits()
        val timestamp = Clock.System.now().toEpochMilliseconds().toString()
        val dataJsonMd5 = buildDataJsonMd5(parameters, data)

        val signList = mutableListOf(
            API_KEY,
            url,
            nonce,
            timestamp,
            dataJsonMd5,
            apiSecret
        )

        val signStr = signList.joinToString("_")
        val sign = getMd5(signStr)
        return "nonce=$nonce&timestamp=$timestamp&sign=${sign}"
    }

    fun genSignxForFlyNarwhal(
        url: String,
        authx: String,
        parameters: Map<String, Any?>? = null,
        data: Any? = null,
        publicKeyBase64: String = AppSettingsStore.authCode
    ): String {
        val authxMap = parseAuthxHeader(authx)
        val nonce = authxMap["nonce"].orEmpty()
        val timestamp = authxMap["timestamp"].orEmpty()
        val sign = authxMap["sign"].orEmpty()
        val dataJsonMd5 = buildDataJsonMd5(parameters, data)
        val signxStr = listOf(timestamp, nonce, sign, dataJsonMd5, url, publicKeyBase64).joinToString("_")
        return sha256Hex(signxStr)
    }

    private fun generateRandomDigits(start: Int = 100000, end: Int = 1000000): String {
        return Random.nextInt(start, end).toString()
    }

    private fun buildDataJsonMd5(parameters: Map<String, Any?>?, data: Any?): String {
        return when {
            data != null -> {
                val dataJson = mapper.writeValueAsString(data)
                getMd5(dataJson)
            }

            parameters != null -> {
                val sortedParams = parameters.filterValues { it != null }
                    .toSortedMap()
                    .map { "${it.key}=${it.value}" }
                    .joinToString("&")
                getMd5(sortedParams)
            }

            else -> getMd5("")
        }
    }

    private fun parseAuthxHeader(authx: String): Map<String, String> {
        return authx.split("&")
            .mapNotNull { part ->
                val kv = part.split("=", limit = 2)
                if (kv.size == 2) kv[0] to kv[1] else null
            }
            .toMap()
    }

    private fun getMd5(input: String): String {
        return MD5.digest(input.toByteArray(Charsets.UTF_8)).hex
    }

    private fun sha256Hex(input: String): String {
        return SHA256.digest(input.toByteArray(Charsets.UTF_8)).hex
    }
}
