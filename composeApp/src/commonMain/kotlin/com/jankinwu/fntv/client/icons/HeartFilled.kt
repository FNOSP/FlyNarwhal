package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathData
import androidx.compose.ui.graphics.vector.group
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val HeartFilled: ImageVector
    get() {
        if (_HeartFilled != null) {
            return _HeartFilled!!
        }
        _HeartFilled = ImageVector.Builder(
            name = "HeartFilled",
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 24f,
            viewportHeight = 24f
        ).apply {
            group(
                clipPathData = PathData {
                    moveTo(0f, 0f)
                    horizontalLineToRelative(24f)
                    verticalLineToRelative(24f)
                    horizontalLineToRelative(-24f)
                    close()
                }
            ) {
                path(fill = SolidColor(Color.Black)) {
                    moveTo(16.5f, 2f)
                    arcTo(6.5f, 6.5f, 0f, isMoreThanHalf = false, isPositiveArc = true, 23f, 8.5f)
                    curveToRelative(0f, 2.742f, -1.81f, 4.753f, -3.297f, 6.21f)
                    lineToRelative(-6.996f, 6.997f)
                    arcToRelative(1f, 1f, 0f, isMoreThanHalf = false, isPositiveArc = true, -1.414f, 0f)
                    lineToRelative(-6.994f, -6.994f)
                    curveTo(2.794f, 13.258f, 1f, 11.249f, 1f, 8.5f)
                    arcTo(6.5f, 6.5f, 0f, isMoreThanHalf = false, isPositiveArc = true, 7.5f, 2f)
                    curveToRelative(0.98f, 0f, 1.873f, 0.14f, 2.747f, 0.52f)
                    curveToRelative(0.613f, 0.267f, 1.185f, 0.64f, 1.753f, 1.12f)
                    curveToRelative(0.568f, -0.48f, 1.14f, -0.853f, 1.753f, -1.12f)
                    curveTo(14.627f, 2.14f, 15.52f, 2f, 16.5f, 2f)
                    close()
                }
            }
        }.build()

        return _HeartFilled!!
    }

@Suppress("ObjectPropertyName")
private var _HeartFilled: ImageVector? = null