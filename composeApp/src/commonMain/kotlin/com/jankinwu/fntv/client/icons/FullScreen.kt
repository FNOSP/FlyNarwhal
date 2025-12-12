package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val FullScreen: ImageVector
    get() {
        if (_FullScreen != null) {
            return _FullScreen!!
        }
        _FullScreen = ImageVector.Builder(
            name = "FullScreen",
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 24f,
            viewportHeight = 24f
        ).apply {
            path(
                fill = SolidColor(Color.White),
                fillAlpha = 0.8f
            ) {
                moveTo(15f, 18f)
                curveTo(15f, 18f, 18f, 18f, 18f, 18f)
                curveTo(18f, 18f, 18f, 15f, 18f, 15f)
                curveTo(18f, 15f, 20f, 15f, 20f, 15f)
                curveTo(20f, 15f, 20f, 18f, 20f, 18f)
                curveTo(20f, 19.105f, 19.105f, 20f, 18f, 20f)
                curveTo(18f, 20f, 15f, 20f, 15f, 20f)
                curveTo(15f, 20f, 15f, 18f, 15f, 18f)
                close()
            }
            path(
                fill = SolidColor(Color.White),
                fillAlpha = 0.8f
            ) {
                moveTo(15f, 4f)
                curveTo(15f, 4f, 15f, 6f, 15f, 6f)
                curveTo(15f, 6f, 18f, 6f, 18f, 6f)
                curveTo(18f, 6f, 18f, 9f, 18f, 9f)
                curveTo(18f, 9f, 20f, 9f, 20f, 9f)
                curveTo(20f, 9f, 20f, 6f, 20f, 6f)
                curveTo(20f, 4.895f, 19.105f, 4f, 18f, 4f)
                curveTo(18f, 4f, 15f, 4f, 15f, 4f)
                close()
            }
            path(
                fill = SolidColor(Color.White),
                fillAlpha = 0.8f
            ) {
                moveTo(4f, 9f)
                curveTo(4f, 9f, 6f, 9f, 6f, 9f)
                curveTo(6f, 9f, 6f, 6f, 6f, 6f)
                curveTo(6f, 6f, 9f, 6f, 9f, 6f)
                curveTo(9f, 6f, 9f, 4f, 9f, 4f)
                curveTo(9f, 4f, 6f, 4f, 6f, 4f)
                curveTo(4.895f, 4f, 4f, 4.895f, 4f, 6f)
                curveTo(4f, 6f, 4f, 9f, 4f, 9f)
                close()
            }
            path(
                fill = SolidColor(Color.White),
                fillAlpha = 0.8f
            ) {
                moveTo(6f, 15f)
                curveTo(6f, 15f, 4f, 15f, 4f, 15f)
                curveTo(4f, 15f, 4f, 18f, 4f, 18f)
                curveTo(4f, 19.105f, 4.895f, 20f, 6f, 20f)
                curveTo(6f, 20f, 9f, 20f, 9f, 20f)
                curveTo(9f, 20f, 9f, 18f, 9f, 18f)
                curveTo(9f, 18f, 6f, 18f, 6f, 18f)
                curveTo(6f, 18f, 6f, 15f, 6f, 15f)
                close()
            }
        }.build()

        return _FullScreen!!
    }

@Suppress("ObjectPropertyName")
private var _FullScreen: ImageVector? = null
