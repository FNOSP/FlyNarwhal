package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.request.SubtitleMarkRequest
import com.jankinwu.fntv.client.data.model.response.SubtitleMarkResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class SubtitleMarkViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<List<SubtitleMarkResponse>>>(UiState.Initial)
    val uiState: StateFlow<UiState<List<SubtitleMarkResponse>>> = _uiState.asStateFlow()

    fun markSubtitles(mediaGuid: String, filePaths: List<String>) {
        val request = SubtitleMarkRequest(mediaGuid, filePaths);
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.subtitleMark(request)
            }
        }
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}