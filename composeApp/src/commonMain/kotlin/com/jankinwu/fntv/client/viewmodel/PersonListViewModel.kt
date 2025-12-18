package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.PersonListResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class PersonListViewModel() : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _uiState = MutableStateFlow<UiState<PersonListResponse>>(UiState.Initial)
    val uiState: StateFlow<UiState<PersonListResponse>> = _uiState.asStateFlow()


    fun loadData(guid: String) {
        viewModelScope.launch {
            executeWithLoading(_uiState) {
                fnOfficialApi.personList(guid)
            }
        }
    }

    fun clearError() {
        _uiState.value = UiState.Initial
    }
}