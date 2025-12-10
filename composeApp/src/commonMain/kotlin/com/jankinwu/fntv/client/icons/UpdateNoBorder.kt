package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val UpdateNoBorder: ImageVector
    get() {
        if (_UpdateNoBorder != null) {
            return _UpdateNoBorder!!
        }
        _UpdateNoBorder = ImageVector.Builder(
            name = "UpdateNoBorder",
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 1024f,
            viewportHeight = 1024f
        ).apply {
            path(fill = SolidColor(Color(0xFF666666))) {
                moveTo(929.9f, 388.3f)
                lineTo(563.2f, 21.6f)
                arcToRelative(72.1f, 72.1f, 0f, isMoreThanHalf = false, isPositiveArc = false, -102.4f, 0f)
                lineTo(94.1f, 388.3f)
                arcToRelative(72.2f, 72.2f, 0f, isMoreThanHalf = false, isPositiveArc = false, 51.2f, 123.6f)
                horizontalLineToRelative(145f)
                verticalLineToRelative(145f)
                arcToRelative(74.7f, 74.7f, 0f, isMoreThanHalf = false, isPositiveArc = false, 72.5f, 72.5f)
                horizontalLineToRelative(294.3f)
                arcToRelative(74.7f, 74.7f, 0f, isMoreThanHalf = false, isPositiveArc = false, 72.5f, -72.5f)
                verticalLineToRelative(-145f)
                horizontalLineToRelative(145f)
                arcToRelative(72.5f, 72.5f, 0f, isMoreThanHalf = false, isPositiveArc = false, 55.4f, -123.6f)
                close()
                moveTo(729.5f, 439.5f)
                horizontalLineToRelative(-72.5f)
                verticalLineToRelative(217.5f)
                lineTo(362.8f, 657f)
                verticalLineToRelative(-217.5f)
                lineTo(145.3f, 439.5f)
                lineTo(511.9f, 72.8f)
                lineToRelative(366.7f, 366.7f)
                horizontalLineToRelative(-149.2f)
                close()
                moveTo(695.3f, 806.2f)
                lineTo(328.6f, 806.2f)
                arcToRelative(38.5f, 38.5f, 0f, isMoreThanHalf = false, isPositiveArc = false, 0f, 76.8f)
                horizontalLineToRelative(366.7f)
                arcToRelative(38.2f, 38.2f, 0f, isMoreThanHalf = false, isPositiveArc = false, 38.5f, -38.5f)
                arcToRelative(45f, 45f, 0f, isMoreThanHalf = false, isPositiveArc = false, -38.5f, -38.5f)
                close()
                moveTo(695.3f, 951.2f)
                lineTo(328.6f, 951.2f)
                arcToRelative(38.2f, 38.2f, 0f, isMoreThanHalf = false, isPositiveArc = false, -38.5f, 38.5f)
                arcToRelative(34.8f, 34.8f, 0f, isMoreThanHalf = false, isPositiveArc = false, 38.5f, 34.1f)
                horizontalLineToRelative(366.7f)
                arcToRelative(38.2f, 38.2f, 0f, isMoreThanHalf = false, isPositiveArc = false, 38.5f, -38.5f)
                arcToRelative(40.4f, 40.4f, 0f, isMoreThanHalf = false, isPositiveArc = false, -38.5f, -34.1f)
                close()
            }
        }.build()

        return _UpdateNoBorder!!
    }

@Suppress("ObjectPropertyName")
private var _UpdateNoBorder: ImageVector? = null
