package com.jankinwu.fntv.client.utils

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle

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

fun parseSubtitleInlineTags(text: String): AnnotatedString {
    if (text.isBlank() || !text.contains('<')) return AnnotatedString(decodeSubtitleEntities(text))

    val input = decodeSubtitleEntities(text)
    val styleStack = ArrayDeque<Pair<String, SpanStyle>>()
    styleStack.addLast("root" to SpanStyle())

    return buildAnnotatedString {
        var i = 0
        while (i < input.length) {
            val ltIndex = input.indexOf('<', startIndex = i)
            if (ltIndex == -1) {
                appendWithStyle(input.substring(i), styleStack.last().second)
                break
            }

            if (ltIndex > i) {
                appendWithStyle(input.substring(i, ltIndex), styleStack.last().second)
            }

            val gtIndex = input.indexOf('>', startIndex = ltIndex + 1)
            if (gtIndex == -1) {
                appendWithStyle(input.substring(ltIndex), styleStack.last().second)
                break
            }

            val rawTag = input.substring(ltIndex + 1, gtIndex).trim()
            i = gtIndex + 1

            if (rawTag.isEmpty()) continue

            val isClosing = rawTag.startsWith("/")
            val normalized = rawTag.removePrefix("/").trim().removeSuffix("/").trim()
            val tagName = normalized.substringBefore(' ').substringBefore('.').lowercase()

            if (!isClosing && (tagName == "br")) {
                append("\n")
                continue
            }

            val isSupported = tagName == "b" || tagName == "i" || tagName == "u" || tagName == "c" || tagName == "v" || tagName == "lang"
            if (!isSupported) continue

            if (isClosing) {
                while (styleStack.size > 1) {
                    val last = styleStack.removeLast()
                    if (last.first == tagName) {
                        break
                    }
                }
                continue
            }

            val currentStyle = styleStack.last().second
            val nextStyle = when (tagName) {
                "b" -> currentStyle.merge(SpanStyle(fontWeight = FontWeight.Bold))
                "i" -> currentStyle.merge(SpanStyle(fontStyle = FontStyle.Italic))
                "u" -> currentStyle.merge(SpanStyle(textDecoration = mergeTextDecoration(currentStyle.textDecoration, TextDecoration.Underline)))
                else -> currentStyle
            }
            styleStack.addLast(tagName to nextStyle)
        }
    }
}

private fun AnnotatedString.Builder.appendWithStyle(text: String, style: SpanStyle) {
    if (text.isEmpty()) return
    withStyle(style) { append(text) }
}

private fun mergeTextDecoration(existing: TextDecoration?, add: TextDecoration): TextDecoration {
    return when (existing) {
        null -> add
        else -> TextDecoration.combine(listOf(existing, add))
    }
}

private fun decodeSubtitleEntities(text: String): String {
    if (!text.contains('&')) return text
    return text
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&")
        .replace("&nbsp;", " ")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
}
