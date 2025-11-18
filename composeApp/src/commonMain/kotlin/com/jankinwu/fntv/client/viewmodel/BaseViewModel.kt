package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.module

abstract class BaseViewModel : ViewModel() {
    // 通用的网络请求方法
    protected suspend fun <T> executeWithLoading(
        stateFlow: MutableStateFlow<UiState<T>>,
        operationId: String? = null,
        apiCall: suspend () -> T
    ) {
        stateFlow.value = UiState.Loading
        try {
            val result = apiCall()
            stateFlow.value = UiState.Success(result)
        } catch (e: Exception) {
            stateFlow.value = UiState.Error(e.message ?: "未知错误", operationId)
        }
    }

    protected suspend fun <T> executeWithLoadingAndReturn(
        apiCall: suspend () -> T
    ): T {
        try {
            return apiCall()
        } catch (e: Exception) {
            throw e // 重新抛出异常让调用者处理
        }
    }
}

// 通用的 UI 状态密封类
sealed class UiState<out T> {
    object Initial : UiState<Nothing>()
    object Loading : UiState<Nothing>()
    data class Success<T>(val data: T) : UiState<T>()
    data class Error(val message: String, val operationId: String? = null) : UiState<Nothing>()
}

val viewModelModule = module {
    viewModelOf (::MediaDbListViewModel)
    viewModelOf (::ItemListViewModel)
    viewModelOf (::PlayListViewModel)
    viewModelOf (::FavoriteViewModel)
    viewModelOf (::WatchedViewModel)
    viewModelOf (::TagViewModel)
    viewModelOf (::GenresViewModel)
    viewModelOf (::TagListViewModel)
    viewModelOf (::StreamListViewModel)
    viewModelOf (::PlayPlayViewModel)
    viewModelOf (::PlayInfoViewModel)
    viewModelOf (::ItemViewModel)
    viewModelOf (::PlayRecordViewModel)
    viewModelOf (::StreamViewModel)
    viewModelOf (::UserInfoViewModel)
    viewModelOf (::LoginViewModel)
    viewModelOf (::LogoutViewModel)
    viewModelOf (::PersonListViewModel)
    viewModelOf (::SubtitleUploadViewModel)
    viewModelOf (::SubtitleDeleteViewModel)
    viewModelOf (::AppAuthorizedDirViewModel)
    viewModelOf (::ServerPathViewModel)
    viewModelOf (::SubtitleMarkViewModel)
    viewModelOf (::SubtitleSearchViewModel)
    viewModelOf (::SubtitleDownloadViewModel)
}