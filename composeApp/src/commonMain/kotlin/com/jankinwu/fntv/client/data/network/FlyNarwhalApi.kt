package com.jankinwu.fntv.client.data.network

import com.jankinwu.fntv.client.data.model.request.AnalyzeRequest
import com.jankinwu.fntv.client.data.model.response.AnalysisStatus
import com.jankinwu.fntv.client.data.model.response.EpisodeSegmentsResponse
import com.jankinwu.fntv.client.data.model.response.SmartAnalysisResult

interface FlyNarwhalApi {
    suspend fun analyze(request: AnalyzeRequest): SmartAnalysisResult<String>
    suspend fun getStatus(type: String, guid: String): SmartAnalysisResult<AnalysisStatus>
    suspend fun getSegments(episodeGuid: String): SmartAnalysisResult<EpisodeSegmentsResponse>
}
