package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.SubtitleSettings
import com.jankinwu.fntv.client.data.model.request.SetConfigByItemRequest
import com.jankinwu.fntv.client.data.model.response.PlayConfig
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.koin.java.KoinJavaComponent.inject

class PlayerViewModel : ViewModel() {
    private val fnOfficialApi: FnOfficialApiImpl by inject(FnOfficialApiImpl::class.java)

    private val _playingInfoCache = MutableStateFlow<PlayingInfoCache?>(null)
    val playingInfoCache: StateFlow<PlayingInfoCache?> = _playingInfoCache.asStateFlow()

    private val _subtitleSettings = MutableStateFlow(SubtitleSettings())
    val subtitleSettings: StateFlow<SubtitleSettings> = _subtitleSettings.asStateFlow()

    fun updateSubtitleSettings(settings: SubtitleSettings) {
        _subtitleSettings.value = settings
    }

    fun updatePlayingInfo(playingInfoCache: PlayingInfoCache?) {
        // 当切换视频（guid不同）或清除播放信息时，重置字幕设置
        if (playingInfoCache?.itemGuid != _playingInfoCache.value?.itemGuid) {
            _subtitleSettings.value = SubtitleSettings()
        }
        _playingInfoCache.value = playingInfoCache
    }

    // Merged into the first updatePlayingInfo


    fun updateSubtitleList(subtitleStreams: List<SubtitleStream>, streamInfo: StreamResponse) {
        _playingInfoCache.update { current ->
            current?.copy(
                currentSubtitleStreamList = subtitleStreams,
                streamInfo = streamInfo
            )
        }
    }

    fun updateSkipConfig(skipOpening: Int, skipEnding: Int) {
        val currentInfo = _playingInfoCache.value ?: return
        val guid = currentInfo.playConfig?.guid ?: currentInfo.parentGuid ?: return

        val newConfig = currentInfo.playConfig?.copy(
            skipOpening = skipOpening,
            skipEnding = skipEnding
        ) ?: PlayConfig(guid = guid, skipOpening = skipOpening, skipEnding = skipEnding)

        _playingInfoCache.update { current ->
            current?.copy(playConfig = newConfig)
        }

        viewModelScope.launch {
            try {
                fnOfficialApi.setConfigByItem(
                    SetConfigByItemRequest(
                        guid = guid,
                        skipOpening = skipOpening,
                        skipEnding = skipEnding
                    )
                )
            } catch (_: Exception) {
                // Ignore error for now
            }
        }
    }
}
