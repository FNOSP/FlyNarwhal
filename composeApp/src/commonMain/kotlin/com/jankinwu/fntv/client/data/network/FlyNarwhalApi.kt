package com.jankinwu.fntv.client.data.network

import com.jankinwu.fntv.client.data.model.request.AnalyzeRequest
import com.jankinwu.fntv.client.data.model.request.SetFnBaseUrlRequest
import com.jankinwu.fntv.client.data.model.request.UpdateSeasonStatusRequest
import com.jankinwu.fntv.client.data.model.response.AnalysisStatus
import com.jankinwu.fntv.client.data.model.response.Danmaku
import com.jankinwu.fntv.client.data.model.response.EpisodeSegmentsResponse
import com.jankinwu.fntv.client.data.model.response.SmartAnalysisResult

interface FlyNarwhalApi {

    suspend fun analyze(request: AnalyzeRequest): SmartAnalysisResult<String>

    suspend fun updateSeasonStatus(request: UpdateSeasonStatusRequest): SmartAnalysisResult<String>

    suspend fun getStatus(type: String, guid: String): SmartAnalysisResult<AnalysisStatus>

    suspend fun getSegments(episodeGuid: String): SmartAnalysisResult<EpisodeSegmentsResponse>

    suspend fun setFnBaseUrl(request: SetFnBaseUrlRequest): SmartAnalysisResult<String>

    suspend fun getDanmaku(
        doubanId: String,
        episodeNumber: Int,
        episodeTitle: String,
        title: String,
        seasonNumber: Int,
        season: Boolean,
        guid: String,
        parentGuid: String
    ): Map<String, List<Danmaku>>
}
