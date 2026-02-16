package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.request.LoginRequest
import com.jankinwu.fntv.client.data.model.response.LoginResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import com.jankinwu.fntv.client.manager.PreferencesManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class LoginViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)
    private val preferencesManager = PreferencesManager.getInstance()

    private val _uiState = MutableStateFlow<UiState<LoginResponse>>(UiState.Initial)
    val uiState: StateFlow<UiState<LoginResponse>> = _uiState.asStateFlow()

    fun login(
        username: String,
        password: String,
    ) {
        if (_uiState.value is UiState.Loading) return
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                val request = LoginRequest(username, password)
                fnOfficialApi.login(request)
            }
        }
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}
