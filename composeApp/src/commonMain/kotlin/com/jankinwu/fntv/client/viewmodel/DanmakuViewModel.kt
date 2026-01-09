package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.response.Danmaku
import com.jankinwu.fntv.client.data.network.FlyNarwhalApi
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore
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

    private val _area = MutableStateFlow(PlayingSettingsStore.danmakuArea)
    val area: StateFlow<Float> = _area.asStateFlow()

    private val _opacity = MutableStateFlow(PlayingSettingsStore.danmakuOpacity)
    val opacity: StateFlow<Float> = _opacity.asStateFlow()

    private val _fontSize = MutableStateFlow(PlayingSettingsStore.danmakuFontSize)
    val fontSize: StateFlow<Float> = _fontSize.asStateFlow()

    private val _speed = MutableStateFlow(PlayingSettingsStore.danmakuSpeed)
    val speed: StateFlow<Float> = _speed.asStateFlow()

    private val _syncPlaybackSpeed = MutableStateFlow(PlayingSettingsStore.danmakuSyncPlaybackSpeed)
    val syncPlaybackSpeed: StateFlow<Boolean> = _syncPlaybackSpeed.asStateFlow()

    private val _debugEnabled = MutableStateFlow(PlayingSettingsStore.danmakuDebug)
    val debugEnabled: StateFlow<Boolean> = _debugEnabled.asStateFlow()

    fun toggleVisibility() {
        _isVisible.value = !_isVisible.value
    }

    fun updateArea(value: Float) {
        _area.value = value
        PlayingSettingsStore.danmakuArea = value
    }

    fun updateOpacity(value: Float) {
        _opacity.value = value
        PlayingSettingsStore.danmakuOpacity = value
    }

    fun updateFontSize(value: Float) {
        val clamped = value.coerceIn(0.5f, 1.7f)
        _fontSize.value = clamped
        PlayingSettingsStore.danmakuFontSize = clamped
    }

    fun updateSpeed(value: Float) {
        _speed.value = value
        PlayingSettingsStore.danmakuSpeed = value
    }

    fun updateSyncPlaybackSpeed(value: Boolean) {
        _syncPlaybackSpeed.value = value
        PlayingSettingsStore.danmakuSyncPlaybackSpeed = value
    }

    fun updateDebugEnabled(value: Boolean) {
        _debugEnabled.value = value
        PlayingSettingsStore.danmakuDebug = value
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
                val episodeKey = episodeNumber.toString()
                val list = map[episodeKey]
                    ?: map["default"]
                    ?: map.values.firstOrNull()
                    ?: emptyList()
                _danmakuList.value = list
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun clear() {
        _danmakuList.value = emptyList()
    }
}
