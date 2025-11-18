package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.request.SubtitleDownloadRequest
import com.jankinwu.fntv.client.data.model.response.SubtitleDownloadResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class SubtitleDownloadViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<SubtitleDownloadResponse>>(UiState.Initial)
    val uiState: StateFlow<UiState<SubtitleDownloadResponse>> = _uiState.asStateFlow()

    fun downloadSubtitle(mediaGuid: String, trimId: String, syncDownload: Int = 1) {
        val request = SubtitleDownloadRequest(mediaGuid, trimId, syncDownload)
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.subtitleDownload(request)
            }
        }
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}