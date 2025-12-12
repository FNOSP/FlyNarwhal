package com.jankinwu.fntv.client.data.store

import com.russhwolf.settings.Settings
import com.russhwolf.settings.set

object AppSettings {
    private val settings: Settings = Settings()

    var githubResourceProxyUrl: String
        get() = settings.getString("github_resource_proxy_url", "https://ghfast.top/")
        set(value) = settings.set("github_resource_proxy_url", value)
}
