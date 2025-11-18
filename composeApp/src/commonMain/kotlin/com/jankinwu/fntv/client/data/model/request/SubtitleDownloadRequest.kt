package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class SubtitleDownloadRequest(
    @param:JsonProperty("media_guid")
    val mediaGuid: String,
    
    @param:JsonProperty("trim_id")
    val trimId: String,
    
    @param:JsonProperty("sync_download")
    val syncDownload: Int
)