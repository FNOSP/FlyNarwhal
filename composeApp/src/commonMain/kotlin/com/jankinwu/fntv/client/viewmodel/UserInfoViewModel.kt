package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.UserInfoResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import com.jankinwu.fntv.client.data.store.UserInfoMemoryCache
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class UserInfoViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<UserInfoResponse>>(UiState.Initial)
    val uiState: StateFlow<UiState<UserInfoResponse>> = _uiState.asStateFlow()

    fun loadUserInfo() {
        val cached = UserInfoMemoryCache.userInfo.value
        if (cached != null && cached.guid.isNotBlank()) {
            _uiState.value = UiState.Success(cached)
            return
        }
        if (_uiState.value is UiState.Loading) return

        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.userInfo().also { UserInfoMemoryCache.setUserInfo(it) }
            }
        }
    }

    suspend fun loadUserInfoAndWait(): UserInfoResponse {
        val cached = UserInfoMemoryCache.userInfo.value
        if (cached != null && cached.guid.isNotBlank()) return cached

        val result = executeWithLoadingAndReturn { fnOfficialApi.userInfo() }
        UserInfoMemoryCache.setUserInfo(result)
        return result
    }

    fun refresh() {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.userInfo().also { UserInfoMemoryCache.setUserInfo(it) }
            }
        }
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}
