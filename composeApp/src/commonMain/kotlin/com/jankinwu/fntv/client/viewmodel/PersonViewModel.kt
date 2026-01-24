package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.request.PersonItemListRequest
import com.jankinwu.fntv.client.data.model.response.PersonItemListQueryResponse
import com.jankinwu.fntv.client.data.model.response.PersonResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class PersonViewModel : BaseViewModel() {
    private val api: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _personUiState = MutableStateFlow<UiState<PersonResponse>>(UiState.Loading)
    val personUiState = _personUiState.asStateFlow()

    private val _actorItemsUiState =
        MutableStateFlow<UiState<PersonItemListQueryResponse>>(UiState.Loading)
    val actorItemsUiState = _actorItemsUiState.asStateFlow()

    private val _directorItemsUiState =
        MutableStateFlow<UiState<PersonItemListQueryResponse>>(UiState.Loading)
    val directorItemsUiState = _directorItemsUiState.asStateFlow()

    private val _screenplayItemsUiState =
        MutableStateFlow<UiState<PersonItemListQueryResponse>>(UiState.Loading)
    val screenplayItemsUiState = _screenplayItemsUiState.asStateFlow()

    fun loadData(guid: String) {
        viewModelScope.launch {
            loadPersonInfo(guid)
            loadPersonItems(guid, "Actor", _actorItemsUiState)
            loadPersonItems(guid, "Director", _directorItemsUiState)
            loadPersonItems(guid, "Screenplay", _screenplayItemsUiState)
        }
    }

    private suspend fun loadPersonInfo(guid: String) {
        executeWithLoading(_personUiState) {
            api.person(guid)
        }
    }

    private suspend fun loadPersonItems(
        guid: String,
        job: String,
        stateFlow: MutableStateFlow<UiState<PersonItemListQueryResponse>>
    ) {
        executeWithLoading(stateFlow) {
            val request = PersonItemListRequest(
                personGuid = guid,
                page = 1,
                pageSize = 200,
                job = job,
                sortColumn = "update_time",
                sortType = "desc"
            )
            api.personItemList(request)
        }
    }
}
