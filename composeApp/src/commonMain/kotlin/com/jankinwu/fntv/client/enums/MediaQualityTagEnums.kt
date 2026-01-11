package com.jankinwu.fntv.client.enums

import flynarwhal.composeapp.generated.resources.Res
import flynarwhal.composeapp.generated.resources.dolby_atmos_logo
import flynarwhal.composeapp.generated.resources.dolby_surround_logo
import flynarwhal.composeapp.generated.resources.dolby_vision_logo
import flynarwhal.composeapp.generated.resources.dts_logo
import org.jetbrains.compose.resources.DrawableResource

enum class MediaQualityTagEnums(val tagName: String, val drawable: DrawableResource) {
    DTS("DTS", Res.drawable.dts_logo),
    DOLBY_ATMOS("DolbyAtmos", Res.drawable.dolby_atmos_logo),
    DOLBY_VISION("DolbyVision", Res.drawable.dolby_vision_logo),
    DOLBY_SURROUND("DolbySurround", Res.drawable.dolby_surround_logo),
    ;

    companion object {
        fun getDrawableByTagName(tagName: String): DrawableResource? {
            return entries.firstOrNull { it.tagName == tagName }?.drawable
        }
    }
}