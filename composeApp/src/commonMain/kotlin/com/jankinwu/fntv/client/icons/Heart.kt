package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathData
import androidx.compose.ui.graphics.vector.group
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val Heart: ImageVector
    get() {
        if (_Heart != null) {
            return _Heart!!
        }
        _Heart = ImageVector.Builder(
            name = "Heart",
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
                path(
                    fill = SolidColor(Color.Black),
                    pathFillType = PathFillType.EvenOdd
                ) {
                    moveTo(2.904f, 3.904f)
                    arcTo(6.5f, 6.5f, 0f, isMoreThanHalf = false, isPositiveArc = true, 7.5f, 2f)
                    curveToRelative(0.98f, 0f, 1.873f, 0.14f, 2.747f, 0.52f)
                    curveToRelative(0.613f, 0.268f, 1.185f, 0.64f, 1.753f, 1.12f)
                    curveToRelative(0.568f, -0.48f, 1.14f, -0.852f, 1.753f, -1.12f)
                    curveTo(14.627f, 2.14f, 15.52f, 2f, 16.5f, 2f)
                    arcTo(6.5f, 6.5f, 0f, isMoreThanHalf = false, isPositiveArc = true, 23f, 8.5f)
                    curveToRelative(0f, 2.742f, -1.81f, 4.753f, -3.297f, 6.21f)
                    lineToRelative(-6.996f, 6.997f)
                    arcToRelative(1f, 1f, 0f, isMoreThanHalf = false, isPositiveArc = true, -1.414f, 0f)
                    lineToRelative(-6.994f, -6.994f)
                    curveTo(2.794f, 13.258f, 1f, 11.25f, 1f, 8.5f)
                    arcToRelative(6.5f, 6.5f, 0f, isMoreThanHalf = false, isPositiveArc = true, 1.904f, -4.596f)
                    close()
                    moveTo(7.5f, 4f)
                    arcTo(4.5f, 4.5f, 0f, isMoreThanHalf = false, isPositiveArc = false, 3f, 8.5f)
                    curveToRelative(0f, 1.847f, 1.2f, 3.336f, 2.695f, 4.781f)
                    lineToRelative(0.012f, 0.012f)
                    lineTo(12f, 19.586f)
                    lineToRelative(6.3f, -6.3f)
                    curveToRelative(1.492f, -1.463f, 2.7f, -2.95f, 2.7f, -4.786f)
                    arcTo(4.5f, 4.5f, 0f, isMoreThanHalf = false, isPositiveArc = false, 16.5f, 4f)
                    curveToRelative(-0.78f, 0f, -1.387f, 0.11f, -1.948f, 0.354f)
                    curveToRelative(-0.568f, 0.248f, -1.152f, 0.66f, -1.845f, 1.353f)
                    arcToRelative(1f, 1f, 0f, isMoreThanHalf = false, isPositiveArc = true, -1.414f, 0f)
                    curveToRelative(-0.693f, -0.693f, -1.277f, -1.105f, -1.845f, -1.353f)
                    curveTo(8.887f, 4.11f, 8.28f, 4f, 7.5f, 4f)
                    close()
                }
            }
        }.build()

        return _Heart!!
    }

@Suppress("ObjectPropertyName")
private var _Heart: ImageVector? = null