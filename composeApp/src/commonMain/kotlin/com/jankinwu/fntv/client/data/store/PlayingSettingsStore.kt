package com.jankinwu.fntv.client.data.store

import com.russhwolf.settings.Settings
import com.russhwolf.settings.set

object PlayingSettingsStore {
    private val settings: Settings = Settings()

    private fun scopedKey(rawKey: String): String {
        val guid = UserInfoMemoryCache.guid
        return if (guid.isNullOrBlank()) rawKey else "$guid::$rawKey"
    }

    data class VideoQuality(val resolution: String, val bitrate: Int?)

    fun saveQuality(resolution: String, bitrate: Int?) {
        settings[scopedKey("quality_resolution")] = resolution
        if (bitrate != null) {
            settings[scopedKey("quality_bitrate")] = bitrate
        } else {
            settings.remove(scopedKey("quality_bitrate"))
        }
    }

    fun getQuality(): VideoQuality? {
        val resolution = settings.getStringOrNull(scopedKey("quality_resolution")) ?: return null
        val bitrate = settings.getIntOrNull(scopedKey("quality_bitrate"))
        return VideoQuality(resolution, bitrate)
    }

    fun saveVolume(volume: Float) {
        settings[scopedKey("player_volume")] = volume
    }

    fun getVolume(): Float {
        return settings.getFloat(scopedKey("player_volume"), 1.0f)
    }
}
