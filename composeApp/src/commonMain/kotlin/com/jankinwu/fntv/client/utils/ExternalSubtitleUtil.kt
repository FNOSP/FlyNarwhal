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

data class AssStyle(
    val name: String,
    val fontName: String,
    val fontSize: Float,
    val primaryColor: Color,
    val secondaryColor: Color,
    val outlineColor: Color,
    val backColor: Color,
    val bold: Boolean,
    val italic: Boolean,
    val underline: Boolean,
    val strikeOut: Boolean,
    val alignment: Int = 2
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
            bold = false,
            italic = false,
            underline = false,
            strikeOut = false,
            alignment = 2
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
                isInitialized = true
                logger.i { "Initialized ExternalSubtitleUtil with ${cues.size} cues (${subtitleStream.format})" }
            } catch (e: Exception) {
                logger.e(e) { "Failed to initialize ExternalSubtitleUtil" }
            }
        }
    }

    fun getCurrentSubtitle(currentPositionMs: Long): List<SubtitleCue> {
        return cues.filter { cue ->
            currentPositionMs >= cue.startTime && currentPositionMs < cue.endTime
        }
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
                    cues.add(SubtitleCue(startTime, endTime, AnnotatedString(subtitleText)))
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
        } catch (e: Exception) {
            // Ignore malformed time
        }
        return 0L
    }

    private fun parseAss(content: String): List<SubtitleCue> {
        val cues = mutableListOf<SubtitleCue>()
        val lines = content.lines()
        var formatIndexMap = mutableMapOf<String, Int>()
        var styleFormatIndexMap = mutableMapOf<String, Int>()
        
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
                            val bold = (parts.getOrNull(styleFormatIndexMap["bold"] ?: -1) ?: "0") != "0"
                            val italic = (parts.getOrNull(styleFormatIndexMap["italic"] ?: -1) ?: "0") != "0"
                            val underline = (parts.getOrNull(styleFormatIndexMap["underline"] ?: -1) ?: "0") != "0"
                            val strikeOut = (parts.getOrNull(styleFormatIndexMap["strikeout"] ?: -1) ?: "0") != "0"
                            val alignment = parts.getOrNull(styleFormatIndexMap["alignment"] ?: -1)?.toIntOrNull() ?: 2
                            
                            val style = AssStyle(
                                name, fontName, fontSize, primaryColor, secondaryColor, outlineColor, backColor,
                                bold, italic, underline, strikeOut, alignment
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
                                
                                val assProps = AssProperties(
                                    playResX = playResX,
                                    playResY = playResY,
                                    fontSize = baseStyle.fontSize,
                                    alignment = align,
                                    position = pos,
                                    move = move
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
            var bold = baseStyle.bold
            var italic = baseStyle.italic
            var underline = baseStyle.underline
            var strikeOut = baseStyle.strikeOut
            var color = baseStyle.primaryColor
            
            tagRegex.findAll(cleanText).forEach { match ->
                // Append text before tag
                if (match.range.first > currentIndex) {
                    val segment = cleanText.substring(currentIndex, match.range.first)
                    withStyle(
                        SpanStyle(
                            color = color,
                            fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal,
                            fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
                            textDecoration = combineTextDecoration(underline, strikeOut)
                        )
                    ) {
                        append(segment)
                    }
                }
                
                // Parse tag
                val tagContent = match.value.removePrefix("{").removeSuffix("}")
                val tags = tagContent.split("\\")
                for (tag in tags) {
                    if (tag.isEmpty()) continue
                    
                    if (tag.startsWith("b")) {
                        val param = tag.removePrefix("b")
                        if (param.isEmpty() || param == "1") bold = true
                        else if (param == "0") bold = false
                        else {
                            // \b<weight>
                            bold = (param.toIntOrNull() ?: 0) > 400
                        }
                    } else if (tag.startsWith("i")) {
                        italic = tag.removePrefix("i") != "0"
                    } else if (tag.startsWith("u")) {
                        underline = tag.removePrefix("u") != "0"
                    } else if (tag.startsWith("s")) {
                        strikeOut = tag.removePrefix("s") != "0"
                    } else if (tag.startsWith("c") || tag.startsWith("1c")) {
                        val colorStr = tag.substringAfter("&H").substringBefore("&")
                        if (colorStr.isNotEmpty()) {
                            color = parseAssColorString(colorStr)
                        } else if (tag == "c" || tag == "1c") {
                            color = baseStyle.primaryColor // Reset to style default
                        }
                    } else if (tag.startsWith("r")) {
                        // Reset style
                        val newStyleName = tag.removePrefix("r")
                        val newStyle = if (newStyleName.isEmpty()) baseStyle else (styles[newStyleName] ?: baseStyle)
                        bold = newStyle.bold
                        italic = newStyle.italic
                        underline = newStyle.underline
                        strikeOut = newStyle.strikeOut
                        color = newStyle.primaryColor
                    }
                }
                
                currentIndex = match.range.last + 1
            }
            
            // Append remaining text
            if (currentIndex < cleanText.length) {
                withStyle(
                    SpanStyle(
                        color = color,
                        fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal,
                        fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
                        textDecoration = combineTextDecoration(underline, strikeOut)
                    )
                ) {
                    append(cleanText.substring(currentIndex))
                }
            }
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
        } catch (e: Exception) {
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
        } catch (e: Exception) {
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
                } catch (e: Exception) {
                    // Ignore malformed
                }
            }
            i++
        }
        return cues
    }
}
