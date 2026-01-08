package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.Danmaku
import com.jankinwu.fntv.client.data.network.FlyNarwhalApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class DanmakuViewModel : BaseViewModel() {

    private val flyNarwhalApi: FlyNarwhalApi by inject(FlyNarwhalApi::class.java)

    private val _danmakuList = MutableStateFlow<List<Danmaku>>(emptyList())
    val danmakuList: StateFlow<List<Danmaku>> = _danmakuList.asStateFlow()

    private val _isVisible = MutableStateFlow(true)
    val isVisible: StateFlow<Boolean> = _isVisible.asStateFlow()

    fun toggleVisibility() {
        _isVisible.value = !_isVisible.value
    }

    fun loadDanmaku(
        doubanId: String,
        episodeNumber: Int,
        episodeTitle: String,
        title: String,
        seasonNumber: Int,
        season: Boolean,
        guid: String,
        parentGuid: String
    ) {
        viewModelScope.launch {
            try {
                val map = flyNarwhalApi.getDanmaku(
                    doubanId,
                    episodeNumber,
                    episodeTitle,
                    title,
                    seasonNumber,
                    season,
                    guid,
                    parentGuid
                )
                _danmakuList.value = map[episodeNumber.toString()] ?: emptyList()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun clear() {
        _danmakuList.value = emptyList()
    }
}
