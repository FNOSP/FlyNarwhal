package com.jankinwu.fntv.client.data.network

import com.jankinwu.fntv.client.data.model.request.AuthRequest
import com.jankinwu.fntv.client.data.model.request.ItemListQueryRequest
import com.jankinwu.fntv.client.data.model.request.LoginRequest
import com.jankinwu.fntv.client.data.model.request.MediaPRequest
import com.jankinwu.fntv.client.data.model.request.PlayPlayRequest
import com.jankinwu.fntv.client.data.model.request.PlayRecordRequest
import com.jankinwu.fntv.client.data.model.request.ScrapRescrapRequest
import com.jankinwu.fntv.client.data.model.request.ScrapSearchRequest
import com.jankinwu.fntv.client.data.model.request.SetConfigByItemRequest
import com.jankinwu.fntv.client.data.model.request.StreamRequest
import com.jankinwu.fntv.client.data.model.request.SubtitleDownloadRequest
import com.jankinwu.fntv.client.data.model.request.SubtitleMarkRequest
import com.jankinwu.fntv.client.data.model.request.SubtitleSearchRequest
import com.jankinwu.fntv.client.data.model.response.AuthDirResponse
import com.jankinwu.fntv.client.data.model.response.AuthResponse
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
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


interface FnOfficialApi {

    suspend fun getSysConfig(): SysConfigResponse

    suspend fun oauthResult(code: String, state: String?): Boolean

    suspend fun auth(request: AuthRequest): AuthResponse

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

    suspend fun uploadSubtitle(guid: String, file: ByteArray, fileName: String): SubtitleUploadResponse

    suspend fun deleteSubtitle(subtitleGuid: String): Boolean

    suspend fun getAppAuthorizedDir(withoutCache: Int): AuthDirResponse

    suspend fun getFilesByServerPath(path: String): List<ServerPathResponse>

    suspend fun setConfigByItem(request: SetConfigByItemRequest): Boolean
    
    suspend fun subtitleMark(request: SubtitleMarkRequest): List<SubtitleMarkResponse>

    suspend fun subtitleSearch(request: SubtitleSearchRequest): SubtitleSearchResponse

    suspend fun subtitleDownload(request: SubtitleDownloadRequest): SubtitleDownloadResponse

    suspend fun mediaItemFile(guid: String): List<MediaItemResponse>

    suspend fun scrap(guid: String, mediaGuids: List<String>): Boolean

    suspend fun scrapSearch(request: ScrapSearchRequest): List<ScrapSearchResponse>

    suspend fun scrapRescrap(request: ScrapRescrapRequest): Boolean

    suspend fun mediaTranscodeStatus(request: MediaPRequest): MediaTranscodeResponse

    suspend fun mediaResetQuality(request: MediaPRequest): MediaResetQualityResponse

    suspend fun seasonList(guid: String): List<SeasonListResponse>
}