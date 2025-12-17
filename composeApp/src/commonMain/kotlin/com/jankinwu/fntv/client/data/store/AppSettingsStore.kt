package com.jankinwu.fntv.client.data.store

import com.russhwolf.settings.Settings
import com.russhwolf.settings.set

object AppSettingsStore {
    private val settings: Settings = Settings()

    var githubResourceProxyUrl: String
        get() = settings.getString("github_resource_proxy_url", "https://ghfast.top/")
        set(value) = settings.set("github_resource_proxy_url", value)

    var isFollowingSystemTheme: Boolean
        get() = settings.getBoolean("is_following_system_theme", true)
        set(value) = settings.set("is_following_system_theme", value)

    var darkMode: Boolean
        get() = settings.getBoolean("dark_mode", true)
        set(value) = settings.set("dark_mode", value)

    var includePrerelease: Boolean
        get() = settings.getBoolean("include_prerelease", true)
        set(value) = settings.set("include_prerelease", value)

    var autoDownloadUpdates: Boolean
        get() = settings.getBoolean("auto_download_updates", false)
        set(value) = settings.set("auto_download_updates", value)

    var lastUpdateCheckTime: Long
        get() = settings.getLong("last_update_check_time", 0L)
        set(value) = settings.set("last_update_check_time", value)

    var windowWidth: Float
        get() = settings.getFloat("window_width", 1280f)
        set(value) = settings.set("window_width", value)

    var windowHeight: Float
        get() = settings.getFloat("window_height", 720f)
        set(value) = settings.set("window_height", value)

    var playerWindowWidth: Float
        get() = settings.getFloat("player_window_width", 1280f)
        set(value) = settings.set("player_window_width", value)

    var playerWindowHeight: Float
        get() = settings.getFloat("player_window_height", 720f)
        set(value) = settings.set("player_window_height", value)

    var playerIsFullscreen: Boolean
        get() = settings.getBoolean("player_is_fullscreen", false)
        set(value) = settings.set("player_is_fullscreen", value)

    var playerWindowAspectRatio: String
        get() = settings.getString("player_window_aspect_ratio", "AUTO")
        set(value) = settings.set("player_window_aspect_ratio", value)

    // 在允许自动伸缩窗口尺寸模式下手动补偿的窗口宽度
    var playerWindowWidthCompensation: Float
        get() = settings.getFloat("player_window_width_compensation", -40f)
        set(value) = settings.set("player_window_width_compensation", value)

    var skippedVersions: Set<String>
        get() = settings.getString("skipped_versions", "").split(",").filter { it.isNotEmpty() }.toSet()
        set(value) = settings.set("skipped_versions", value.joinToString(","))

    var autoPlay: Boolean
        get() = settings.getBoolean("auto_play", true)
        set(value) = settings.set("auto_play", value)
}
