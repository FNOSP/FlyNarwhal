package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.SeasonItemResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class SeasonListViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<List<SeasonItemResponse>>>(UiState.Initial)
    val uiState: StateFlow<UiState<List<SeasonItemResponse>>> = _uiState.asStateFlow()

    fun loadData(guid: String) {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.seasonList(guid)
            }
        }
    }

    fun refresh(guid: String) {
        loadData(guid)
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}