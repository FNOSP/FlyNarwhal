package com.jankinwu.fntv.client.enums

enum class FnTvMediaType(val value: String, val description: String) {
    MOVIE("Movie", "电影"),
    TV("TV", "电视节目"),
    DIRECTORY("Directory", "目录"),
    VIDEO("Video", "其他"),
    EPISODE("Episode", "剧集"),
    SEASON("Season", "季"),
    ;

    companion object {
        fun getCommonly(): List<String> {
            return entries.map { it.value } - EPISODE.value - SEASON.value
        }

        fun getDescByValue(value: String): String {
            return getByValue(value).description
        }

        fun getByCategory(category: String): List<String> {
            return when (category) {
                Category.OTHERS.value -> {
                    listOf(DIRECTORY.value, VIDEO.value)
                }
                Category.MOVIE.value -> {
                    listOf(MOVIE.value)
                }
                Category.TV.value -> {
                    listOf(TV.value)
                }
                else -> {
                    getCommonly()
                }
            }
        }

        fun getByValue(value: String): FnTvMediaType {
            return entries.firstOrNull { it.value == value } ?: VIDEO
        }
    }
}
