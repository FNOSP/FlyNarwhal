package com.jankinwu.fntv.client.utils

import androidx.compose.ui.text.AnnotatedString

data class SubtitleCue(
    val startTime: Long, // milliseconds
    val endTime: Long,   // milliseconds
    val text: AnnotatedString,
    val assProps: AssProperties? = null
)

data class AssProperties(
    val playResX: Int,
    val playResY: Int,
    val fontSize: Float,
    val alignment: Int = 2, // Default 2 (Bottom Center) in ASS
    val position: AssPosition? = null,
    val move: AssMove? = null,
    val fade: AssFade? = null,
    val rotationZ: Float? = null,
    val alpha: Float? = null,
    val clip: AssClip? = null
)

data class AssPosition(
    val x: Float,
    val y: Float
)

data class AssMove(
    val x1: Float,
    val y1: Float,
    val x2: Float,
    val y2: Float,
    val t1: Long? = null,
    val t2: Long? = null
)

data class AssFade(
    val t1: Long, // fade in duration
    val t2: Long  // fade out duration
)

data class AssClip(
    val x1: Float,
    val y1: Float,
    val x2: Float,
    val y2: Float
)
