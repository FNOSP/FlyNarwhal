package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.request.MediaPRequest
import com.jankinwu.fntv.client.data.model.response.MediaResetQualityResponse
import com.jankinwu.fntv.client.data.model.response.MediaTranscodeResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class MediaPViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _transcodeState = MutableStateFlow<UiState<MediaTranscodeResponse>>(UiState.Initial)
    val transcodeState: StateFlow<UiState<MediaTranscodeResponse>> = _transcodeState.asStateFlow()

    private val _resetQualityState = MutableStateFlow<UiState<MediaResetQualityResponse>>(UiState.Initial)
    val resetQualityState: StateFlow<UiState<MediaResetQualityResponse>> = _resetQualityState.asStateFlow()

    /**
     * Generic function to handle data loading
     */
    private fun <T> loadData(
        stateFlow: MutableStateFlow<UiState<T>>,
        apiCall: suspend () -> T
    ) {
        viewModelScope.launch {
            executeWithLoading(stateFlow) {
                apiCall()
            }
        }
    }

    /**
     * Logic for reqId: 1234567890ABCDEF (Transcode Status)
     */
    fun fetchTranscodeStatus(request: MediaPRequest) {
        request.req = "media.transcodeStatis"
        request.reqId = "1234567890ABCDEF"
        loadData(_transcodeState) {
            fnOfficialApi.mediaTranscodeStatus(request)
        }
    }

    /**
     * Logic for reqId: 1234567890ABCDEF2s (Reset Quality)
     */
    fun resetQuality(request: MediaPRequest) {
        request.req = "media.resetQuality"
        request.reqId = "1234567890ABCDEF2s"
        loadData(_resetQualityState) {
            fnOfficialApi.mediaResetQuality(request)
        }
    }

    fun clearError() {
        _transcodeState.value = UiState.Initial
        _resetQualityState.value = UiState.Initial
    }
}
