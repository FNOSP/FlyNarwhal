package com.jankinwu.fntv.client.data.network.impl

import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import com.jankinwu.fntv.client.data.model.request.FavoriteRequest
import com.jankinwu.fntv.client.data.model.request.ItemListQueryRequest
import com.jankinwu.fntv.client.data.model.request.LoginRequest
import com.jankinwu.fntv.client.data.model.request.PlayInfoRequest
import com.jankinwu.fntv.client.data.model.request.PlayPlayRequest
import com.jankinwu.fntv.client.data.model.request.PlayRecordRequest
import com.jankinwu.fntv.client.data.model.request.StreamRequest
import com.jankinwu.fntv.client.data.model.request.SubtitleDownloadRequest
import com.jankinwu.fntv.client.data.model.request.SubtitleMarkRequest
import com.jankinwu.fntv.client.data.model.request.SubtitleSearchRequest
import com.jankinwu.fntv.client.data.model.request.WatchedRequest
import com.jankinwu.fntv.client.data.model.response.AuthDirResponse
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
import com.jankinwu.fntv.client.data.model.response.FnBaseResponse
import com.jankinwu.fntv.client.data.model.response.GenresResponse
import com.jankinwu.fntv.client.data.model.response.ItemListQueryResponse
import com.jankinwu.fntv.client.data.model.response.ItemResponse
import com.jankinwu.fntv.client.data.model.response.LoginResponse
import com.jankinwu.fntv.client.data.model.response.MediaDbListResponse
import com.jankinwu.fntv.client.data.model.response.PersonListResponse
import com.jankinwu.fntv.client.data.model.response.PlayDetailResponse
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.PlayPlayResponse
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.model.response.ServerPathResponse
import com.jankinwu.fntv.client.data.model.response.StreamListResponse
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleDownloadResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleMarkResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleSearchResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleUploadResponse
import com.jankinwu.fntv.client.data.model.response.TagListResponse
import com.jankinwu.fntv.client.data.model.response.UserInfoResponse
import com.jankinwu.fntv.client.data.network.FnOfficialApi
import com.jankinwu.fntv.client.data.network.fnOfficialClient
import com.jankinwu.fntv.client.data.store.AccountDataCache
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.delete
import io.ktor.client.request.forms.formData
import io.ktor.client.request.forms.submitFormWithBinaryData
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.headers
import korlibs.crypto.MD5
import kotlin.random.Random
import kotlin.time.Clock
import kotlin.time.ExperimentalTime


class FnOfficialApiImpl() : FnOfficialApi {

    companion object {
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
    }

    override suspend fun getMediaDbList(): List<MediaDbListResponse> {
        return get("/v/api/v1/mediadb/list")
    }

    override suspend fun getItemList(request: ItemListQueryRequest): ItemListQueryResponse {
        println("query media list param: ${mapper.writeValueAsString(request)}")
        return post("/v/api/v1/item/list", request)
    }

    override suspend fun getPlayList(): List<PlayDetailResponse> {
        return get("/v/api/v1/play/list")
    }

    override suspend fun favorite(guid: String): Boolean {
        val favoriteRequest = FavoriteRequest(guid)
        return put("/v/api/v1/item/favorite", favoriteRequest)
    }

    override suspend fun cancelFavorite(guid: String): Boolean {
        val favoriteRequest = FavoriteRequest(guid)
        return delete("/v/api/v1/item/favorite", favoriteRequest)
    }

    override suspend fun watched(guid: String): Boolean {
        val watchedRequest = WatchedRequest(guid)
        return post("/v/api/v1/item/watched", watchedRequest)
    }

    override suspend fun cancelWatched(guid: String): Boolean {
        val watchedRequest = WatchedRequest(guid)
        return delete("/v/api/v1/item/watched", watchedRequest)
    }

    override suspend fun getGenres(lan: String): List<GenresResponse> {
        return get("/v/api/v1/tag/genres", mapOf("lan" to lan))
    }

    override suspend fun getTag(tag: String, lan: String): List<QueryTagResponse> {
        return get("/v/api/v1/tag/$tag", mapOf("lan" to lan))
    }

    override suspend fun getTagList(
        ancestorGuid: String?,
        isFavorite: Int,
        type: String?
    ): TagListResponse {
        return get(
            "/v/api/v1/tag/list",
            buildMap {
                ancestorGuid?.let { put("ancestor_guid", it) }
                put("is_favorite", isFavorite)
                type?.let { put("type", it) }
            }
        )
    }

    override suspend fun getStreamList(guid: String, beforePlay: Int?): StreamListResponse {
        val map = mapOf<String, Int>()
        if (beforePlay != null) {
            map.plus("before_play" to beforePlay)
            return get("/v/api/v1/stream/list/$guid", map)
        }
        return get("/v/api/v1/stream/list/$guid")
    }

    override suspend fun playPlay(request: PlayPlayRequest): PlayPlayResponse {
        return post("/v/api/v1/play/play", request)
    }

    override suspend fun playInfo(guid: String, mediaGuid: String?): PlayInfoResponse {
        val playInfoRequest = PlayInfoRequest(guid, mediaGuid)
        return post("/v/api/v1/play/info", playInfoRequest)
    }

    override suspend fun getItem(guid: String): ItemResponse {
        return get("/v/api/v1/item/$guid")
    }

    override suspend fun playRecord(request: PlayRecordRequest): Boolean {
        return post("/v/api/v1/play/record", request)
    }

    override suspend fun stream(request: StreamRequest): StreamResponse {
        return post("/v/api/v1/stream", request)
    }

    override suspend fun userInfo(): UserInfoResponse {
        return get("/v/api/v1/user/info")
    }

    override suspend fun login(request: LoginRequest): LoginResponse {
        return post("/v/api/v1/login", request)
    }

    override suspend fun logout(): Boolean {
        return post("/v/api/v1/user/logout")
    }

    override suspend fun episodeList(guid: String): List<EpisodeListResponse> {
        return get("/v/api/v1/episode/list/$guid")
    }

    override suspend fun personList(guid: String): PersonListResponse {
        return post("/v/api/v1/person/list/$guid")
    }

    override suspend fun uploadSubtitle(
        guid: String,
        file: ByteArray,
        fileName: String
    ): SubtitleUploadResponse {
        return postMultipartFile("/v/api/v1/subtitle/upload/$guid", "file", file, fileName)
    }

    override suspend fun deleteSubtitle(subtitleGuid: String): Boolean {
        return delete("/v/api/v1/subtitle/del", mapOf("subtitle_guid" to subtitleGuid))
    }

    override suspend fun getAppAuthorizedDir(withoutCache: Int): AuthDirResponse {
        return get("/v/api/v1/server/getAppAuthorizedDir", mapOf("without_cache" to withoutCache))
    }

    override suspend fun getFilesByServerPath(path: String): List<ServerPathResponse> {
        return post("/v/api/v1/server/path", mapOf("path" to path))
    }

    override suspend fun subtitleMark(request: SubtitleMarkRequest): List<SubtitleMarkResponse> {
        return put("/v/api/v1/subtitle/mark", request)
    }

    override suspend fun subtitleSearch(request: SubtitleSearchRequest): SubtitleSearchResponse {
        return post("/v/api/v1/subtitle/search", request)
    }

    override suspend fun subtitleDownload(request: SubtitleDownloadRequest): SubtitleDownloadResponse {
        return post("/v/api/v1/subtitle/download", request)
    }

    private suspend inline fun <reified T> get(
        url: String,
        parameters: Map<String, Any?>? = null,
        noinline block: (HttpRequestBuilder.() -> Unit)? = null
    ): T {
        return try {
            if (AccountDataCache.getFnOfficialBaseUrl().isBlank()) {
                throw IllegalArgumentException("飞牛官方URL未配置")
            }
            val authx = genAuthx(url, parameters)
            println("GET request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx, parameters: $parameters")

            val response = fnOfficialClient.get("${AccountDataCache.getFnOfficialBaseUrl()}$url") {
                header("Authx", authx)
                parameters?.forEach { (key, value) ->
                    if (value != null) {
                        parameter(key, value)
                    }
                }
                block?.invoke(this)
            }
            val responseString = response.bodyAsText()
            println("url: $url Get response content: $responseString")

            val body = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (body.code != 0) {
                println("请求异常: ${body.msg}, url: $url")
                throw Exception("请求失败, url: $url, code: ${body.code}, msg: ${body.msg}")
            }

            body.data ?: throw Exception("返回数据为空")
        } catch (e: java.net.UnknownHostException) {
            throw Exception("网络连接失败，请检查网络设置", e)
        } catch (e: io.ktor.client.network.sockets.ConnectTimeoutException) {
            throw Exception("连接超时，请稍后重试", e)
        } catch (e: io.ktor.client.plugins.ClientRequestException) {
            throw Exception("请求失败: ${e.message}", e)
        } catch (e: Exception) {
            throw Exception("请求失败: ${e.message}", e)
        }
    }

    private suspend inline fun <reified T> post(
        url: String,
        body: Any? = emptyMap<String, Any>(),
        noinline block: (HttpRequestBuilder.() -> Unit)? = null
    ): T {
        return try {
            // 校验 baseURL 是否存在
            if (AccountDataCache.getFnOfficialBaseUrl().isBlank()) {
                throw IllegalArgumentException("飞牛官方URL未配置")
            }

            val authx = genAuthx(url, data = body)
            println("POST request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx, body: $body")

            val response = fnOfficialClient.post("${AccountDataCache.getFnOfficialBaseUrl()}$url") {
                header(HttpHeaders.ContentType, "application/json; charset=utf-8")
                header("Authx", authx)
                if (body != null) {
                    setBody(body)
                }
                block?.invoke(this)
            }

            val responseString = response.bodyAsText()
            println("url: $url POST response content: $responseString")

            // 解析为对象
            val responseBody = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (responseBody.code != 0) {
                println("请求异常: ${responseBody.msg}, url: $url, request body: $body")
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
                println("302 response: ${response.bodyAsText()}")
            }
            throw Exception("请求失败: ${e.message}", e)
        }
    }

    private suspend inline fun <reified T> postMultipartFile(
        url: String,
        fileParamName: String = "file",
        file: ByteArray,
        fileName: String,
        additionalParams: Map<String, String> = emptyMap()
    ): T {
        return try {
            if (AccountDataCache.getFnOfficialBaseUrl().isBlank()) {
                throw IllegalArgumentException("飞牛官方URL未配置")
            }

            val authx = genAuthx(url)
            println("POST multipart file request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx")
            val response = fnOfficialClient.submitFormWithBinaryData(
                url = "${AccountDataCache.getFnOfficialBaseUrl()}$url",
                formData = formData {
                    // 添加文件
                    append(fileParamName, file, Headers.build {
                        append(HttpHeaders.ContentType, "application/octet-stream")
                        append(HttpHeaders.ContentDisposition, "filename=\"$fileName\"")
                    })

                    // 添加其他参数
                    additionalParams.forEach { (key, value) ->
                        append(key, value)
                    }
                }
            ) {
                headers {
                    append("Authx", authx)
                }
            }

            val responseString = response.bodyAsText()
            println("url: $url POST multipart file response content: $responseString")

            val responseBody = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (responseBody.code != 0) {
                throw Exception("请求失败, url: $url, code: ${responseBody.code}, msg: ${responseBody.msg}")
            }

            responseBody.data ?: throw Exception("返回数据为空")
        } catch (e: Exception) {
            throw Exception("请求失败: ${e.message}", e)
        }
    }

    private suspend inline fun <reified T> put(
        url: String,
        body: Any? = null,
        noinline block: (HttpRequestBuilder.() -> Unit)? = null
    ): T {
        return try {
            // 校验 baseURL 是否存在
            if (AccountDataCache.getFnOfficialBaseUrl().isBlank()) {
                throw IllegalArgumentException("飞牛官方URL未配置")
            }

            val authx = genAuthx(url, data = body)
            println("url: $url PUT request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx, body: $body")
            val response = fnOfficialClient.put("${AccountDataCache.getFnOfficialBaseUrl()}$url") {
                header(HttpHeaders.ContentType, "application/json; charset=utf-8")
                header("Authx", authx)
                if (body != null) {
                    setBody(body)
                }
                block?.invoke(this)
            }

            val responseString = response.bodyAsText()
            println("PUT response content: $responseString")

            // 解析为对象
            val responseBody = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (responseBody.code != 0) {
                println("请求异常: ${responseBody.msg}, url: $url, request body: $body")
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
            throw Exception("请求失败: ${e.message}", e)
        }
    }

    private suspend inline fun <reified T> delete(
        url: String,
        body: Any? = null,
        noinline block: (HttpRequestBuilder.() -> Unit)? = null
    ): T {
        return try {
            // 校验 baseURL 是否存在
            if (AccountDataCache.getFnOfficialBaseUrl().isBlank()) {
                throw IllegalArgumentException("飞牛官方URL未配置")
            }

            val authx = genAuthx(url, data = body)
            println("DELETE request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx, body: $body")

            val response = fnOfficialClient.delete("${AccountDataCache.getFnOfficialBaseUrl()}$url") {
                header(HttpHeaders.ContentType, "application/json; charset=utf-8")
                header("Authx", authx)
                if (body != null) {
                    setBody(body)
                }
                block?.invoke(this)
            }

            val responseString = response.bodyAsText()
            println("url: $url Delete response content: $responseString")

            // 解析为对象
            val responseBody = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (responseBody.code != 0) {
                println("请求异常: ${responseBody.msg}, url: $url, request body: $body")
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
            throw Exception("请求失败: ${e.message}", e)
        }
    }

    @OptIn(ExperimentalTime::class)
    private fun genAuthx(
        url: String,
        parameters: Map<String, Any?>? = null,
        data: Any? = null
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
            API_SECRET
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


