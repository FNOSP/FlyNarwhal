package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val ExitFullScreen: ImageVector
    get() {
        if (_ExitFullScreen != null) {
            return _ExitFullScreen!!
        }
        _ExitFullScreen = ImageVector.Builder(
            name = "ExitFullScreen",
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 24f,
            viewportHeight = 24f
        ).apply {
            path(
                fill = SolidColor(Color.White),
                fillAlpha = 0.8f
            ) {
                moveTo(6.5f, 17f)
                curveTo(6.5f, 17f, 3.5f, 17f, 3.5f, 17f)
                curveTo(3.5f, 17f, 3.5f, 15f, 3.5f, 15f)
                curveTo(3.5f, 15f, 6.5f, 15f, 6.5f, 15f)
                curveTo(7.605f, 15f, 8.5f, 15.895f, 8.5f, 17f)
                curveTo(8.5f, 17f, 8.5f, 20f, 8.5f, 20f)
                curveTo(8.5f, 20f, 6.5f, 20f, 6.5f, 20f)
                curveTo(6.5f, 20f, 6.5f, 17f, 6.5f, 17f)
                close()
            }
            path(
                fill = SolidColor(Color.White),
                fillAlpha = 0.8f
            ) {
                moveTo(6.5f, 6.5f)
                curveTo(6.5f, 6.5f, 3.5f, 6.5f, 3.5f, 6.5f)
                curveTo(3.5f, 6.5f, 3.5f, 8.5f, 3.5f, 8.5f)
                curveTo(3.5f, 8.5f, 6.5f, 8.5f, 6.5f, 8.5f)
                curveTo(7.605f, 8.5f, 8.5f, 7.605f, 8.5f, 6.5f)
                curveTo(8.5f, 6.5f, 8.5f, 3.5f, 8.5f, 3.5f)
                curveTo(8.5f, 3.5f, 6.5f, 3.5f, 6.5f, 3.5f)
                curveTo(6.5f, 3.5f, 6.5f, 6.5f, 6.5f, 6.5f)
                close()
            }
            path(
                fill = SolidColor(Color.White),
                fillAlpha = 0.8f
            ) {
                moveTo(17f, 6.5f)
                curveTo(17f, 6.5f, 17f, 3.5f, 17f, 3.5f)
                curveTo(17f, 3.5f, 15f, 3.5f, 15f, 3.5f)
                curveTo(15f, 3.5f, 15f, 6.5f, 15f, 6.5f)
                curveTo(15f, 7.605f, 15.895f, 8.5f, 17f, 8.5f)
                curveTo(17f, 8.5f, 20f, 8.5f, 20f, 8.5f)
                curveTo(20f, 8.5f, 20f, 6.5f, 20f, 6.5f)
                curveTo(20f, 6.5f, 17f, 6.5f, 17f, 6.5f)
                close()
            }
            path(
                fill = SolidColor(Color.White),
                fillAlpha = 0.8f
            ) {
                moveTo(15f, 20f)
                curveTo(15f, 20f, 17f, 20f, 17f, 20f)
                curveTo(17f, 20f, 17f, 17f, 17f, 17f)
                curveTo(17f, 17f, 20f, 17f, 20f, 17f)
                curveTo(20f, 17f, 20f, 15f, 20f, 15f)
                curveTo(20f, 15f, 17f, 15f, 17f, 15f)
                curveTo(15.895f, 15f, 15f, 15.895f, 15f, 17f)
                curveTo(15f, 17f, 15f, 20f, 15f, 20f)
                close()
            }
        }.build()

        return _ExitFullScreen!!
    }

@Suppress("ObjectPropertyName")
private var _ExitFullScreen: ImageVector? = null