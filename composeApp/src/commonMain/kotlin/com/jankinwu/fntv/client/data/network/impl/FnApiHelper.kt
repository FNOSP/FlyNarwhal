package com.jankinwu.fntv.client.data.network.impl

import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.jankinwu.fntv.client.BuildConfig
import korlibs.crypto.MD5
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
    fun genAuthx(
        url: String,
        parameters: Map<String, Any?>? = null,
        data: Any? = null,
        apiSecret: String = BuildConfig.FLY_NARWHAL_API_SECRET
    ): String {
        val nonce = generateRandomDigits()
        val timestamp = Clock.System.now().toEpochMilliseconds().toString()
        val dataJsonMd5 = when {
            data != null -> {
                val dataJson = mapper.writeValueAsString(data)
                getMd5(dataJson)
            }

            parameters != null -> {
                // 对参数按键排序并编码
                val sortedParams = parameters.filterValues { it != null }
                    .toSortedMap()
                    .map { "${it.key}=${it.value}" }
                    .joinToString("&")
                getMd5(sortedParams)
            }

            else -> getMd5("")
        }

        val signArray = arrayOf(
            API_KEY,
            url,
            nonce,
            timestamp,
            dataJsonMd5,
            apiSecret.ifBlank { API_SECRET }
        )

        val signStr = signArray.joinToString("_")
        val sign = getMd5(signStr)
        return "nonce=$nonce&timestamp=$timestamp&sign=${sign}"
    }

    private fun generateRandomDigits(start: Int = 100000, end: Int = 1000000): String {
        return Random.nextInt(start, end).toString()
    }

    private fun getMd5(input: String): String {
        return MD5.digest(input.toByteArray(Charsets.UTF_8)).hex
    }
}
