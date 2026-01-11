package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class LoginRequest(
    @get:JsonProperty("username")
    @param:JsonProperty("username")
    val username: String,
    @get:JsonProperty("password")
    @param:JsonProperty("password")
    val password: String,
    @get:JsonProperty("app_name")
    @param:JsonProperty("app_name")
    val appName: String = "trimemedia-web",
) {
    override fun toString(): String {
        return "LoginRequest(username=$username, password=******, appName=$appName)"
    }
}
