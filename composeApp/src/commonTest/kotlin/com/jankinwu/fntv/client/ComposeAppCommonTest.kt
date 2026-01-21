package com.jankinwu.fntv.client

import androidx.compose.ui.text.font.FontWeight
import com.jankinwu.fntv.client.utils.parseSubtitleInlineTags
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ComposeAppCommonTest {

    @Test
    fun example() {
        assertEquals(3, 1 + 2)
    }

    @Test
    fun parseSubtitleInlineTags_bold() {
        val result = parseSubtitleInlineTags("<b>测试字幕</b>")
        assertEquals("测试字幕", result.text)
        assertTrue(result.spanStyles.any { it.item.fontWeight == FontWeight.Bold })
    }

    @Test
    fun parseSubtitleInlineTags_br() {
        val result = parseSubtitleInlineTags("a<br/>b")
        assertEquals("a\nb", result.text)
    }
}
