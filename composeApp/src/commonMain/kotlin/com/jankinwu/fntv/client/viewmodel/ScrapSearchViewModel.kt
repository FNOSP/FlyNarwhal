package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.request.ScrapSearchRequest
import com.jankinwu.fntv.client.data.model.response.ScrapSearchResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class ScrapSearchViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<List<ScrapSearchResponse>>>(UiState.Initial)
    val uiState: StateFlow<UiState<List<ScrapSearchResponse>>> = _uiState.asStateFlow()

    fun search(request: ScrapSearchRequest) {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.scrapSearch(request)
            }
        }
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}