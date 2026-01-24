package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class PersonItemListQueryResponse(
    @param:JsonProperty("total")
    val total: Int,

    @param:JsonProperty("list")
    val list: List<PersonItemList>
)
