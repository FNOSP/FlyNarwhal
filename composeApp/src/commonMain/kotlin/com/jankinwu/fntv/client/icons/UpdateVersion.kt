package com.jankinwu.fntv.client.icons


import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val UpdateVersion: ImageVector
    get() {
        if (_UpdateVersion != null) {
            return _UpdateVersion!!
        }
        _UpdateVersion = ImageVector.Builder(
            name = "UpdateVersion",
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 1024f,
            viewportHeight = 1024f
        ).apply {
            path(fill = SolidColor(Color.Black)) {
                moveTo(646.1f, 799.2f)
                horizontalLineTo(377.9f)
                curveToRelative(-14.8f, 0f, -27.1f, 12.3f, -27.1f, 27.1f)
                reflectiveCurveToRelative(12.3f, 27.1f, 27.1f, 27.1f)
                horizontalLineToRelative(268.3f)
                curveToRelative(14.8f, 0f, 27.1f, -12.3f, 27.1f, -27.1f)
                reflectiveCurveToRelative(-11.8f, -27.1f, -27.1f, -27.1f)
                close()
                moveTo(751.6f, 387.1f)
                lineToRelative(-181.2f, -191f)
                curveToRelative(-15.4f, -16.4f, -36.4f, -25.1f, -58.9f, -25.1f)
                reflectiveCurveToRelative(-43f, 9.2f, -58.9f, 25.1f)
                lineTo(272.4f, 387.1f)
                curveTo(265.2f, 394.2f, 261.1f, 404.5f, 261.1f, 414.7f)
                curveToRelative(0f, 10.8f, 4.1f, 21f, 11.8f, 28.7f)
                curveToRelative(7.7f, 7.7f, 17.9f, 11.8f, 28.7f, 11.8f)
                horizontalLineToRelative(84.5f)
                verticalLineToRelative(160.8f)
                curveToRelative(0f, 29.7f, 24.1f, 54.3f, 54.3f, 54.3f)
                horizontalLineToRelative(143.4f)
                curveToRelative(14.3f, 0f, 28.2f, -5.6f, 38.4f, -15.9f)
                reflectiveCurveToRelative(15.9f, -23.6f, 15.4f, -38.4f)
                verticalLineTo(455.2f)
                horizontalLineTo(721.9f)
                curveToRelative(15.9f, 0f, 30.7f, -9.7f, 37.4f, -24.6f)
                curveToRelative(6.7f, -14.8f, 3.6f, -31.7f, -7.7f, -43.5f)
                close()
                moveTo(601.6f, 762.9f)
                curveToRelative(14.8f, 0f, 27.1f, -12.3f, 27.1f, -27.1f)
                reflectiveCurveToRelative(-12.3f, -27.1f, -27.1f, -27.1f)
                horizontalLineToRelative(-179.2f)
                curveToRelative(-14.8f, 0f, -27.1f, 12.3f, -27.1f, 27.1f)
                reflectiveCurveToRelative(12.3f, 27.1f, 27.1f, 27.1f)
                horizontalLineToRelative(179.2f)
                close()
            }
            path(fill = SolidColor(Color.Black)) {
                moveTo(847.4f, 1006.1f)
                horizontalLineToRelative(-670.7f)
                curveToRelative(-87.6f, 0f, -158.7f, -71.2f, -158.7f, -158.7f)
                verticalLineToRelative(-670.7f)
                curveToRelative(0f, -87.6f, 71.2f, -158.7f, 158.7f, -158.7f)
                horizontalLineToRelative(670.7f)
                curveToRelative(87.6f, 0f, 158.7f, 71.2f, 158.7f, 158.7f)
                verticalLineToRelative(670.7f)
                curveToRelative(0f, 87.6f, -71.2f, 158.7f, -158.7f, 158.7f)
                close()
                moveTo(176.6f, 84.5f)
                curveToRelative(-50.7f, 0f, -92.2f, 41.5f, -92.2f, 92.2f)
                verticalLineToRelative(670.7f)
                curveToRelative(0f, 50.7f, 41.5f, 92.2f, 92.2f, 92.2f)
                horizontalLineToRelative(670.7f)
                curveToRelative(50.7f, 0f, 92.2f, -41.5f, 92.2f, -92.2f)
                verticalLineToRelative(-670.7f)
                curveToRelative(0f, -50.7f, -41.5f, -92.2f, -92.2f, -92.2f)
                horizontalLineToRelative(-670.7f)
                close()
            }
        }.build()

        return _UpdateVersion!!
    }

@Suppress("ObjectPropertyName")
private var _UpdateVersion: ImageVector? = null