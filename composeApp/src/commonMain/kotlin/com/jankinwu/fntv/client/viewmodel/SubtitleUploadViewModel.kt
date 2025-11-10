package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.SubtitleUploadResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class SubtitleUploadViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<SubtitleUploadResponse>>(UiState.Initial)
    val uiState: StateFlow<UiState<SubtitleUploadResponse>> = _uiState.asStateFlow()

    fun uploadSubtitle(guid: String, file: ByteArray) {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.uploadSubtitle(guid, file)
            }
        }
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}