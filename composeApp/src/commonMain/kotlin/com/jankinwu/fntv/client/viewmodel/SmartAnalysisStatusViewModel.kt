package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.response.AnalysisStatus
import com.jankinwu.fntv.client.data.model.response.SmartAnalysisResult
import com.jankinwu.fntv.client.data.network.impl.FlyNarwhalApiImpl
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

    // Starts polling analysis status and stops automatically when status is not pending/in-progress.
    fun startPolling(type: String, guid: String) {
        stopPolling()
        pollingJob = viewModelScope.launch {
            while (isActive) {
                try {
                    if (_uiState.value is UiState.Initial) {
                        _uiState.value = UiState.Loading
                    }
                    val result = flyNarwhalApi.getStatus(type = type, guid = guid)
                    _uiState.value = UiState.Success(result)

                    if (!result.isSuccess()) {
                        break
                    }

                    val status = result.data
                    if (status == AnalysisStatus.PENDING || status == AnalysisStatus.IN_PROGRESS) {
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
}
