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

    data class PipWindowData(val x: Int, val y: Int, val width: Int, val height: Int)

    fun savePipWindowData(x: Int, y: Int, width: Int, height: Int) {
        settings[scopedKey("pip_window_x")] = x
        settings[scopedKey("pip_window_y")] = y
        settings[scopedKey("pip_window_width")] = width
        settings[scopedKey("pip_window_height")] = height
    }

    fun getPipWindowData(): PipWindowData? {
        val x = settings.getIntOrNull(scopedKey("pip_window_x")) ?: return null
        val y = settings.getIntOrNull(scopedKey("pip_window_y")) ?: return null
        val width = settings.getIntOrNull(scopedKey("pip_window_width")) ?: return null
        val height = settings.getIntOrNull(scopedKey("pip_window_height")) ?: return null
        return PipWindowData(x, y, width, height)
    }

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

    var autoPlay: Boolean
        get() = settings.getBoolean(scopedKey("auto_play"), true)
        set(value) = settings.set(scopedKey("auto_play"), value)

    var playerIsFullscreen: Boolean
        get() = settings.getBoolean(scopedKey("player_is_fullscreen"), false)
        set(value) = settings.set(scopedKey("player_is_fullscreen"), value)

    var playerWindowAspectRatio: String
        get() = settings.getString(scopedKey("player_window_aspect_ratio"), "AUTO")
        set(value) = settings.set(scopedKey("player_window_aspect_ratio"), value)

    var playerWindowWidthCompensation: Float
        get() = settings.getFloat(scopedKey("player_window_width_compensation"), -40f)
        set(value) = settings.set(scopedKey("player_window_width_compensation"), value)

    data class PlayerScreenSize(val width: Float, val height: Float)

    fun saveLastPlayerScreenSize(width: Float, height: Float) {
        if (width.isNaN() || height.isNaN() || width <= 0f || height <= 0f) return
        settings[scopedKey("last_player_screen_width")] = width
        settings[scopedKey("last_player_screen_height")] = height
    }

    fun getLastPlayerScreenSize(): PlayerScreenSize? {
        val width = settings.getFloatOrNull(scopedKey("last_player_screen_width")) ?: return null
        val height = settings.getFloatOrNull(scopedKey("last_player_screen_height")) ?: return null
        return PlayerScreenSize(width, height)
    }

    var smartSkipEnabled: Boolean
        get() = settings.getBoolean(scopedKey("smart_skip_enabled"), true)
        set(value) = settings.set(scopedKey("smart_skip_enabled"), value)

    var danmakuArea: Float
        get() = settings.getFloat(scopedKey("danmaku_area"), 1.0f)
        set(value) = settings.set(scopedKey("danmaku_area"), value)

    var danmakuOpacity: Float
        get() = settings.getFloat(scopedKey("danmaku_opacity"), 1.0f)
        set(value) = settings.set(scopedKey("danmaku_opacity"), value)

    var danmakuFontSize: Float
        get() = settings.getFloat(scopedKey("danmaku_font_size"), 1.0f)
        set(value) = settings.set(scopedKey("danmaku_font_size"), value)

    var danmakuDebug: Boolean
        get() = settings.getBoolean(scopedKey("danmaku_debug"), false)
        set(value) = settings.set(scopedKey("danmaku_debug"), value)

    var danmakuSpeed: Float
        get() = settings.getFloat(scopedKey("danmaku_speed"), 1.0f)
        set(value) = settings.set(scopedKey("danmaku_speed"), value)

    var danmakuSyncPlaybackSpeed: Boolean
        get() = settings.getBoolean(scopedKey("danmaku_sync_playback_speed"), false)
        set(value) = settings.set(scopedKey("danmaku_sync_playback_speed"), value)
}
