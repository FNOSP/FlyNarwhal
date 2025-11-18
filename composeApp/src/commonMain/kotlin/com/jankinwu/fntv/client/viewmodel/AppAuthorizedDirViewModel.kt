package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.AuthDirResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class AppAuthorizedDirViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<AuthDirResponse>>(UiState.Initial)
    val uiState: StateFlow<UiState<AuthDirResponse>> = _uiState.asStateFlow()

    fun loadAppAuthorizedDir(withoutCache: Int = 1) {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.getAppAuthorizedDir(withoutCache)
            }
        }
    }

    fun refreshAppAuthorizedDir(withoutCache: Int = 0) {
        loadAppAuthorizedDir(withoutCache)
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}