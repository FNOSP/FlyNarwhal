package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.request.ProxyInfoRequest
import com.jankinwu.fntv.client.data.network.impl.ProxyApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class ProxySettingViewModel : BaseViewModel() {

    private val proxyApi: ProxyApiImpl by inject(ProxyApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<Boolean>>(UiState.Initial)
    val uiState: StateFlow<UiState<Boolean>> = _uiState.asStateFlow()

    fun setProxyInfo(url: String, cookie: String) {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                val request = ProxyInfoRequest(url, cookie)
                proxyApi.setProxyInfo(request)
            }
        }
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}