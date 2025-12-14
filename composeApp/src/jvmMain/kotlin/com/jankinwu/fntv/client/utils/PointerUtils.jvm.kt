package com.jankinwu.fntv.client.utils

import androidx.compose.ui.input.pointer.PointerIcon
import java.awt.BasicStroke
import java.awt.Color
import java.awt.Point
import java.awt.RenderingHints
import java.awt.Toolkit
import java.awt.image.BufferedImage

actual val HiddenPointerIcon: PointerIcon = PointerIcon(
    Toolkit.getDefaultToolkit().createCustomCursor(
        BufferedImage(1, 1, BufferedImage.TYPE_INT_ARGB),
        Point(0, 0),
        "Hidden"
    )
)

actual val DisabledPointerIcon: PointerIcon = PointerIcon(
    Toolkit.getDefaultToolkit().createCustomCursor(
        run {
            val size = 32
            val image = BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB)
            val g = image.createGraphics()
            g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

            // Draw forbidden icon (red circle with slash)
            g.color = Color.RED
            g.stroke = BasicStroke(2f)
            val padding = 7
            g.drawOval(padding, padding, size - 2 * padding, size - 2 * padding)

            val innerPadding = 10
            // Diagonal line from top-left to bottom-right
            g.drawLine(innerPadding, innerPadding, size - innerPadding, size - innerPadding)

            g.dispose()
            image
        },
        Point(16, 16),
        "Disabled"
    )
)
