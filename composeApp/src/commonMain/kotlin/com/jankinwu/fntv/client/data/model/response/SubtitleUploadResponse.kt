package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class SubtitleUploadResponse(
    @param:JsonProperty("media_guid")
    val mediaGuid: String,

    @param:JsonProperty("title")
    val title: String,

    @param:JsonProperty("guid")
    val guid: String,

    @param:JsonProperty("codec_name")
    val codecName: String,

    @param:JsonProperty("codec_type")
    val codecType: String,

    @param:JsonProperty("language")
    val language: String,

    @param:JsonProperty("forced")
    val forced: Int,

    @param:JsonProperty("index")
    val index: Int,

    @param:JsonProperty("is_default")
    val isDefault: Int,

    @param:JsonProperty("is_external")
    val isExternal: Int,

    @param:JsonProperty("format")
    val format: String,

    @param:JsonProperty("trim_id")
    val trimId: String,

    @param:JsonProperty("source_id")
    val sourceId: String,

    @param:JsonProperty("Source")
    val source: String,

    @param:JsonProperty("create_time")
    val createTime: Long,

    @param:JsonProperty("update_time")
    val updateTime: Long,

    @param:JsonProperty("extra_file")
    val extraFile: Int,

    @param:JsonProperty("is_bitmap")
    val isBitmap: Int,

    @param:JsonProperty("file_size")
    val fileSize: Int
)
