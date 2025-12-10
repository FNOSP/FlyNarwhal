package com.jankinwu.fntv.client.icons


import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val VersionInfo: ImageVector
    get() {
        if (_VersionInfo != null) {
            return _VersionInfo!!
        }
        _VersionInfo = ImageVector.Builder(
            name = "VersionInfo",
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 1024f,
            viewportHeight = 1024f
        ).apply {
            path(fill = SolidColor(Color.LightGray)) {
                moveTo(512f, 102.4f)
                arcTo(409.6f, 409.6f, 0f, isMoreThanHalf = true, isPositiveArc = true, 102.4f, 512f)
                arcTo(409.6f, 409.6f, 0f, isMoreThanHalf = false, isPositiveArc = true, 512f, 102.4f)
                moveTo(512f, 0f)
                arcToRelative(512f, 512f, 0f, isMoreThanHalf = true, isPositiveArc = false, 512f, 512f)
                arcToRelative(512f, 512f, 0f, isMoreThanHalf = false, isPositiveArc = false, -512f, -512f)
                close()
            }
            path(fill = SolidColor(Color.LightGray)) {
                moveTo(460.8f, 435.2f)
                moveToRelative(51.2f, 0f)
                lineToRelative(0f, 0f)
                quadToRelative(51.2f, 0f, 51.2f, 51.2f)
                lineToRelative(0f, 238.9f)
                quadToRelative(0f, 51.2f, -51.2f, 51.2f)
                lineToRelative(0f, 0f)
                quadToRelative(-51.2f, 0f, -51.2f, -51.2f)
                lineToRelative(0f, -238.9f)
                quadToRelative(0f, -51.2f, 51.2f, -51.2f)
                close()
            }
            path(fill = SolidColor(Color.LightGray)) {
                moveTo(512f, 298.7f)
                moveToRelative(-51.2f, 0f)
                arcToRelative(51.2f, 51.2f, 0f, isMoreThanHalf = true, isPositiveArc = false, 102.4f, 0f)
                arcToRelative(51.2f, 51.2f, 0f, isMoreThanHalf = true, isPositiveArc = false, -102.4f, 0f)
                close()
            }
        }.build()

        return _VersionInfo!!
    }

@Suppress("ObjectPropertyName")
private var _VersionInfo: ImageVector? = null