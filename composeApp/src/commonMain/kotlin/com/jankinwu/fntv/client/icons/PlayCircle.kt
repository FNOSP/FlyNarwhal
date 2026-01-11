package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val PlayCircle: ImageVector
    get() {
        if (_PlayCircle != null) {
            return _PlayCircle!!
        }
        _PlayCircle = ImageVector.Builder(
            name = "PlayCircle",
            defaultWidth = 200.dp,
            defaultHeight = 200.dp,
            viewportWidth = 1024f,
            viewportHeight = 1024f
        ).apply {
            path(fill = SolidColor(Color.Black)) {
                moveTo(512f, 981.3f)
                arcToRelative(469.3f, 469.3f, 0f, isMoreThanHalf = true, isPositiveArc = true, 469.3f, -469.3f)
                arcToRelative(469.3f, 469.3f, 0f, isMoreThanHalf = false, isPositiveArc = true, -469.3f, 469.3f)
                close()
                moveTo(512f, 128f)
                arcToRelative(384f, 384f, 0f, isMoreThanHalf = true, isPositiveArc = false, 384f, 384f)
                arcToRelative(384f, 384f, 0f, isMoreThanHalf = false, isPositiveArc = false, -384f, -384f)
                close()
            }
            path(fill = SolidColor(Color.Black)) {
                moveTo(384f, 768f)
                arcToRelative(38.8f, 38.8f, 0f, isMoreThanHalf = false, isPositiveArc = true, -20.5f, -5.5f)
                arcTo(42.7f, 42.7f, 0f, isMoreThanHalf = false, isPositiveArc = true, 341.3f, 725.3f)
                lineTo(341.3f, 298.7f)
                arcToRelative(42.7f, 42.7f, 0f, isMoreThanHalf = false, isPositiveArc = true, 65.3f, -36.3f)
                lineToRelative(341.3f, 213.3f)
                arcToRelative(42.7f, 42.7f, 0f, isMoreThanHalf = false, isPositiveArc = true, 0f, 72.5f)
                lineToRelative(-341.3f, 213.3f)
                arcTo(42.7f, 42.7f, 0f, isMoreThanHalf = false, isPositiveArc = true, 384f, 768f)
                close()
                moveTo(426.7f, 375.5f)
                verticalLineToRelative(273.1f)
                lineToRelative(218f, -136.5f)
                close()
            }
        }.build()

        return _PlayCircle!!
    }

@Suppress("ObjectPropertyName")
private var _PlayCircle: ImageVector? = null