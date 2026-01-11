package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val VideoSmartAnalysis: ImageVector
    get() {
        if (_VideoSmartAnalysis != null) {
            return _VideoSmartAnalysis!!
        }
        _VideoSmartAnalysis = ImageVector.Builder(
            name = "VideoSmartAnalysis",
            defaultWidth = 200.dp,
            defaultHeight = 200.dp,
            viewportWidth = 1024f,
            viewportHeight = 1024f
        ).apply {
            path(fill = SolidColor(Color(0xFF030000))) {
                moveTo(365.4f, 628f)
                lineToRelative(187f, -169.7f)
                lineToRelative(-187f, -162.3f)
                close()
                moveTo(930.5f, 795.9f)
                curveToRelative(22.8f, -33.2f, 36.3f, -73.1f, 36.3f, -116.2f)
                curveToRelative(0f, -113.4f, -92.2f, -205.6f, -205.6f, -205.6f)
                curveToRelative(-113.3f, 0f, -205.6f, 92.2f, -205.6f, 205.6f)
                reflectiveCurveToRelative(92.2f, 205.6f, 205.6f, 205.6f)
                curveToRelative(43.2f, 0f, 83.1f, -13.5f, 116.2f, -36.3f)
                lineToRelative(93.5f, 93.5f)
                lineToRelative(53.1f, -53.1f)
                lineToRelative(-93.6f, -93.4f)
                close()
                moveTo(761.1f, 810.2f)
                curveToRelative(-71.9f, 0f, -130.5f, -58.5f, -130.5f, -130.6f)
                reflectiveCurveToRelative(58.5f, -130.6f, 130.5f, -130.6f)
                curveToRelative(72f, 0f, 130.6f, 58.5f, 130.6f, 130.6f)
                reflectiveCurveToRelative(-58.5f, 130.6f, -130.6f, 130.6f)
                close()
            }
            path(fill = SolidColor(Color(0xFF030000))) {
                moveTo(75.1f, 156.7f)
                horizontalLineToRelative(720.9f)
                verticalLineToRelative(226.5f)
                horizontalLineToRelative(75.1f)
                verticalLineTo(81.6f)
                horizontalLineTo(0f)
                verticalLineToRelative(754.8f)
                horizontalLineToRelative(459.5f)
                verticalLineToRelative(-75f)
                horizontalLineTo(75.1f)
                close()
            }
        }.build()

        return _VideoSmartAnalysis!!
    }

@Suppress("ObjectPropertyName")
private var _VideoSmartAnalysis: ImageVector? = null