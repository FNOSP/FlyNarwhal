package com.jankinwu.fntv.client.icons


import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathData
import androidx.compose.ui.graphics.vector.group
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp
val Setting: ImageVector
    get() {
        if (_Setting != null) {
            return _Setting!!
        }
        _Setting = ImageVector.Builder(
            name = "Setting",
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
                    fill = SolidColor(Color.White),
                    fillAlpha = 0.8f
                ) {
                    moveTo(15.6f, 12f)
                    curveTo(15.6f, 10.02f, 13.98f, 8.4f, 12f, 8.4f)
                    curveTo(10.02f, 8.4f, 8.4f, 10.02f, 8.4f, 12f)
                    curveTo(8.4f, 13.98f, 10.02f, 15.6f, 12f, 15.6f)
                    curveTo(13.98f, 15.6f, 15.6f, 13.98f, 15.6f, 12f)
                    close()
                    moveTo(4.8f, 12f)
                    curveTo(4.8f, 11.67f, 4.82f, 11.36f, 4.86f, 11.06f)
                    curveTo(4.86f, 11.06f, 2.85f, 9.48f, 2.85f, 9.48f)
                    curveTo(2.66f, 9.34f, 2.61f, 9.09f, 2.73f, 8.87f)
                    curveTo(2.73f, 8.87f, 4.65f, 5.55f, 4.65f, 5.55f)
                    curveTo(4.77f, 5.33f, 5.02f, 5.25f, 5.24f, 5.33f)
                    curveTo(5.24f, 5.33f, 7.63f, 6.29f, 7.63f, 6.29f)
                    curveTo(8.12f, 5.91f, 8.66f, 5.59f, 9.25f, 5.35f)
                    curveTo(9.25f, 5.35f, 9.61f, 2.81f, 9.61f, 2.81f)
                    curveTo(9.64f, 2.57f, 9.84f, 2.4f, 10.08f, 2.4f)
                    curveTo(10.08f, 2.4f, 13.92f, 2.4f, 13.92f, 2.4f)
                    curveTo(14.16f, 2.4f, 14.35f, 2.57f, 14.4f, 2.81f)
                    curveTo(14.4f, 2.81f, 14.76f, 5.35f, 14.76f, 5.35f)
                    curveTo(15.35f, 5.59f, 15.88f, 5.91f, 16.38f, 6.29f)
                    curveTo(16.38f, 6.29f, 18.77f, 5.33f, 18.77f, 5.33f)
                    curveTo(18.99f, 5.26f, 19.24f, 5.33f, 19.36f, 5.55f)
                    curveTo(19.36f, 5.55f, 21.28f, 8.87f, 21.28f, 8.87f)
                    curveTo(21.39f, 9.07f, 21.34f, 9.34f, 21.16f, 9.48f)
                    curveTo(21.16f, 9.48f, 19.13f, 11.06f, 19.13f, 11.06f)
                    curveTo(19.18f, 11.36f, 19.2f, 11.69f, 19.2f, 12f)
                    curveTo(19.2f, 12.31f, 19.16f, 12.64f, 19.11f, 12.94f)
                    curveTo(19.11f, 12.94f, 21.14f, 14.52f, 21.14f, 14.52f)
                    curveTo(21.34f, 14.66f, 21.38f, 14.92f, 21.26f, 15.13f)
                    curveTo(21.26f, 15.13f, 19.35f, 18.45f, 19.35f, 18.45f)
                    curveTo(19.23f, 18.67f, 18.98f, 18.75f, 18.76f, 18.67f)
                    curveTo(18.76f, 18.67f, 16.37f, 17.71f, 16.37f, 17.71f)
                    curveTo(15.88f, 18.08f, 15.34f, 18.41f, 14.75f, 18.65f)
                    curveTo(14.75f, 18.65f, 14.39f, 21.19f, 14.39f, 21.19f)
                    curveTo(14.35f, 21.43f, 14.16f, 21.6f, 13.92f, 21.6f)
                    curveTo(13.92f, 21.6f, 10.08f, 21.6f, 10.08f, 21.6f)
                    curveTo(9.84f, 21.6f, 9.64f, 21.43f, 9.6f, 21.19f)
                    curveTo(9.6f, 21.19f, 9.24f, 18.65f, 9.24f, 18.65f)
                    curveTo(8.65f, 18.41f, 8.12f, 18.09f, 7.62f, 17.71f)
                    curveTo(7.62f, 17.71f, 5.23f, 18.67f, 5.23f, 18.67f)
                    curveTo(5.01f, 18.74f, 4.76f, 18.67f, 4.64f, 18.45f)
                    curveTo(4.64f, 18.45f, 2.72f, 15.13f, 2.72f, 15.13f)
                    curveTo(2.61f, 14.93f, 2.66f, 14.66f, 2.84f, 14.52f)
                    curveTo(2.84f, 14.52f, 4.87f, 12.94f, 4.87f, 12.94f)
                    curveTo(4.82f, 12.64f, 4.8f, 12.32f, 4.8f, 12f)
                    close()
                }
            }
        }.build()

        return _Setting!!
    }

@Suppress("ObjectPropertyName")
private var _Setting: ImageVector? = null