package com.jankinwu.fntv.client.data.store

import com.russhwolf.settings.Settings
import com.russhwolf.settings.set

object PlayingSettingsStore {
    private val settings: Settings = Settings()

    data class VideoQuality(val resolution: String, val bitrate: Int?)

    fun saveQuality(resolution: String, bitrate: Int?) {
        settings["quality_resolution"] = resolution
        if (bitrate != null) {
            settings["quality_bitrate"] = bitrate
        } else {
            settings.remove("quality_bitrate")
        }
    }

    fun getQuality(): VideoQuality? {
        val resolution = settings.getStringOrNull("quality_resolution") ?: return null
        val bitrate = settings.getIntOrNull("quality_bitrate")
        return VideoQuality(resolution, bitrate)
    }

    fun saveVolume(volume: Float) {
        settings["player_volume"] = volume
    }

    fun getVolume(): Float {
        return settings.getFloat("player_volume", 1.0f)
    }
}