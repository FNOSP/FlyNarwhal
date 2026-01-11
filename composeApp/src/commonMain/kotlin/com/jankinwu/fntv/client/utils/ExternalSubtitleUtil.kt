package com.jankinwu.fntv.client.utils

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.store.AccountDataCache
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.coroutines.cancellation.CancellationException

data class AssStyle(
    val name: String,
    val fontName: String,
    val fontSize: Float,
    val primaryColor: Color,
    val secondaryColor: Color,
    val outlineColor: Color,
    val backColor: Color,
    val bold: Int, // 0/1/-1 or specific weight
    val italic: Boolean,
    val underline: Boolean,
    val strikeOut: Boolean,
    val alignment: Int = 2,
    val outlineWidth: Float = 0f,
    val shadowDistance: Float = 0f
) {
    companion object {
        val Default = AssStyle(
            name = "Default",
            fontName = "Arial",
            fontSize = 20f,
            primaryColor = Color.White,
            secondaryColor = Color.Red,
            outlineColor = Color.Black,
            backColor = Color.Black,
            bold = 0,
            italic = false,
            underline = false,
            strikeOut = false,
            alignment = 2,
            outlineWidth = 2f,
            shadowDistance = 0f
        )
    }
}

class ExternalSubtitleUtil(
    private val client: HttpClient,
    private val subtitleStream: SubtitleStream
) {
    private val logger = Logger.withTag("ExternalSubtitleUtil")
    private val cues = mutableListOf<SubtitleCue>()
    private val styles = mutableMapOf<String, AssStyle>()
    private var isInitialized = false
    private var playResY = 288 // Default ASS height if not specified
    private var playResX = 0 // Will be parsed

    suspend fun initialize() {
        if (isInitialized) return
        withContext(Dispatchers.IO) {
            try {
                val subtitleUrl = "${AccountDataCache.getProxyBaseUrl()}/v/api/v1/subtitle/dl/${subtitleStream.guid}"
                
                val response = client.get(subtitleUrl)
                val content = response.bodyAsText()
                
                val parsedCues = when (subtitleStream.format.lowercase()) {
                    "srt" -> parseSrt(content)
                    "ass", "ssa" -> parseAss(content)
                    "vtt" -> parseVtt(content)
                    else -> emptyList()
                }
                
                cues.clear()
                cues.addAll(parsedCues)
                cues.sortBy { it.startTime }
                isInitialized = true
                logger.i { "Initialized ExternalSubtitleUtil with ${cues.size} cues (${subtitleStream.format})" }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                logger.e(e) { "Failed to initialize ExternalSubtitleUtil" }
            }
        }
    }

    fun getCurrentSubtitle(currentPositionMs: Long): List<SubtitleCue> {
        if (cues.isEmpty()) return emptyList()

        var low = 0
        var high = cues.size - 1
        var index = -1

        // Find the last cue that starts before or at currentPositionMs
        while (low <= high) {
            val mid = (low + high) / 2
            if (cues[mid].startTime <= currentPositionMs) {
                index = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        if (index == -1) return emptyList()

        val result = mutableListOf<SubtitleCue>()

        // Iterate backwards from the found index
        for (i in index downTo 0) {
            val cue = cues[i]
            if (currentPositionMs < cue.endTime) {
                result.add(cue)
            }

            // Optimization: Stop if we go back too far (e.g., 5 minutes)
            if (currentPositionMs - cue.startTime > 300000) {
                break
            }
        }

        return result.reversed().distinctBy { it.text to it.assProps }
    }

    private fun parseSrt(content: String): List<SubtitleCue> {
        val cues = mutableListOf<SubtitleCue>()
        val text = content.replace("\r\n", "\n").replace("\r", "\n")
        val blocks = text.split("\n\n")

        for (block in blocks) {
            val lines = block.trim().lines()
            if (lines.size >= 3) {
                val timeCodeLine = lines.find { it.contains("-->") } ?: continue
                val timeParts = timeCodeLine.split("-->")
                if (timeParts.size != 2) continue

                val startTime = parseSrtTime(timeParts[0].trim())
                val endTime = parseSrtTime(timeParts[1].trim())
                
                val timeCodeIndex = lines.indexOf(timeCodeLine)
                if (timeCodeIndex < 0 || timeCodeIndex >= lines.size - 1) continue
                
                val textLines = lines.subList(timeCodeIndex + 1, lines.size)
                val subtitleText = textLines.joinToString("\n")
                    .replace(Regex("<.*?>"), "") 

                if (subtitleText.isNotBlank()) {
                    cues.add(
                        SubtitleCue(
                            startTime = startTime,
                            endTime = endTime,
                            text = AnnotatedString(subtitleText),
                            assProps = null
                        )
                    )
                }
            }
        }
        return cues
    }

    private fun parseSrtTime(timeStr: String): Long {
        try {
            val parts = timeStr.replace(',', '.').split(':')
            if (parts.size == 3) {
                val hours = parts[0].toLong()
                val minutes = parts[1].toLong()
                val secondsParts = parts[2].split('.')
                val seconds = secondsParts[0].toLong()
                val millis = if (secondsParts.size > 1) secondsParts[1].padEnd(3, '0').take(3).toLong() else 0L
                
                return (hours * 3600000) + (minutes * 60000) + (seconds * 1000) + millis
            }
        } catch (_: Exception) {
            // Ignore malformed time
        }
        return 0L
    }

    private fun parseAss(content: String): List<SubtitleCue> {
        val cues = mutableListOf<SubtitleCue>()
        val lines = content.lines()
        val formatIndexMap = mutableMapOf<String, Int>()
        val styleFormatIndexMap = mutableMapOf<String, Int>()
        
        var section = ""
        
        for (line in lines) {
            val trimmed = line.trim()
            if (trimmed.startsWith("[")) {
                section = trimmed
                continue
            }
            
            if (section.equals("[Script Info]", ignoreCase = true)) {
                if (trimmed.startsWith("PlayResY:", ignoreCase = true)) {
                    playResY = trimmed.substringAfter(":").trim().toIntOrNull() ?: 288
                } else if (trimmed.startsWith("PlayResX:", ignoreCase = true)) {
                    playResX = trimmed.substringAfter(":").trim().toIntOrNull() ?: 0
                }
            } else if (section.equals("[V4+ Styles]", ignoreCase = true)) {
                if (trimmed.startsWith("Format:", ignoreCase = true)) {
                    val formatLine = trimmed.substringAfter("Format:").trim()
                    val parts = formatLine.split(",").map { it.trim().lowercase() }
                    parts.forEachIndexed { index, name -> styleFormatIndexMap[name] = index }
                } else if (trimmed.startsWith("Style:", ignoreCase = true)) {
                    val styleLine = trimmed.substringAfter("Style:").trim()
                    val formatCount = styleFormatIndexMap.size
                    if (formatCount > 0) {
                        val parts = styleLine.split(",", limit = formatCount).map { it.trim() }
                        if (parts.size >= formatCount) {
                            val name = parts.getOrNull(styleFormatIndexMap["name"] ?: -1) ?: "Default"
                            val fontName = parts.getOrNull(styleFormatIndexMap["fontname"] ?: -1) ?: "Arial"
                            val fontSize = parts.getOrNull(styleFormatIndexMap["fontsize"] ?: -1)?.toFloatOrNull() ?: 20f
                            val primaryColor = parseAssColor(parts.getOrNull(styleFormatIndexMap["primarycolour"] ?: -1) ?: "")
                            val secondaryColor = parseAssColor(parts.getOrNull(styleFormatIndexMap["secondarycolour"] ?: -1) ?: "")
                            val outlineColor = parseAssColor(parts.getOrNull(styleFormatIndexMap["outlinecolour"] ?: -1) ?: "")
                            val backColor = parseAssColor(parts.getOrNull(styleFormatIndexMap["backcolour"] ?: -1) ?: "")
                            
                            val boldRaw = parts.getOrNull(styleFormatIndexMap["bold"] ?: -1) ?: "0"
                            val bold = when (boldRaw) {
                                "-1" -> 1 // Standard ASS True
                                "1" -> 1  // Standard ASS True
                                "0" -> 0  // Standard ASS False
                                else -> boldRaw.toIntOrNull() ?: 0 // Specific weight or 0
                            }
                            
                            val italic = (parts.getOrNull(styleFormatIndexMap["italic"] ?: -1) ?: "0") != "0"
                            val underline = (parts.getOrNull(styleFormatIndexMap["underline"] ?: -1) ?: "0") != "0"
                            val strikeOut = (parts.getOrNull(styleFormatIndexMap["strikeout"] ?: -1) ?: "0") != "0"
                            val alignment = parts.getOrNull(styleFormatIndexMap["alignment"] ?: -1)?.toIntOrNull() ?: 2
                            val outlineWidth = parts.getOrNull(styleFormatIndexMap["outline"] ?: -1)?.toFloatOrNull() ?: 0f
                            val shadowDistance = parts.getOrNull(styleFormatIndexMap["shadow"] ?: -1)?.toFloatOrNull() ?: 0f
                            
                            val style = AssStyle(
                                name, fontName, fontSize, primaryColor, secondaryColor, outlineColor, backColor,
                                bold, italic, underline, strikeOut, alignment, outlineWidth, shadowDistance
                            )
                            styles[name] = style
                        }
                    }
                }
            } else if (section.equals("[Events]", ignoreCase = true)) {
                if (trimmed.startsWith("Format:", ignoreCase = true)) {
                    val formatLine = trimmed.substringAfter("Format:").trim()
                    val parts = formatLine.split(",").map { it.trim().lowercase() }
                    parts.forEachIndexed { index, name -> formatIndexMap[name] = index }
                } else if (trimmed.startsWith("Dialogue:", ignoreCase = true)) {
                    val dialogueLine = trimmed.substringAfter("Dialogue:").trim()
                    val formatCount = formatIndexMap.size
                    if (formatCount > 0) {
                        val parts = dialogueLine.split(",", limit = formatCount).map { it.trim() }
                        if (parts.size == formatCount) {
                            val startIndex = formatIndexMap["start"] ?: -1
                            val endIndex = formatIndexMap["end"] ?: -1
                            val textIndex = formatIndexMap["text"] ?: -1
                            val styleIndex = formatIndexMap["style"] ?: -1
                            
                            if (startIndex != -1 && endIndex != -1 && textIndex != -1) {
                                val startTime = parseAssTime(parts[startIndex])
                                val endTime = parseAssTime(parts[endIndex])
                                val textRaw = parts[textIndex]
                                val styleName = if (styleIndex != -1) parts[styleIndex] else "Default"
                                
                                val baseStyle = styles[styleName] ?: styles["Default"] ?: AssStyle.Default
                                val move = parseAssMove(textRaw)
                                val pos = parseAssPos(textRaw)
                                val align = parseAssAlign(textRaw) ?: baseStyle.alignment
                                val fade = parseAssFade(textRaw)
                                val rotationZ = parseAssRotation(textRaw)
                                val alpha = parseAssAlpha(textRaw)
                                val clip = parseAssClip(textRaw)
                                
                                val assProps = AssProperties(
                                    playResX = playResX,
                                    playResY = playResY,
                                    fontSize = baseStyle.fontSize,
                                    alignment = align,
                                    position = pos,
                                    move = move,
                                    fade = fade,
                                    rotationZ = rotationZ,
                                    alpha = alpha,
                                    clip = clip
                                )

                                val annotatedString = parseAssText(textRaw, styleName)
                                
                                if (annotatedString.isNotEmpty()) {
                                    cues.add(SubtitleCue(startTime, endTime, annotatedString, assProps))
                                }
                            }
                        }
                    }
                }
            }
        }
        return cues
    }

    private fun parseAssMove(text: String): AssMove? {
        // \move(x1,y1,x2,y2) or \move(x1,y1,x2,y2,t1,t2)
        // Allow spaces after commas
        val regex = Regex("""\\move\(\s*([\d.-]+)\s*,\s*([\d.-]+)\s*,\s*([\d.-]+)\s*,\s*([\d.-]+)\s*(?:,\s*([\d.-]+)\s*,\s*([\d.-]+)\s*)?\)""")
        val match = regex.find(text) ?: return null
        val (x1, y1, x2, y2) = match.destructured
        val t1 = match.groups[5]?.value?.toLongOrNull()
        val t2 = match.groups[6]?.value?.toLongOrNull()
        return AssMove(x1.toFloat(), y1.toFloat(), x2.toFloat(), y2.toFloat(), t1, t2)
    }

    private fun parseAssPos(text: String): AssPosition? {
        // \pos(x,y)
        // Allow spaces after commas
        val regex = Regex("""\\pos\(\s*([\d.-]+)\s*,\s*([\d.-]+)\s*\)""")
        val match = regex.find(text) ?: return null
        val (x, y) = match.destructured
        return AssPosition(x.toFloat(), y.toFloat())
    }

    private fun parseAssAlign(text: String): Int? {
        // \anX
        val regex = Regex("""\\an(\d)""")
        val match = regex.find(text)
        return match?.groupValues?.get(1)?.toIntOrNull()
    }

    private fun parseAssFade(text: String): AssFade? {
        // \fad(t1,t2)
        val regex = Regex("""\\fad\(\s*(\d+)\s*,\s*(\d+)\s*\)""")
        val match = regex.find(text) ?: return null
        val (t1, t2) = match.destructured
        return AssFade(t1.toLong(), t2.toLong())
    }

    private fun parseAssRotation(text: String): Float? {
        // \frz<angle> or \fr<angle>
        val regex = Regex("""\\frz?(-?[\d.]+)""")
        val match = regex.find(text)
        return match?.groupValues?.get(1)?.toFloatOrNull()
    }

    private fun parseAssAlpha(text: String): Float? {
        // \alpha&H<aa>&
        val regex = Regex("""\\alpha&H([0-9a-fA-F]{2})&""")
        val match = regex.find(text)
        val hex = match?.groupValues?.get(1) ?: return null
        // 00 = opaque (1.0), FF = transparent (0.0)
        val alphaVal = hex.toIntOrNull(16) ?: return null
        return 1f - (alphaVal / 255f)
    }

    private fun parseAssClip(text: String): AssClip? {
        // \clip(x1,y1,x2,y2)
        val regex = Regex("""\\clip\(\s*([\d.-]+)\s*,\s*([\d.-]+)\s*,\s*([\d.-]+)\s*,\s*([\d.-]+)\s*\)""")
        val match = regex.find(text) ?: return null
        val (x1, y1, x2, y2) = match.destructured
        return AssClip(x1.toFloat(), y1.toFloat(), x2.toFloat(), y2.toFloat())
    }

    private fun parseAssText(textRaw: String, styleName: String): AnnotatedString {
        val baseStyle = styles[styleName] ?: styles["Default"] ?: AssStyle.Default
        
        return buildAnnotatedString {
            // Replace \h with space, \n with space, \N with newline
            val cleanText = textRaw
                .replace("\\h", " ")
                .replace("\\n", " ")
                .replace("\\N", "\n")
            
            val tagRegex = Regex("\\{.*?\\}")
            var currentIndex = 0
            
            // State variables
            var boldWeight = baseStyle.bold
            var italic = baseStyle.italic
            var underline = baseStyle.underline
            var strikeOut = baseStyle.strikeOut
            var color = baseStyle.primaryColor
            var secondaryColor = baseStyle.secondaryColor
            var outlineColor = baseStyle.outlineColor
            var shadowColor = baseStyle.backColor
            var outlineWidth = baseStyle.outlineWidth
            var shadowDistance = baseStyle.shadowDistance
            var blurRadius = 0f

            tagRegex.findAll(cleanText).forEach { match ->
                // Append text before tag
                if (match.range.first > currentIndex) {
                    val segment = cleanText.substring(currentIndex, match.range.first)
                    
                    pushStringAnnotation("AssOutlineWidth", outlineWidth.toString())
                    pushStringAnnotation("AssOutlineColor", outlineColor.value.toString())
                    pushStringAnnotation("AssShadowDistance", shadowDistance.toString())
                    pushStringAnnotation("AssShadowColor", shadowColor.value.toString())
                    pushStringAnnotation("AssBlurRadius", blurRadius.toString())
                    
                    withStyle(
                        SpanStyle(
                            color = color,
                            fontWeight = resolveFontWeight(boldWeight),
                            fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
                            textDecoration = combineTextDecoration(underline, strikeOut),
                            shadow = null // Shadow handled by annotations in AssStyledText
                        )
                    ) {
                        append(segment)
                    }
                    pop()
                    pop()
                    pop()
                    pop()
                    pop()
                }
                
                // Parse tag
                val tagContent = match.value.removePrefix("{").removeSuffix("}")
                val tags = tagContent.split("\\")
                for (tag in tags) {
                    if (tag.isEmpty()) continue
                    
                    if (tag.startsWith("bord")) {
                        outlineWidth = tag.removePrefix("bord").toFloatOrNull() ?: 0f
                    } else if (tag.startsWith("shad")) {
                        shadowDistance = tag.removePrefix("shad").toFloatOrNull() ?: 0f
                    } else if (tag.startsWith("blur")) {
                        blurRadius = tag.removePrefix("blur").toFloatOrNull() ?: 0f
                    } else if (tag.startsWith("be")) {
                        blurRadius = tag.removePrefix("be").toFloatOrNull() ?: 0f
                    } else if (tag.startsWith("b")) {
                        // Ensure it's not 'be' or 'blur'
                         if (!tag.startsWith("be") && !tag.startsWith("blur")) {
                            val param = tag.removePrefix("b")
                             boldWeight = if (param.isEmpty() || param == "1") 1
                             else if (param == "0") 0
                             else {
                                 // \b<weight>
                                 param.toIntOrNull() ?: 0
                             }
                        }
                    } else if (tag.startsWith("i")) {
                         italic = tag.removePrefix("i") != "0"
                    } else if (tag.startsWith("u")) {
                         underline = tag.removePrefix("u") != "0"
                    } else if (tag.startsWith("s")) {

                        // Also check for 'sc' (Scale constraint?) - ASS tags: \scx, \scy.
                        if (!tag.startsWith("sc")) {
                            strikeOut = tag.removePrefix("s") != "0"
                        }
                    } else if (tag.startsWith("1c") || (tag.startsWith("c") && !tag.startsWith("clip"))) {
                        // Primary Color
                        val colorStr = tag.substringAfter("&H").substringBefore("&")
                        if (colorStr.isNotEmpty()) {
                            val newColor = parseAssColorString(colorStr)
                            // If the tag only provides RGB (length <= 6), preserve the existing alpha
                            color = if (colorStr.length <= 6) newColor.copy(alpha = color.alpha) else newColor
                        } else if (tag == "c" || tag == "1c") {
                            color = baseStyle.primaryColor
                        }
                    } else if (tag.startsWith("2c")) {
                        // Secondary Color
                        val colorStr = tag.substringAfter("&H").substringBefore("&")
                        if (colorStr.isNotEmpty()) {
                            val newColor = parseAssColorString(colorStr)
                            secondaryColor = if (colorStr.length <= 6) newColor.copy(alpha = secondaryColor.alpha) else newColor
                        } else if (tag == "2c") {
                            secondaryColor = baseStyle.secondaryColor
                        }
                    } else if (tag.startsWith("3c")) {
                        // Outline Color
                        val colorStr = tag.substringAfter("&H").substringBefore("&")
                        if (colorStr.isNotEmpty()) {
                            val newColor = parseAssColorString(colorStr)
                            outlineColor = if (colorStr.length <= 6) newColor.copy(alpha = outlineColor.alpha) else newColor
                        } else if (tag == "3c") {
                            outlineColor = baseStyle.outlineColor
                        }
                    } else if (tag.startsWith("4c")) {
                        // Shadow Color
                        val colorStr = tag.substringAfter("&H").substringBefore("&")
                        if (colorStr.isNotEmpty()) {
                            val newColor = parseAssColorString(colorStr)
                            shadowColor = if (colorStr.length <= 6) newColor.copy(alpha = shadowColor.alpha) else newColor
                        } else if (tag == "4c") {
                            shadowColor = baseStyle.backColor
                        }
                    } else if (tag.startsWith("r")) {
                        // Reset style
                        val newStyleName = tag.removePrefix("r")
                        val newStyle = if (newStyleName.isEmpty()) baseStyle else (styles[newStyleName] ?: baseStyle)
                        boldWeight = newStyle.bold
                        italic = newStyle.italic
                        underline = newStyle.underline
                        strikeOut = newStyle.strikeOut
                        color = newStyle.primaryColor
                        secondaryColor = newStyle.secondaryColor
                        outlineColor = newStyle.outlineColor
                        shadowColor = newStyle.backColor
                        outlineWidth = newStyle.outlineWidth
                        shadowDistance = newStyle.shadowDistance
                    }
                }
                
                currentIndex = match.range.last + 1
            }
            
            // Append remaining text
            if (currentIndex < cleanText.length) {
                pushStringAnnotation("AssOutlineWidth", outlineWidth.toString())
                pushStringAnnotation("AssOutlineColor", outlineColor.value.toString())
                pushStringAnnotation("AssShadowDistance", shadowDistance.toString())
                pushStringAnnotation("AssShadowColor", shadowColor.value.toString())
                pushStringAnnotation("AssBlurRadius", blurRadius.toString())
                
                withStyle(
                    SpanStyle(
                        color = color,
                        fontWeight = resolveFontWeight(boldWeight),
                        fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
                        textDecoration = combineTextDecoration(underline, strikeOut),
                        shadow = null // Shadow handled by annotations in AssStyledText
                    )
                ) {
                    append(cleanText.substring(currentIndex))
                }
                pop()
                pop()
                pop()
                pop()
                pop()
            }
        }
    }

    private fun resolveFontWeight(weight: Int): FontWeight {
        return when (weight) {
            1 -> FontWeight.Normal // Map standard Bold (1) to Normal (400) because Compose renders Bold too thick for some fonts (e.g. Heiti)
            0 -> FontWeight.Normal
            else -> FontWeight(weight.coerceIn(1, 1000))
        }
    }

    private fun combineTextDecoration(underline: Boolean, strikeOut: Boolean): TextDecoration {
        val decorations = mutableListOf<TextDecoration>()
        if (underline) decorations.add(TextDecoration.Underline)
        if (strikeOut) decorations.add(TextDecoration.LineThrough)
        return if (decorations.isEmpty()) TextDecoration.None else TextDecoration.combine(decorations)
    }

    private fun parseAssColor(colorStr: String): Color {
        // Format: &HBBGGRR& or &HAABBGGRR& (Alpha is 00=opaque, FF=transparent)
        val clean = colorStr.replace("&H", "").replace("&", "")
        return parseAssColorString(clean)
    }
    
    private fun parseAssColorString(clean: String): Color {
        try {
            val longVal = clean.toLong(16)
            return if (clean.length > 6) {
                // AABBGGRR
                val alpha = ((longVal shr 24) and 0xFF).toInt()
                val blue = ((longVal shr 16) and 0xFF).toInt()
                val green = ((longVal shr 8) and 0xFF).toInt()
                val red = (longVal and 0xFF).toInt()
                Color(red, green, blue, 255 - alpha)
            } else {
                // BBGGRR
                val blue = ((longVal shr 16) and 0xFF).toInt()
                val green = ((longVal shr 8) and 0xFF).toInt()
                val red = (longVal and 0xFF).toInt()
                Color(red, green, blue, 255)
            }
        } catch (_: Exception) {
            return Color.White
        }
    }

    private fun parseAssTime(timeStr: String): Long {
        // Format: H:MM:SS.cc (centiseconds)
        try {
            val parts = timeStr.split(':')
            if (parts.size == 3) {
                val hours = parts[0].toLong()
                val minutes = parts[1].toLong()
                val secondsParts = parts[2].split('.')
                val seconds = secondsParts[0].toLong()
                val centis = if (secondsParts.size > 1) secondsParts[1].padEnd(2, '0').take(2).toLong() else 0L
                
                return (hours * 3600000) + (minutes * 60000) + (seconds * 1000) + (centis * 10)
            }
        } catch (_: Exception) {
            // Ignore malformed time
        }
        return 0L
    }
    
    private fun parseVtt(content: String): List<SubtitleCue> {
        val cues = mutableListOf<SubtitleCue>()
        val lines = content.lines()
        
        var i = 0
        while (i < lines.size) {
            val line = lines[i].trim()
            if (line.contains("-->")) {
                // Found timestamp line
                try {
                    val parts = line.split("-->")
                    val startStr = parts[0].trim()
                    val endStr = parts[1].trim()
                    val startMs = parseSrtTime(startStr) // VTT time format is similar to SRT
                    val endMs = parseSrtTime(endStr)
                    
                    // Collect text
                    val textBuilder = StringBuilder()
                    i++
                    while (i < lines.size && lines[i].trim().isNotBlank()) {
                        textBuilder.append(lines[i].trim()).append("\n")
                        i++
                    }
                    val text = textBuilder.toString().trim()
                    
                    if (text.isNotEmpty()) {
                        cues.add(SubtitleCue(startMs, endMs, AnnotatedString(text)))
                    }
                } catch (_: Exception) {
                    // Ignore malformed
                }
            }
            i++
        }
        return cues
    }
}
