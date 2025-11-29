package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class UserInfoResponse(
    @param:JsonProperty("guid")
    val guid: String,

    @param:JsonProperty("username")
    val username: String,

    @param:JsonProperty("lan")
    val lan: String,

    @param:JsonProperty("is_admin")
    val isAdmin: Int,

    @param:JsonProperty("last_login_time")
    val lastLoginTime: Int,

    @param:JsonProperty("sources")
    val userSources: List<UserSource>
) {
    companion object {
        val Empty = UserInfoResponse(
            guid = "",
            username = "",
            lan = "",
            isAdmin = 0,
            lastLoginTime = 0,
            userSources = emptyList()
        )
    }
}

data class UserSource(
    @param:JsonProperty("source")
    val source: String,

    @param:JsonProperty("source_id")
    val sourceId: String,

    @param:JsonProperty("source_name")
    val sourceName: String
)