package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.request.AnalyzeRequest
import com.jankinwu.fntv.client.data.model.request.QueuedEpisode
import com.jankinwu.fntv.client.data.model.request.UpdateSeasonStatusRequest
import com.jankinwu.fntv.client.data.model.response.AnalysisStatus
import com.jankinwu.fntv.client.data.network.FlyNarwhalApi
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class SmartAnalysisViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)
    private val flyNarwhalApi: FlyNarwhalApi by inject(FlyNarwhalApi::class.java)
    private val seasonListViewModel: SeasonListViewModel by inject(SeasonListViewModel::class.java)
    private val episodeListViewModel: EpisodeListViewModel by inject(EpisodeListViewModel::class.java)

    private val _analyzeState = MutableStateFlow<UiState<String>>(UiState.Initial)
    val analyzeState: StateFlow<UiState<String>> = _analyzeState.asStateFlow()

    private val _seasonStatusPollingTrigger = MutableSharedFlow<String>(extraBufferCapacity = 1)
    val seasonStatusPollingTrigger: SharedFlow<String> = _seasonStatusPollingTrigger.asSharedFlow()

    private val logger = Logger.withTag("SmartAnalysisViewModel")

    private suspend fun buildAnalyzeRequest(
        seasonGuid: String,
        tvTitle: String,
        seasonNumber: Int,
    ): AnalyzeRequest {
        logger.i { "Building analysis request for $tvTitle (S$seasonNumber, guid: $seasonGuid)" }
        val episodeList = episodeListViewModel.loadDataAndWait(seasonGuid)

        logger.i { "Found ${episodeList.size} episodes" }
        val queuedEpisodes = mutableListOf<QueuedEpisode>()
        var seasonPath = ""

        for (episode in episodeList) {
            try {
                delay(300)
                val streamList = fnOfficialApi.getStreamList(episode.guid, null)
                val files = streamList.files
                if (!files.isNullOrEmpty()) {
                    val file = files.first()
                    queuedEpisodes.add(
                        QueuedEpisode(
                            guid = file.guid,
                            filePath = file.path,
                            episodeNumber = episode.episodeNumber,
                            seasonNumber = seasonNumber
                        )
                    )

                    if (seasonPath.isEmpty()) {
                        val separator = if (file.path.contains("/")) '/' else '\\'
                        seasonPath = file.path.substringBeforeLast(separator, "")
                    }
                }
            } catch (e: Exception) {
                logger.e(e) { "Failed to get stream for episode ${episode.guid}" }
            }
        }

        if (queuedEpisodes.isEmpty()) {
            throw Exception("No valid episodes found to analyze")
        }

        logger.i { "Collected ${queuedEpisodes.size} episodes for analysis. Season path: $seasonPath" }
        return AnalyzeRequest(
            seasonGuid = seasonGuid,
            seasonPath = seasonPath,
            episodes = queuedEpisodes,
            tvTitle = tvTitle,
            seasonNumber = seasonNumber
        )
    }

    private suspend fun startSeasonAnalysis(
        seasonGuid: String,
        tvTitle: String,
        seasonNumber: Int,
        shouldUpdatePreparingStatus: Boolean = true,
    ) {
        if (shouldUpdatePreparingStatus) {
            val updateStatusResult = flyNarwhalApi.updateSeasonStatus(
                UpdateSeasonStatusRequest(
                    seasonGuids = listOf(seasonGuid),
                    status = AnalysisStatus.PREPARING.name
                )
            )
            if (!updateStatusResult.isSuccess()) {
                throw Exception(updateStatusResult.msg)
            }
            _seasonStatusPollingTrigger.tryEmit(seasonGuid)
        }
        val request = buildAnalyzeRequest(
            seasonGuid = seasonGuid,
            tvTitle = tvTitle,
            seasonNumber = seasonNumber
        )
        val result = flyNarwhalApi.analyze(request)
        if (!result.isSuccess()) {
            throw Exception(result.msg)
        }
    }

    fun analyzeSeason(seasonGuid: String, mediaTitle: String, seasonNumber: Int) {
        if (_analyzeState.value is UiState.Loading) return
        viewModelScope.launch {
            _analyzeState.value = UiState.Loading
            try {
                _analyzeState.value = UiState.Success("已加入到分析队列")
                startSeasonAnalysis(seasonGuid, mediaTitle, seasonNumber)
            } catch (e: Exception) {
                logger.e(e) { "Analysis failed" }
                _analyzeState.value = UiState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun analyzeTv(tvGuid: String, tvTitle: String) {
        if (_analyzeState.value is UiState.Loading) return
        viewModelScope.launch {
            _analyzeState.value = UiState.Loading
            try {
                val seasons = seasonListViewModel.loadDataAndWait(tvGuid).sortedBy { it.seasonNumber }

                if (seasons.isEmpty()) {
                    throw Exception("No seasons found to analyze")
                }

                val updateStatusResult = flyNarwhalApi.updateSeasonStatus(
                    UpdateSeasonStatusRequest(
                        seasonGuids = seasons.map { it.guid },
                        status = AnalysisStatus.PREPARING.name
                    )
                )
                if (!updateStatusResult.isSuccess()) {
                    throw Exception(updateStatusResult.msg)
                }
                seasons.forEach { _seasonStatusPollingTrigger.tryEmit(it.guid) }

                val normalizedTitle = tvTitle.ifBlank {
                    seasons.firstOrNull()?.parentTitle ?: seasons.firstOrNull()?.tvTitle ?: ""
                }

                val failedSeasonNumbers = mutableListOf<Int>()
                for (season in seasons) {
                    try {
                        delay(300)
                        startSeasonAnalysis(
                            seasonGuid = season.guid,
                            tvTitle = normalizedTitle,
                            seasonNumber = season.seasonNumber,
                            shouldUpdatePreparingStatus = false
                        )
                    } catch (e: Exception) {
                        logger.e(e) { "Failed to start analysis for season ${season.guid}" }
                        failedSeasonNumbers.add(season.seasonNumber)
                    }
                }

                if (failedSeasonNumbers.isNotEmpty()) {
                    val failedText = failedSeasonNumbers.sorted().joinToString(", ") { "S$it" }
                    _analyzeState.value = UiState.Error("部分季请求片头片尾分析失败：$failedText")
                } else {
                    _analyzeState.value = UiState.Success("已将 ${seasons.size} 季剧集加入分析队列")
                }
            } catch (e: Exception) {
                logger.e(e) { "TV analysis failed" }
                _analyzeState.value = UiState.Error(e.message ?: "Unknown error")
            }
        }
    }
    
    fun clearState() {
        _analyzeState.value = UiState.Initial
    }
}
