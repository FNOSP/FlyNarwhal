package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.request.SubtitleSearchRequest
import com.jankinwu.fntv.client.data.model.response.SubtitleSearchResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class SubtitleSearchViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<SubtitleSearchResponse>>(UiState.Initial)
    val uiState: StateFlow<UiState<SubtitleSearchResponse>> = _uiState.asStateFlow()

    fun searchSubtitles(lan: String = "zh-CN", mediaGuid: String) {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                val request = SubtitleSearchRequest(lan, mediaGuid)
                fnOfficialApi.subtitleSearch(request)
            }
        }
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}