package com.jankinwu.fntv.client.data.store

import com.russhwolf.settings.Settings
import com.russhwolf.settings.set

object AppSettingsStore {
    private val settings: Settings = Settings()

    private fun scopedKey(rawKey: String): String {
        val guid = UserInfoMemoryCache.guid
        return if (guid.isNullOrBlank()) rawKey else "$guid::$rawKey"
    }

    var githubResourceProxyUrl: String
        get() = settings.getString(scopedKey("github_resource_proxy_url"), "https://ghfast.top/")
        set(value) = settings.set(scopedKey("github_resource_proxy_url"), value)

    var isFollowingSystemTheme: Boolean
        get() = settings.getBoolean(scopedKey("is_following_system_theme"), false)
        set(value) = settings.set(scopedKey("is_following_system_theme"), value)

    var darkMode: Boolean
        get() = settings.getBoolean(scopedKey("dark_mode"), true)
        set(value) = settings.set(scopedKey("dark_mode"), value)

    var includePrerelease: Boolean
        get() = settings.getBoolean(scopedKey("include_prerelease"), true)
        set(value) = settings.set(scopedKey("include_prerelease"), value)

    var autoDownloadUpdates: Boolean
        get() = settings.getBoolean(scopedKey("auto_download_updates"), false)
        set(value) = settings.set(scopedKey("auto_download_updates"), value)

    var lastUpdateCheckTime: Long
        get() = settings.getLong(scopedKey("last_update_check_time"), 0L)
        set(value) = settings.set(scopedKey("last_update_check_time"), value)

    var windowWidth: Float
        get() = settings.getFloat(scopedKey("window_width"), 1280f)
        set(value) = settings.set(scopedKey("window_width"), value)

    var windowHeight: Float
        get() = settings.getFloat(scopedKey("window_height"), 720f)
        set(value) = settings.set(scopedKey("window_height"), value)

    var windowX: Float
        get() = settings.getFloat(scopedKey("window_x"), Float.NaN)
        set(value) = settings.set(scopedKey("window_x"), value)

    var windowY: Float
        get() = settings.getFloat(scopedKey("window_y"), Float.NaN)
        set(value) = settings.set(scopedKey("window_y"), value)

    var playerWindowWidth: Float
        get() = settings.getFloat(scopedKey("player_window_width"), 1280f)
        set(value) = settings.set(scopedKey("player_window_width"), value)

    var playerWindowHeight: Float
        get() = settings.getFloat(scopedKey("player_window_height"), 720f)
        set(value) = settings.set(scopedKey("player_window_height"), value)

    var playerWindowX: Float
        get() = settings.getFloat(scopedKey("player_window_x"), Float.NaN)
        set(value) = settings.set(scopedKey("player_window_x"), value)

    var playerWindowY: Float
        get() = settings.getFloat(scopedKey("player_window_y"), Float.NaN)
        set(value) = settings.set(scopedKey("player_window_y"), value)

    var playerIsFullscreen: Boolean
        get() = settings.getBoolean(scopedKey("player_is_fullscreen"), false)
        set(value) = settings.set(scopedKey("player_is_fullscreen"), value)

    var playerWindowAspectRatio: String
        get() = settings.getString(scopedKey("player_window_aspect_ratio"), "AUTO")
        set(value) = settings.set(scopedKey("player_window_aspect_ratio"), value)

    // 在允许自动伸缩窗口尺寸模式下手动补偿的窗口宽度
    var playerWindowWidthCompensation: Float
        get() = settings.getFloat(scopedKey("player_window_width_compensation"), -40f)
        set(value) = settings.set(scopedKey("player_window_width_compensation"), value)

    var skippedVersions: Set<String>
        get() = settings.getString(scopedKey("skipped_versions"), "").split(",").filter { it.isNotEmpty() }.toSet()
        set(value) = settings.set(scopedKey("skipped_versions"), value.joinToString(","))

    var autoPlay: Boolean
        get() = settings.getBoolean(scopedKey("auto_play"), true)
        set(value) = settings.set(scopedKey("auto_play"), value)

    var navigationDisplayMode: String
        get() = settings.getString(scopedKey("navigation_display_mode"), "Left")
        set(value) = settings.set(scopedKey("navigation_display_mode"), value)
}
