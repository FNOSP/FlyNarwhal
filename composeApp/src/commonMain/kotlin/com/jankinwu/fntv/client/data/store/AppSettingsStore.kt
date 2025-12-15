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
}
