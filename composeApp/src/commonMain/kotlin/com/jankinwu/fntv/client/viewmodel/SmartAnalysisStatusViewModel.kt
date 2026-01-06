package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.response.AnalysisStatus
import com.jankinwu.fntv.client.data.model.response.EpisodeSegmentsResponse
import com.jankinwu.fntv.client.data.model.response.SmartAnalysisResult
import com.jankinwu.fntv.client.data.network.impl.FlyNarwhalApiImpl
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class SmartAnalysisStatusViewModel : BaseViewModel() {

    private val logger = Logger.withTag("SmartAnalysisStatusViewModel")
    private val flyNarwhalApi = FlyNarwhalApiImpl()

    private val _uiState = MutableStateFlow<UiState<SmartAnalysisResult<AnalysisStatus>>>(UiState.Initial)
    val uiState: StateFlow<UiState<SmartAnalysisResult<AnalysisStatus>>> = _uiState.asStateFlow()

    private var pollingJob: Job? = null

    private var episodeAnalysisJob: Job? = null
    private val _smartSegments = MutableStateFlow<EpisodeSegmentsResponse?>(null)
    val smartSegments: StateFlow<EpisodeSegmentsResponse?> = _smartSegments.asStateFlow()

    private val _smartSkipEnabled = MutableStateFlow(PlayingSettingsStore.smartSkipEnabled)
    val smartSkipEnabled: StateFlow<Boolean> = _smartSkipEnabled.asStateFlow()

    private val _currentEpisodeGuid = MutableStateFlow<String?>(null)

    // Starts polling analysis status and stops automatically when status is not pending/in-progress.
    fun startPolling(type: String, guid: String, force: Boolean = false) {
        stopPolling()
        _uiState.value = UiState.Loading
        pollingJob = viewModelScope.launch {
            var forceRetryCount = if (force) 6 else 0
            var sawPendingOrInProgress = false
            while (isActive) {
                try {
                    val result = flyNarwhalApi.getStatus(type = type, guid = guid)
                    _uiState.value = UiState.Success(result)

                    if (!result.isSuccess()) {
                        break
                    }

                    val status = result.data
                    if (status == AnalysisStatus.PREPARING || status == AnalysisStatus.PENDING || status == AnalysisStatus.IN_PROGRESS) {
                        sawPendingOrInProgress = true
                        delay(10_000)
                        continue
                    }
                    if (!sawPendingOrInProgress && forceRetryCount > 0) {
                        forceRetryCount--
                        delay(10_000)
                        continue
                    }
                    break
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    logger.e(e) { "Polling analysis status failed" }
                    _uiState.value = UiState.Error(e.message ?: "未知错误")
                    break
                }
            }
        }
    }

    fun stopPolling() {
        pollingJob?.cancel()
        pollingJob = null
    }

    fun updateEpisodeGuid(episodeGuid: String?) {
        if (_currentEpisodeGuid.value == episodeGuid) return
        _currentEpisodeGuid.value = episodeGuid
        restartEpisodeAnalysisIfNeeded()
    }

    fun onSmartSkipEnabledChanged(enabled: Boolean) {
        PlayingSettingsStore.smartSkipEnabled = enabled
        _smartSkipEnabled.value = enabled
        restartEpisodeAnalysisIfNeeded()
    }

    private fun restartEpisodeAnalysisIfNeeded() {
        cancelEpisodeAnalysisCheck()
        val episodeGuid = _currentEpisodeGuid.value
        if (episodeGuid.isNullOrBlank()) return
        if (!AppSettingsStore.smartAnalysisEnabled) return
        if (!_smartSkipEnabled.value) return
        startEpisodeAnalysisCheck(episodeGuid)
    }

    private fun startEpisodeAnalysisCheck(episodeGuid: String, type: String = "EPISODE") {
        _smartSegments.value = null
        episodeAnalysisJob?.cancel()
        episodeAnalysisJob = viewModelScope.launch {
            while (isActive) {
                try {
                    val statusResult = flyNarwhalApi.getStatus(type, episodeGuid)
                    if (statusResult.isSuccess()) {
                        val status = statusResult.data
                        logger.i { "Analysis status: $status" }
                        if (status == AnalysisStatus.COMPLETED) {
                            logger.i { "Analysis completed" }
                            val segmentsResult = flyNarwhalApi.getSegments(episodeGuid)
                            if (segmentsResult.isSuccess()) {
                                _smartSegments.value = segmentsResult.data
                            } else {
                                logger.w { "Get segments failed: code=${segmentsResult.code}, msg=${segmentsResult.msg}" }
                            }
                            break
                        } else if (status == AnalysisStatus.FAILED) {
                            break
                        } else if (status == AnalysisStatus.PREPARING || status == AnalysisStatus.IN_PROGRESS || status == AnalysisStatus.PENDING) {
                            delay(10_000)
                        } else {
                            break
                        }
                    } else {
                        logger.w { "Get status failed: code=${statusResult.code}, msg=${statusResult.msg}" }
                        break
                    }
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    logger.e(e) { "Check analysis status failed" }
                    break
                }
            }
        }
    }

    private fun cancelEpisodeAnalysisCheck() {
        episodeAnalysisJob?.cancel()
        episodeAnalysisJob = null
        _smartSegments.value = null
    }
}
