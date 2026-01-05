package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.SubtitleSettings
import com.jankinwu.fntv.client.data.model.request.SetConfigByItemRequest
import com.jankinwu.fntv.client.data.model.response.PlayConfig
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

import com.jankinwu.fntv.client.data.model.response.EpisodeSegmentsResponse
import com.jankinwu.fntv.client.data.model.response.AnalysisStatus
import com.jankinwu.fntv.client.data.network.impl.FlyNarwhalApiImpl
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

class PlayerViewModel : ViewModel() {
    private val logger = Logger.withTag("PlayerViewModel")
    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _playingInfoCache = MutableStateFlow<PlayingInfoCache?>(null)
    val playingInfoCache: StateFlow<PlayingInfoCache?> = _playingInfoCache.asStateFlow()

    private val _subtitleSettings = MutableStateFlow(SubtitleSettings())
    val subtitleSettings: StateFlow<SubtitleSettings> = _subtitleSettings.asStateFlow()


    private var analysisJob: Job? = null
    private val _smartSegments = MutableStateFlow<EpisodeSegmentsResponse?>(null)

    val smartSegments: StateFlow<EpisodeSegmentsResponse?> = _smartSegments.asStateFlow()

    private val flyNarwhalApi = FlyNarwhalApiImpl()

    private val _smartSkipEnabled = MutableStateFlow(PlayingSettingsStore.smartSkipEnabled)
    val smartSkipEnabled: StateFlow<Boolean> = _smartSkipEnabled.asStateFlow()

    fun updateSubtitleSettings(settings: SubtitleSettings) {
        _subtitleSettings.value = settings
    }

    fun updatePlayingInfo(playingInfoCache: PlayingInfoCache?) {
        // 当切换视频（guid不同）或清除播放信息时，重置字幕设置
        if (playingInfoCache?.itemGuid != _playingInfoCache.value?.itemGuid) {
            _subtitleSettings.value = SubtitleSettings()
        }
        _playingInfoCache.value = playingInfoCache
        if (playingInfoCache != null && AppSettingsStore.smartAnalysisEnabled && _smartSkipEnabled.value) {
            val episodeGuid = playingInfoCache.currentVideoStream.mediaGuid
            if (episodeGuid.isNotBlank()) {
                checkAnalysisStatus(episodeGuid)
            } else {
                cancelAnalysisCheck()
            }
        } else {
            cancelAnalysisCheck()
        }
    }

    fun onSmartSkipEnabledChanged(enabled: Boolean) {
        PlayingSettingsStore.smartSkipEnabled = enabled
        _smartSkipEnabled.value = enabled
        if (enabled && AppSettingsStore.smartAnalysisEnabled) {
            val episodeGuid = playingInfoCache.value?.currentVideoStream?.mediaGuid
            if (!episodeGuid.isNullOrBlank()) {
                checkAnalysisStatus(episodeGuid)
            }
        } else {
            cancelAnalysisCheck()
        }
    }

    private fun checkAnalysisStatus(guid: String, type: String = "EPISODE") {
        analysisJob?.cancel()
        analysisJob = viewModelScope.launch {
            while (isActive) {
                try {
                    val statusResult = flyNarwhalApi.getStatus(type, guid)
                    if (statusResult.isSuccess()) {
                        val status = statusResult.data
                        logger.i { "Analysis status: $status" }
                        if (status == AnalysisStatus.COMPLETED) {
                            logger.i { "Analysis completed" }
                            val segmentsResult = flyNarwhalApi.getSegments(guid)
                            if (segmentsResult.isSuccess()) {
                                _smartSegments.value = segmentsResult.data
                            } else {
                                logger.w { "Get segments failed: code=${segmentsResult.code}, msg=${segmentsResult.msg}" }
                            }
                            break
                        } else if (status == AnalysisStatus.FAILED) {
                            // Should handle error toast in UI by observing state or simple error state
                            break
                        } else if (status == AnalysisStatus.IN_PROGRESS || status == AnalysisStatus.PENDING) {
                            delay(10000)
                        } else {
                            break
                        }
                    } else {
                        logger.w { "Get status failed: code=${statusResult.code}, msg=${statusResult.msg}" }
                        break
                    }
                } catch (e: Exception) {
                    logger.e(e) { "Check analysis status failed" }
                    break
                }
            }
        }
    }

    private fun cancelAnalysisCheck() {
        analysisJob?.cancel()
        _smartSegments.value = null
    }

    // Merged into the first updatePlayingInfo


    fun updateSubtitleList(subtitleStreams: List<SubtitleStream>, streamInfo: StreamResponse) {
        _playingInfoCache.update { current ->
            current?.copy(
                currentSubtitleStreamList = subtitleStreams,
                streamInfo = streamInfo
            )
        }
    }

    fun updateSkipConfig(skipOpening: Int, skipEnding: Int) {
        val currentInfo = _playingInfoCache.value ?: return
        val guid = currentInfo.playConfig?.guid ?: currentInfo.parentGuid ?: return

        val newConfig = currentInfo.playConfig?.copy(
            skipOpening = skipOpening,
            skipEnding = skipEnding
        ) ?: PlayConfig(guid = guid, skipOpening = skipOpening, skipEnding = skipEnding)

        _playingInfoCache.update { current ->
            current?.copy(playConfig = newConfig)
        }

        viewModelScope.launch {
            try {
                fnOfficialApi.setConfigByItem(
                    SetConfigByItemRequest(
                        guid = guid,
                        skipOpening = skipOpening,
                        skipEnding = skipEnding
                    )
                )
            } catch (_: Exception) {
                // Ignore error for now
            }
        }
    }
}
