package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.MediaItem
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class SearchViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<List<MediaItem>>>(UiState.Initial)
    val uiState: StateFlow<UiState<List<MediaItem>>> = _uiState.asStateFlow()

    private var searchJob: Job? = null

    fun search(query: String) {
        searchJob?.cancel()
        if (query.isBlank()) {
            _uiState.value = UiState.Initial
            return
        }
        searchJob = viewModelScope.launch {
            
            executeWithLoading(_uiState) {
                fnOfficialApi.search(query)
            }
        }
    }

    fun clearSearch() {
        searchJob?.cancel()
        _uiState.value = UiState.Initial
    }
}
