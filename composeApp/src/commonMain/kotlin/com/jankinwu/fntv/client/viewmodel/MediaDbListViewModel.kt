package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.MediaDbListResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class MediaDbListViewModel() : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<List<MediaDbListResponse>>>(UiState.Initial)
    val uiState: StateFlow<UiState<List<MediaDbListResponse>>> = _uiState.asStateFlow()

    private val _mediaSum = MutableStateFlow<Map<String, Int>>(emptyMap())
    val mediaSum: StateFlow<Map<String, Int>> = _mediaSum.asStateFlow()

    fun loadData() {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                val listDeferred = async { fnOfficialApi.getMediaDbList() }
                val sumDeferred = async { fnOfficialApi.getMediaDbSum() }

                val list = listDeferred.await()
                _mediaSum.value = sumDeferred.await()
                list
            }
        }
    }

    fun refresh() {
        loadData()
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}