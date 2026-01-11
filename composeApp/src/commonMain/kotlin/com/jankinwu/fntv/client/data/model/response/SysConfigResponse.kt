package com.jankinwu.fntv.client.data.model.response

import com.fasterxml.jackson.annotation.JsonProperty
import kotlinx.serialization.Serializable

@Serializable
data class SysConfigResponse(

    @get:JsonProperty("initialized")
    @param:JsonProperty("initialized")
    val initialized: Boolean,

    @get:JsonProperty("region")
    @param:JsonProperty("region")
    val region: String? = null,

    @get:JsonProperty("server_name")
    @param:JsonProperty("server_name")
    val serverName: String,

    @get:JsonProperty("server_guid")
    @param:JsonProperty("server_guid")
    val serverGuid: String,

    @get:JsonProperty("nas_oauth")
    @param:JsonProperty("nas_oauth")
    val nasOauth: NasOauthConfig
)

@Serializable
data class NasOauthConfig(

    @get:JsonProperty("app_id")
    @param:JsonProperty("app_id")
    val appId: String,

    @get:JsonProperty("url")
    @param:JsonProperty("url")
    val url: String
)
