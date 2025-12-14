package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val Statement: ImageVector
    get() {
        if (_Statement != null) {
            return _Statement!!
        }
        _Statement = ImageVector.Builder(
            name = "Statement",
            defaultWidth = 200.dp,
            defaultHeight = 200.dp,
            viewportWidth = 1024f,
            viewportHeight = 1024f
        ).apply {
            path(fill = SolidColor(Color.Black)) {
                moveTo(512f, 51.2f)
                lineTo(56.9f, 244.6f)
                verticalLineToRelative(39.9f)
                curveTo(56.9f, 699.8f, 204.8f, 944.3f, 495f, 1024f)
                horizontalLineToRelative(34.1f)
                curveToRelative(290.2f, -73.9f, 438.1f, -324.2f, 438.1f, -739.5f)
                verticalLineToRelative(-39.9f)
                lineTo(512f, 51.2f)
                close()
                moveTo(512f, 910.2f)
                curveToRelative(-221.8f, -62.5f, -335.7f, -256f, -341.4f, -585.9f)
                lineTo(512f, 176.3f)
                lineToRelative(341.4f, 147.9f)
                curveToRelative(-5.7f, 329.9f, -119.5f, 517.7f, -341.4f, 585.9f)
                close()
            }
            path(fill = SolidColor(Color.Black)) {
                moveTo(455.1f, 455.1f)
                horizontalLineToRelative(113.8f)
                verticalLineToRelative(284.5f)
                lineTo(455.1f, 739.6f)
                verticalLineToRelative(-284.5f)
                close()
                moveTo(455.1f, 284.5f)
                horizontalLineToRelative(113.8f)
                verticalLineToRelative(113.7f)
                lineTo(455.1f, 398.2f)
                lineTo(455.1f, 284.5f)
                close()
            }
        }.build()

        return _Statement!!
    }

@Suppress("ObjectPropertyName")
private var _Statement: ImageVector? = null