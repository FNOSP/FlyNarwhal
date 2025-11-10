package com.jankinwu.fntv.client.data.network

import com.jankinwu.fntv.client.data.model.request.ItemListQueryRequest
import com.jankinwu.fntv.client.data.model.request.LoginRequest
import com.jankinwu.fntv.client.data.model.request.PlayPlayRequest
import com.jankinwu.fntv.client.data.model.request.PlayRecordRequest
import com.jankinwu.fntv.client.data.model.request.StreamRequest
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
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
import com.jankinwu.fntv.client.data.model.response.StreamListResponse
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleUploadResponse
import com.jankinwu.fntv.client.data.model.response.TagListResponse
import com.jankinwu.fntv.client.data.model.response.UserInfoResponse

interface FnOfficialApi {

    suspend fun getMediaDbList(): List<MediaDbListResponse>

    suspend fun getItemList(request: ItemListQueryRequest): ItemListQueryResponse

    suspend fun getPlayList(): List<PlayDetailResponse>

    suspend fun favorite(guid: String): Boolean

    suspend fun cancelFavorite(guid: String): Boolean

    suspend fun watched(guid: String): Boolean

    suspend fun cancelWatched(guid: String): Boolean

    suspend fun getGenres(lan: String): List<GenresResponse>

    suspend fun getTag(tag: String, lan: String): List<QueryTagResponse>

    suspend fun getTagList(ancestorGuid: String?, isFavorite: Int, type: String?): TagListResponse

    suspend fun getStreamList(guid: String, beforePlay: Int?): StreamListResponse

    suspend fun playPlay(request: PlayPlayRequest): PlayPlayResponse

    suspend fun playInfo(guid: String, mediaGuid: String?): PlayInfoResponse

    suspend fun getItem(guid: String): ItemResponse

    suspend fun playRecord(request: PlayRecordRequest): Boolean

    suspend fun stream(request: StreamRequest): StreamResponse

    suspend fun userInfo(): UserInfoResponse

    suspend fun login(request: LoginRequest): LoginResponse

    suspend fun logout(): Boolean

    suspend fun episodeList(guid: String): List<EpisodeListResponse>

    suspend fun personList(guid: String): PersonListResponse

    suspend fun uploadSubtitle(guid: String, file: ByteArray): SubtitleUploadResponse
}