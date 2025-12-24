package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class SubtitleDownloadRequest(
    @get:JsonProperty("media_guid")
    @param:JsonProperty("media_guid")
    val mediaGuid: String,
    
    @get:JsonProperty("trim_id")
    @param:JsonProperty("trim_id")
    val trimId: String,
    
    @get:JsonProperty("sync_download")
    @param:JsonProperty("sync_download")
    val syncDownload: Int
)