package com.jankinwu.fntv.client.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

val Server: ImageVector
    get() {
        if (_Server != null) {
            return _Server!!
        }
        _Server = ImageVector.Builder(
            name = "Server",
            defaultWidth = 200.dp,
            defaultHeight = 200.dp,
            viewportWidth = 1024f,
            viewportHeight = 1024f
        ).apply {
            path(fill = SolidColor(Color.Black)) {
                moveTo(682.7f, 256f)
                moveToRelative(-42.7f, 0f)
                arcToRelative(42.7f, 42.7f, 0f, isMoreThanHalf = true, isPositiveArc = false, 85.3f, 0f)
                arcToRelative(42.7f, 42.7f, 0f, isMoreThanHalf = true, isPositiveArc = false, -85.3f, 0f)
                close()
            }
            path(fill = SolidColor(Color.Black)) {
                moveTo(341.3f, 469.3f)
                horizontalLineToRelative(213.3f)
                verticalLineToRelative(85.3f)
                horizontalLineTo(341.3f)
                close()
            }
            path(fill = SolidColor(Color.Black)) {
                moveTo(682.7f, 512f)
                moveToRelative(-42.7f, 0f)
                arcToRelative(42.7f, 42.7f, 0f, isMoreThanHalf = true, isPositiveArc = false, 85.3f, 0f)
                arcToRelative(42.7f, 42.7f, 0f, isMoreThanHalf = true, isPositiveArc = false, -85.3f, 0f)
                close()
            }
            path(fill = SolidColor(Color.Black)) {
                moveTo(768f, 85.3f)
                lineTo(256f, 85.3f)
                curveToRelative(-46.9f, 0f, -85.3f, 38.4f, -85.3f, 85.3f)
                verticalLineToRelative(682.7f)
                curveToRelative(0f, 46.9f, 38.4f, 85.3f, 85.3f, 85.3f)
                horizontalLineToRelative(512f)
                curveToRelative(46.9f, 0f, 85.3f, -38.4f, 85.3f, -85.3f)
                lineTo(853.3f, 170.7f)
                curveToRelative(0f, -46.9f, -38.4f, -85.3f, -85.3f, -85.3f)
                close()
                moveTo(768f, 853.3f)
                lineTo(256f, 853.3f)
                verticalLineToRelative(-170.7f)
                horizontalLineToRelative(512f)
                verticalLineToRelative(170.7f)
                close()
                moveTo(768f, 597.3f)
                lineTo(256f, 597.3f)
                verticalLineToRelative(-170.7f)
                horizontalLineToRelative(512f)
                verticalLineToRelative(170.7f)
                close()
                moveTo(768f, 341.3f)
                lineTo(256f, 341.3f)
                lineTo(256f, 170.7f)
                horizontalLineToRelative(512f)
                verticalLineToRelative(170.7f)
                close()
            }
            path(fill = SolidColor(Color.Black)) {
                moveTo(682.7f, 768f)
                moveToRelative(-42.7f, 0f)
                arcToRelative(42.7f, 42.7f, 0f, isMoreThanHalf = true, isPositiveArc = false, 85.3f, 0f)
                arcToRelative(42.7f, 42.7f, 0f, isMoreThanHalf = true, isPositiveArc = false, -85.3f, 0f)
                close()
            }
        }.build()

        return _Server!!
    }

@Suppress("ObjectPropertyName")
private var _Server: ImageVector? = null