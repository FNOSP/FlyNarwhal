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
            path(fill = SolidColor(Color.White)) {
                moveTo(512f, 853.3f)
                curveToRelative(188.5f, 0f, 341.3f, -152.8f, 341.3f, -341.3f)
                reflectiveCurveTo(700.5f, 170.7f, 512f, 170.7f)
                reflectiveCurveTo(170.7f, 323.5f, 170.7f, 512f)
                reflectiveCurveToRelative(152.8f, 341.3f, 341.3f, 341.3f)
                close()
                moveTo(938.7f, 512f)
                curveToRelative(0f, 235.6f, -191f, 426.7f, -426.7f, 426.7f)
                reflectiveCurveTo(85.3f, 747.6f, 85.3f, 512f)
                reflectiveCurveTo(276.4f, 85.3f, 512f, 85.3f)
                reflectiveCurveToRelative(426.7f, 191f, 426.7f, 426.7f)
                close()
                moveTo(469.3f, 725.3f)
                verticalLineToRelative(-85.3f)
                horizontalLineToRelative(85.3f)
                verticalLineToRelative(85.3f)
                horizontalLineToRelative(-85.3f)
                close()
                moveTo(554.7f, 298.7f)
                verticalLineToRelative(298.7f)
                horizontalLineToRelative(-85.3f)
                lineTo(469.3f, 298.7f)
                horizontalLineToRelative(85.3f)
                close()
            }
        }.build()

        return _Statement!!
    }

@Suppress("ObjectPropertyName")
private var _Statement: ImageVector? = null
