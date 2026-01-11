package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val DanmuSetting: ImageVector
    get() {
        if (_DanmuSetting != null) {
            return _DanmuSetting!!
        }
        _DanmuSetting = ImageVector.Builder(
            name = "DanmuSetting",
            defaultWidth = 200.dp,
            defaultHeight = 200.dp,
            viewportWidth = 1024f,
            viewportHeight = 1024f
        ).apply {
            path(fill = SolidColor(Color.Black)) {
                moveTo(226.6f, 320.4f)
                horizontalLineToRelative(-48f)
                curveToRelative(-35.9f, 0f, -65f, -29.1f, -65f, -65f)
                reflectiveCurveToRelative(29.1f, -65f, 65f, -65f)
                horizontalLineToRelative(48f)
                curveToRelative(35.9f, 0f, 65f, 29.1f, 65f, 65f)
                reflectiveCurveToRelative(-29.1f, 65f, -65f, 65f)
                close()
                moveTo(723.6f, 320.4f)
                horizontalLineToRelative(-322f)
                curveToRelative(-35.9f, 0f, -65f, -29.1f, -65f, -65f)
                reflectiveCurveToRelative(29.1f, -65f, 65f, -65f)
                horizontalLineToRelative(322f)
                curveToRelative(35.9f, 0f, 65f, 29.1f, 65f, 65f)
                reflectiveCurveToRelative(-29.1f, 65f, -65f, 65f)
                close()
                moveTo(402.6f, 580.4f)
                horizontalLineToRelative(-224f)
                curveToRelative(-35.9f, 0f, -65f, -29.1f, -65f, -65f)
                reflectiveCurveToRelative(29.1f, -65f, 65f, -65f)
                horizontalLineToRelative(224f)
                curveToRelative(35.9f, 0f, 65f, 29.1f, 65f, 65f)
                reflectiveCurveToRelative(-29.1f, 65f, -65f, 65f)
                close()
                moveTo(251.6f, 839.4f)
                horizontalLineToRelative(-73f)
                curveToRelative(-35.9f, 0f, -65f, -29.1f, -65f, -65f)
                reflectiveCurveToRelative(29.1f, -65f, 65f, -65f)
                horizontalLineToRelative(73f)
                curveToRelative(35.9f, 0f, 65f, 29.1f, 65f, 65f)
                reflectiveCurveToRelative(-29.1f, 65f, -65f, 65f)
                close()
                moveTo(424.6f, 839.4f)
                horizontalLineToRelative(-1f)
                curveToRelative(-35.9f, 0f, -65f, -29.1f, -65f, -65f)
                reflectiveCurveToRelative(29.1f, -65f, 65f, -65f)
                horizontalLineToRelative(1f)
                curveToRelative(35.9f, 0f, 65f, 29.1f, 65f, 65f)
                reflectiveCurveToRelative(-29.1f, 65f, -65f, 65f)
                close()
                moveTo(954.8f, 588.6f)
                lineToRelative(-93.4f, -161.8f)
                arcToRelative(59.2f, 59.2f, 0f, isMoreThanHalf = false, isPositiveArc = false, -51.3f, -29.6f)
                horizontalLineToRelative(-186.8f)
                arcToRelative(59.2f, 59.2f, 0f, isMoreThanHalf = false, isPositiveArc = false, -51.3f, 29.6f)
                lineToRelative(-93.4f, 161.8f)
                arcToRelative(59.2f, 59.2f, 0f, isMoreThanHalf = false, isPositiveArc = false, 0f, 59.2f)
                lineToRelative(93.4f, 161.8f)
                arcToRelative(59.2f, 59.2f, 0f, isMoreThanHalf = false, isPositiveArc = false, 51.3f, 29.6f)
                horizontalLineToRelative(186.8f)
                curveToRelative(21.1f, 0f, 40.7f, -11.3f, 51.3f, -29.6f)
                lineToRelative(93.4f, -161.8f)
                arcToRelative(59.2f, 59.2f, 0f, isMoreThanHalf = false, isPositiveArc = false, -0f, -59.2f)
                close()
                moveTo(716.8f, 684.4f)
                curveToRelative(-36.5f, 0f, -66.2f, -29.6f, -66.2f, -66.2f)
                curveToRelative(0f, -36.5f, 29.6f, -66.2f, 66.2f, -66.2f)
                curveToRelative(36.5f, 0f, 66.2f, 29.6f, 66.2f, 66.2f)
                curveToRelative(0f, 36.5f, -29.6f, 66.2f, -66.2f, 66.2f)
                close()
            }
        }.build()

        return _DanmuSetting!!
    }

@Suppress("ObjectPropertyName")
private var _DanmuSetting: ImageVector? = null