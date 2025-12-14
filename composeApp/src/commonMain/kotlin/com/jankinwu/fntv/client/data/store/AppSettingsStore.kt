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
}
