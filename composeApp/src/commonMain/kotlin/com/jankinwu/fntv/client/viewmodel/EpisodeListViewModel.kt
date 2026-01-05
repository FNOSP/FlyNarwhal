package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class EpisodeListViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<List<EpisodeListResponse>>>(UiState.Initial)
    val uiState: StateFlow<UiState<List<EpisodeListResponse>>> = _uiState.asStateFlow()

    fun loadData(guid: String) {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.episodeList(guid)
            }
        }
    }

    suspend fun loadDataAndWait(guid: String): List<EpisodeListResponse> {
        executeWithLoading(_uiState, operationId = guid) {
            fnOfficialApi.episodeList(guid)
        }
        return when (val state = _uiState.value) {
            is UiState.Success -> state.data
            is UiState.Error -> throw (state.exception ?: Exception(state.message))
            else -> throw Exception("Unexpected episode list state")
        }
    }

    fun refresh(guid: String) {
        loadData(guid)
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}
