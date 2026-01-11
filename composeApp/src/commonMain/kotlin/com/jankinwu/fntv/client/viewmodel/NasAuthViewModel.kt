package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.request.AuthRequest
import com.jankinwu.fntv.client.data.model.response.AuthResponse
import com.jankinwu.fntv.client.data.model.response.SysConfigResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class NasAuthViewModel : BaseViewModel() {
    private val logger = Logger.withTag("NasAuthViewModel")
    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _authUiState = MutableStateFlow<UiState<AuthResponse>>(UiState.Initial)
    val authUiState: StateFlow<UiState<AuthResponse>> = _authUiState.asStateFlow()

    private val _sysConfigUiState = MutableStateFlow<UiState<SysConfigResponse>>(UiState.Initial)
    val sysConfigUiState: StateFlow<UiState<SysConfigResponse>> = _sysConfigUiState.asStateFlow()

    fun auth(code: String) {
        viewModelScope.launch {
            try {
                executeWithLoading(_authUiState) {
                    fnOfficialApi.auth(AuthRequest("Trim-NAS", code))
                }
            } catch (e: Exception) {
                logger.e("auth error: ${e.message}")
            }
        }
    }

    suspend fun authAndReturn(code: String): AuthResponse {
        return try {
            executeWithLoadingAndReturn {
                fnOfficialApi.auth(AuthRequest("Trim-NAS", code))
            }
        } catch (e: Exception) {
            logger.e("authAndReturn error: ${e.message}")
            throw e
        }
    }

    fun getSysConfig() {
        viewModelScope.launch {
            try {
                executeWithLoading(_sysConfigUiState) {
                    fnOfficialApi.getSysConfig()
                }
            } catch (e: Exception) {
                logger.e("getSysConfig error: ${e.message}")
            }
        }
    }

    suspend fun getSysConfigAndReturn(): SysConfigResponse {
        return try {
            executeWithLoadingAndReturn {
                fnOfficialApi.getSysConfig()
            }
        } catch (e: Exception) {
            logger.e("getSysConfigAndReturn error: ${e.message}")
            throw e
        }
    }

    fun resetAuthState() {
        _authUiState.value = UiState.Initial
    }

    fun resetSysConfigState() {
        _sysConfigUiState.value = UiState.Initial
    }
}
