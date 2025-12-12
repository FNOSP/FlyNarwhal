package com.jankinwu.fntv.client.icons


import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val Volume: ImageVector
    get() {
        if (_Volume != null) {
            return _Volume!!
        }
        _Volume = ImageVector.Builder(
            name = "Volume",
            defaultWidth = 28.dp,
            defaultHeight = 40.dp,
            viewportWidth = 28f,
            viewportHeight = 40f
        ).apply {
            path(fill = SolidColor(Color.White)) {
                moveTo(7.907f, 17.907f)
                lineToRelative(-4.518f, 0f)
                lineToRelative(0f, 6.778f)
                lineToRelative(4.518f, 0f)
                lineToRelative(5.648f, 5.648f)
                lineToRelative(0f, -18.074f)
                lineToRelative(-5.648f, 5.648f)
                close()
            }
            path(fill = SolidColor(Color.White)) {
                moveTo(17.554f, 25.295f)
                lineToRelative(-1.604f, -1.604f)
                curveToRelative(0.612f, -0.613f, 0.991f, -1.46f, 0.991f, -2.395f)
                reflectiveCurveToRelative(-0.379f, -1.782f, -0.991f, -2.395f)
                lineToRelative(0f, 0f)
                lineToRelative(1.604f, -1.604f)
                curveToRelative(1.031f, 1.02f, 1.669f, 2.435f, 1.669f, 3.999f)
                reflectiveCurveToRelative(-0.638f, 2.979f, -1.668f, 3.998f)
                lineToRelative(-0f, 0f)
                close()
                moveTo(17.554f, 25.295f)
                lineToRelative(-1.604f, -1.604f)
                curveToRelative(0.612f, -0.613f, 0.991f, -1.46f, 0.991f, -2.395f)
                reflectiveCurveToRelative(-0.379f, -1.782f, -0.991f, -2.395f)
                lineToRelative(0f, 0f)
                lineToRelative(1.604f, -1.604f)
                curveToRelative(1.031f, 1.02f, 1.669f, 2.435f, 1.669f, 3.999f)
                reflectiveCurveToRelative(-0.638f, 2.979f, -1.668f, 3.998f)
                lineToRelative(-0f, 0f)
                close()
            }
        }.build()

        return _Volume!!
    }

@Suppress("ObjectPropertyName")
private var _Volume: ImageVector? = null