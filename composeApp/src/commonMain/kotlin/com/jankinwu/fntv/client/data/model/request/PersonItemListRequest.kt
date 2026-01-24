package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class PersonItemListRequest(
    @get:JsonProperty("person_guid")
    @param:JsonProperty("person_guid")
    val personGuid: String,

    @get:JsonProperty("page")
    @param:JsonProperty("page")
    val page: Int,

    @get:JsonProperty("page_size")
    @param:JsonProperty("page_size")
    val pageSize: Int,

    @get:JsonProperty("job")
    @param:JsonProperty("job")
    val job: String,

    @get:JsonProperty("sort_column")
    @param:JsonProperty("sort_column")
    val sortColumn: String,

    @get:JsonProperty("sort_type")
    @param:JsonProperty("sort_type")
    val sortType: String
)