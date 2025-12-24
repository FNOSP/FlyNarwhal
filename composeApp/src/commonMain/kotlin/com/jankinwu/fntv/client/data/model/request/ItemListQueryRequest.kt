package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty
import kotlinx.serialization.Serializable

@Immutable
@Serializable
data class ItemListQueryRequest (
    @get:JsonProperty("ancestor_guid")
    @param:JsonProperty("ancestor_guid")
    val ancestorGuid: String?,

    @get:JsonProperty("exclude_grouped_video")
    @param:JsonProperty("exclude_grouped_video")
    val excludeGroupedVideo: Int = 1,

    @get:JsonProperty("sort_type")
    @param:JsonProperty("sort_type")
    val sortType: String = "DESC",

    @get:JsonProperty("sort_column")
    @param:JsonProperty("sort_column")
    val sortColumn: String = "create_time",

    @get:JsonProperty("page_size")
    @param:JsonProperty("page_size")
    val pageSize: Int = 22,

    @get:JsonProperty("page")
    @param:JsonProperty("page")
    val page: Int = 1,

    val tags: Tags
)

data class Tags(

    val genres: Int? = null,

    val resolution : String? = null,

    @get:JsonProperty("color_range")
    @param:JsonProperty("color_range")
    val colorRange: String? = null,

    @get:JsonProperty("locate")
    @param:JsonProperty("locate")
    val locate: String? = null,

    val decade: String? = null,

    @get:JsonProperty("recognition_status")
    @param:JsonProperty("recognition_status")
    val recognitionStatus: String? = null,

    val watched: String? = null,

    @get:JsonProperty("audio_type")
    @param:JsonProperty("audio_type")
    val audioType: String? = null,

    @get:JsonProperty("type")
    @param:JsonProperty("type")
    val type: List<String>
) {
    class Builder(
        private var genres: Int? = null,
        private var resolution: String? = null,
        private var colorRange: String? = null,
        private var locate: String? = null,
        private var decade: String? = null,
        private var recognitionStatus: String? = null,
        private var watched: String? = null,
        private var audioType: String? = null,
        private var type: List<String> = emptyList()
    ) {
        fun genres(genres: Int?) = apply { this.genres = genres }
        fun resolution(resolution: String?) = apply { this.resolution = resolution }
        fun colorRange(colorRange: String?) = apply { this.colorRange = colorRange }
        fun locate(locate: String?) = apply { this.locate = locate }
        fun decade(decade: String?) = apply { this.decade = decade }
        fun recognitionStatus(recognitionStatus: String?) = apply { this.recognitionStatus = recognitionStatus }
        fun watched(watched: String?) = apply { this.watched = watched }
        fun audioType(audioType: String?) = apply { this.audioType = audioType }
        fun type(type: List<String>) = apply { this.type = type }

        fun build() = Tags(
            genres = genres,
            resolution = resolution,
            colorRange = colorRange,
            locate = locate,
            decade = decade,
            recognitionStatus = recognitionStatus,
            watched = watched,
            audioType = audioType,
            type = type
        )
    }
}