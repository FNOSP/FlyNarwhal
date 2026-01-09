package com.jankinwu.fntv.client.data.network.impl

import co.touchlab.kermit.Logger
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import com.jankinwu.fntv.client.data.model.request.AuthRequest
import com.jankinwu.fntv.client.data.model.request.FavoriteRequest
import com.jankinwu.fntv.client.data.model.request.ItemListQueryRequest
import com.jankinwu.fntv.client.data.model.request.LoginRequest
import com.jankinwu.fntv.client.data.model.request.MediaPRequest
import com.jankinwu.fntv.client.data.model.request.PlayInfoRequest
import com.jankinwu.fntv.client.data.model.request.PlayPlayRequest
import com.jankinwu.fntv.client.data.model.request.PlayRecordRequest
import com.jankinwu.fntv.client.data.model.request.ScrapRescrapRequest
import com.jankinwu.fntv.client.data.model.request.ScrapSearchRequest
import com.jankinwu.fntv.client.data.model.request.SetConfigByItemRequest
import com.jankinwu.fntv.client.data.model.request.StreamRequest
import com.jankinwu.fntv.client.data.model.request.SubtitleDownloadRequest
import com.jankinwu.fntv.client.data.model.request.SubtitleMarkRequest
import com.jankinwu.fntv.client.data.model.request.SubtitleSearchRequest
import com.jankinwu.fntv.client.data.model.request.WatchedRequest
import com.jankinwu.fntv.client.data.model.response.AuthDirResponse
import com.jankinwu.fntv.client.data.model.response.AuthResponse
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
import com.jankinwu.fntv.client.data.model.response.FnBaseResponse
import com.jankinwu.fntv.client.data.model.response.GenresResponse
import com.jankinwu.fntv.client.data.model.response.ItemListQueryResponse
import com.jankinwu.fntv.client.data.model.response.ItemResponse
import com.jankinwu.fntv.client.data.model.response.LoginResponse
import com.jankinwu.fntv.client.data.model.response.MediaDbListResponse
import com.jankinwu.fntv.client.data.model.response.MediaItemResponse
import com.jankinwu.fntv.client.data.model.response.MediaResetQualityResponse
import com.jankinwu.fntv.client.data.model.response.MediaTranscodeResponse
import com.jankinwu.fntv.client.data.model.response.PersonListResponse
import com.jankinwu.fntv.client.data.model.response.PlayDetailResponse
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.PlayPlayResponse
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.model.response.ScrapSearchResponse
import com.jankinwu.fntv.client.data.model.response.SeasonListResponse
import com.jankinwu.fntv.client.data.model.response.ServerPathResponse
import com.jankinwu.fntv.client.data.model.response.StreamListResponse
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleDownloadResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleMarkResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleSearchResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleUploadResponse
import com.jankinwu.fntv.client.data.model.response.SysConfigResponse
import com.jankinwu.fntv.client.data.model.response.TagListResponse
import com.jankinwu.fntv.client.data.model.response.UserInfoResponse
import com.jankinwu.fntv.client.data.network.FnOfficialApi
import com.jankinwu.fntv.client.data.network.fnOfficialClient
import com.jankinwu.fntv.client.data.network.impl.FnApiHelper.genAuthx
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


class FnOfficialApiImpl : FnOfficialApi {
    private val logger = Logger.withTag("FnOfficialApiImpl")

    companion object {
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

    override suspend fun getSysConfig(): SysConfigResponse {
        return get("/v/api/v1/sys/config")
    }

    override suspend fun oauthResult(code: String, state: String?): Boolean {
        return post("/v/oauth/result?code=$code&state=${state ?: "undefined"}")
    }

    override suspend fun auth(request: AuthRequest): AuthResponse {
        return post("/v/api/v1/auth", request)
    }

    override suspend fun getMediaDbList(): List<MediaDbListResponse> {
        return get("/v/api/v1/mediadb/list")
    }

    override suspend fun getItemList(request: ItemListQueryRequest): ItemListQueryResponse {
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

    override suspend fun mediaItemFile(guid: String): List<MediaItemResponse> {
        return get("/v/api/v1/media/itemfile/$guid")
    }

    override suspend fun scrap(guid: String, mediaGuids: List<String>): Boolean {
        return delete("/v/api/v1/scrap/$guid", mapOf("media_guids" to mediaGuids))
    }

    override suspend fun scrapSearch(request: ScrapSearchRequest): List<ScrapSearchResponse> {
        return post("/v/api/v1/scrap/search", request)
    }

    override suspend fun scrapRescrap(request: ScrapRescrapRequest): Boolean {
        return post("/v/api/v1/scrap/rescrap", request)
    }

    override suspend fun mediaTranscodeStatus(request: MediaPRequest): MediaTranscodeResponse {
        return post("/v/api/v1/media/p", request)
    }

    override suspend fun mediaResetQuality(request: MediaPRequest): MediaResetQualityResponse {
        return post("/v/api/v1/media/p", request)
    }

    override suspend fun seasonList(guid: String): List<SeasonListResponse> {
        return get("/v/api/v1/season/list/$guid")
    }

    override suspend fun setConfigByItem(request: SetConfigByItemRequest): Boolean {
        return post("/v/api/v1/play/setConfigByItem", request)
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
            logger.i { "GET request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx, parameters: $parameters, cookie: ${AccountDataCache.cookieState}" }
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
            logger.i { "url: $url Get response content: $responseString" }
            val body = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (body.code != 0) {
                logger.e { "请求异常: ${body.msg}, url: $url" }
                throw Exception("url: $url, code: ${body.code}, msg: ${body.msg}")
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
            logger.i { "POST request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx, body: $body, cookie: ${AccountDataCache.cookieState}" }
            val response = fnOfficialClient.post("${AccountDataCache.getFnOfficialBaseUrl()}$url") {
                header(HttpHeaders.ContentType, "application/json; charset=utf-8")
                header("Authx", authx)
                if (body != null) {
                    setBody(body)
                }
                block?.invoke(this)
            }

            val responseString = response.bodyAsText()
            logger.i { "url: $url POST response content: $responseString" }
            // 解析为对象
            val responseBody = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (responseBody.code != 0) {
                logger.e { "请求异常: ${responseBody.msg}, url: $url, request body: $body" }
                throw Exception("url: $url, code: ${responseBody.code}, msg: ${responseBody.msg}")
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
                logger.e(e) { "302 response: ${response.bodyAsText()}" }
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
            logger.i { "POST multipart file request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx" }
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
            logger.i { "url: $url POST multipart file response content: $responseString" }

            val responseBody = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (responseBody.code != 0) {
                throw Exception("url: $url, code: ${responseBody.code}, msg: ${responseBody.msg}")
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
            logger.i { "url: $url PUT request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx, body: $body" }
            val response = fnOfficialClient.put("${AccountDataCache.getFnOfficialBaseUrl()}$url") {
                header(HttpHeaders.ContentType, "application/json; charset=utf-8")
                header("Authx", authx)
                if (body != null) {
                    setBody(body)
                }
                block?.invoke(this)
            }

            val responseString = response.bodyAsText()
            logger.i { "PUT response content: $responseString" }

            // 解析为对象
            val responseBody = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (responseBody.code != 0) {
                logger.e { "请求异常: ${responseBody.msg}, url: $url, request body: $body" }
                throw Exception("url: $url, code: ${responseBody.code}, msg: ${responseBody.msg}")
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
            logger.i { "DELETE request, url: ${AccountDataCache.getFnOfficialBaseUrl()}$url, authx: $authx, body: $body" }
            val response =
                fnOfficialClient.delete("${AccountDataCache.getFnOfficialBaseUrl()}$url") {
                    header(HttpHeaders.ContentType, "application/json; charset=utf-8")
                    header("Authx", authx)
                    if (body != null) {
                        setBody(body)
                    }
                    block?.invoke(this)
                }

            val responseString = response.bodyAsText()
            logger.i { "url: $url Delete response content: $responseString" }

            // 解析为对象
            val responseBody = mapper.readValue<FnBaseResponse<T>>(responseString)
            if (responseBody.code != 0) {
                logger.e { "请求异常: ${responseBody.msg}, url: $url, request body: $body" }
                throw Exception("url: $url, code: ${responseBody.code}, msg: ${responseBody.msg}")
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
}


