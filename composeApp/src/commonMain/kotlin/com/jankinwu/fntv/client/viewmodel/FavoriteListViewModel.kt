package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.request.ItemListQueryRequest
import com.jankinwu.fntv.client.data.model.request.Tags
import com.jankinwu.fntv.client.data.model.response.ItemListQueryResponse
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

data class FavoriteTabKey(
    val tab: String,
    val tags: Tags,
    val sortColumn: String,
    val sortOrder: String
)

class FavoriteListViewModel : BaseViewModel() {

    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _tabStates = MutableStateFlow<Map<FavoriteTabKey, UiState<ItemListQueryResponse>>>(emptyMap())
    val tabStates: StateFlow<Map<FavoriteTabKey, UiState<ItemListQueryResponse>>> = _tabStates.asStateFlow()

    private data class PageInfo(
        val currentPage: Int,
        val isLastPage: Boolean
    )

    private val pageInfo = mutableMapOf<FavoriteTabKey, PageInfo>()

    fun loadDataForKey(
        key: FavoriteTabKey,
        pageSize: Int = 50,
        page: Int = 1,
        force: Boolean = false
    ) {
        val existingState = _tabStates.value[key]
        if (!force && (existingState is UiState.Success || existingState is UiState.Loading)) {
            return
        }
        viewModelScope.launch {
            _tabStates.value = _tabStates.value + (key to UiState.Loading)
            try {
                val request = ItemListQueryRequest(
                    ancestorGuid = null,
                    tags = key.tags,
                    pageSize = pageSize,
                    page = page,
                    sortColumn = key.sortColumn,
                    sortType = key.sortOrder
                )
                val result = fnOfficialApi.getFavoriteList(request)
                pageInfo[key] = PageInfo(page, result.list.size < pageSize)
                _tabStates.value = _tabStates.value + (key to UiState.Success(result))
            } catch (e: Exception) {
                _tabStates.value = _tabStates.value + (key to UiState.Error(e.message ?: "未知错误", exception = e))
            }
        }
    }

    fun loadMoreDataForKey(
        key: FavoriteTabKey,
        pageSize: Int = 50,
        isLoadMore: Boolean = false
    ) {
        if (!isLoadMore) return
        val currentInfo = pageInfo[key]
        if (currentInfo?.isLastPage == true) return
        val nextPage = (currentInfo?.currentPage ?: 1) + 1
        viewModelScope.launch {
            try {
                val request = ItemListQueryRequest(
                    ancestorGuid = null,
                    tags = key.tags,
                    pageSize = pageSize,
                    page = nextPage,
                    sortColumn = key.sortColumn,
                    sortType = key.sortOrder
                )
                val result = fnOfficialApi.getFavoriteList(request)
                pageInfo[key] = PageInfo(nextPage, result.list.size < pageSize)
                val currentData = (_tabStates.value[key] as? UiState.Success)?.data
                if (currentData != null) {
                    val mergedList = currentData.list + result.list
                    val mergedResult = result.copy(list = mergedList)
                    _tabStates.value = _tabStates.value + (key to UiState.Success(mergedResult))
                } else {
                    _tabStates.value = _tabStates.value + (key to UiState.Success(result))
                }
            } catch (e: Exception) {
                _tabStates.value = _tabStates.value + (key to UiState.Error(e.message ?: "未知错误", exception = e))
            }
        }
    }

    fun isLastPageFor(key: FavoriteTabKey): Boolean {
        return pageInfo[key]?.isLastPage ?: false
    }
}
