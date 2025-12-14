package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.ViewModel
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class PlayerViewModel : ViewModel() {
    private val _playingInfoCache = MutableStateFlow<PlayingInfoCache?>(null)
    val playingInfoCache: StateFlow<PlayingInfoCache?> = _playingInfoCache.asStateFlow()

    fun updatePlayingInfo(info: PlayingInfoCache?) {
        _playingInfoCache.value = info
    }

    fun updateSubtitleList(subtitleStreams: List<SubtitleStream>, streamInfo: StreamResponse) {
        _playingInfoCache.update { current ->
            current?.copy(
                currentSubtitleStreamList = subtitleStreams,
                streamInfo = streamInfo
            )
        }
    }
}
