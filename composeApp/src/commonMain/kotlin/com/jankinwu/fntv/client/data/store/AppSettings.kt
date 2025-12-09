package com.jankinwu.fntv.client.data.store

import com.russhwolf.settings.Settings
import com.russhwolf.settings.set

object AppSettings {
    private val settings: Settings = Settings()

    var updateProxyUrl: String
        get() = settings.getString("update_proxy_url", "https://ghfast.top/")
        set(value) = settings.set("update_proxy_url", value)
}
