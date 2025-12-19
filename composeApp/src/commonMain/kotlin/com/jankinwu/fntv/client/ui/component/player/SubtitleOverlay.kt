package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.data.model.SubtitleSettings
import com.jankinwu.fntv.client.utils.SubtitleCue

@Composable
fun SubtitleOverlay(
    subtitleCues: List<SubtitleCue>,
    currentRenderTime: Long,
    maxWidth: Dp,
    maxHeight: Dp,
    currentPosition: Long,
    settings: SubtitleSettings = SubtitleSettings()
) {
    val screenWidth = maxWidth.value
    val screenHeight = maxHeight.value
    val currentPos = currentPosition

    // Calculate vertical shift for ASS (assuming 0.1 is default/baseline)
    val verticalShift = (0.1f - settings.verticalPosition) * screenHeight

    // Separate cues into positioned (absolute) and flow (relative/stacked)
    val (positionedCues, flowCues) = subtitleCues.partition {
        val props = it.assProps
        props != null && (props.move != null || props.position != null)
    }

    // 1. Render Positioned Cues (ASS with \pos or \move)
    positionedCues.forEach { cue ->
        val props = cue.assProps!! // Safe because of partition condition
        
        // ASS Rendering logic for positioned cues
        val playResX = if (props.playResX > 0) props.playResX else 384
        val playResY = if (props.playResY > 0) props.playResY else 288

        val scaleX = screenWidth / playResX
        val scaleY = screenHeight / playResY

        // Font Size
        val fontSizeDp = props.fontSize * scaleY * settings.fontScale
        val fontSizeSp = with(LocalDensity.current) { fontSizeDp.dp.toSp() }

        // Position
        var x = 0f
        var y = 0f

        if (props.move != null) {
            val move = props.move
            val t1 = move.t1 ?: 0L
            val t2 = move.t2 ?: (cue.endTime - cue.startTime)
            val progress = (currentPos - cue.startTime).coerceIn(t1, t2).toFloat()
            val duration = (t2 - t1).toFloat()
            val fraction = if (duration > 0) progress / duration else 1f

            x = move.x1 + (move.x2 - move.x1) * fraction
            y = move.y1 + (move.y2 - move.y1) * fraction
        } else if (props.position != null) {
            x = props.position.x
            y = props.position.y
        }

        // Absolute positioning with GPU acceleration
        val align = props.alignment

        Text(
            text = cue.text,
            style = TextStyle(
                fontSize = fontSizeSp,
//                        shadow = Shadow(Color.Black, Offset(1f, 1f), 2f)
            ),
            modifier = Modifier
                .layout { measurable, constraints ->
                    val placeable = measurable.measure(constraints)
                    // Place at top-left (0,0) initially, then transform
                    layout(placeable.width, placeable.height) {
                        placeable.place(0, 0)
                    }
                }
                .graphicsLayer {

                    var currX = x
                    var currY = y

                    if (props.move != null) {
                        val move = props.move
                        val t1 = move.t1 ?: 0L
                        val t2 = move.t2 ?: (cue.endTime - cue.startTime)
                        val progress = (currentRenderTime - cue.startTime).coerceIn(t1, t2).toFloat()
                        val duration = (t2 - t1).toFloat()
                        val fraction = if (duration > 0) progress / duration else 1f

                        currX = move.x1 + (move.x2 - move.x1) * fraction
                        currY = move.y1 + (move.y2 - move.y1) * fraction
                    } else if (props.position != null) {
                        currX = props.position.x
                        currY = props.position.y
                    }

                    val screenX = currX * scaleX
                    val screenY = currY * scaleY

                    // Apply alignment offset
                    // We use `this.size` which gives us the size of the Text composable
                    val pWidth = this.size.width
                    val pHeight = this.size.height

                    val offsetX = when (align % 3) {
                        1 -> 0f
                        2 -> -pWidth / 2f
                        0 -> -pWidth.toFloat()
                        else -> 0f
                    }
                    val offsetY = when ((align - 1) / 3) {
                        0 -> -pHeight.toFloat()
                        1 -> -pHeight / 2f
                        2 -> 0f
                        else -> 0f
                    }

                    translationX = screenX.dp.toPx() + offsetX
                    translationY = screenY.dp.toPx() + offsetY + verticalShift.dp.toPx()

                    // Apply Rotation
                    if (props.rotationZ != null) {
                        rotationZ = props.rotationZ
                    }

                    // Apply Opacity/Alpha
                    var finalAlpha = props.alpha ?: 1f

                    if (props.fade != null) {
                        val fade = props.fade
                        val timeIntoCue = currentRenderTime - cue.startTime
                        val timeRemaining = cue.endTime - currentRenderTime

                        if (timeIntoCue < fade.t1) {
                            finalAlpha *= (timeIntoCue.toFloat() / fade.t1.toFloat()).coerceIn(0f, 1f)
                        } else if (timeRemaining < fade.t2) {
                            finalAlpha *= (timeRemaining.toFloat() / fade.t2.toFloat()).coerceIn(0f, 1f)
                        }
                    }
                    alpha = finalAlpha
                }
                .then(
                    if (props.clip != null) {
                        Modifier.clip(object : Shape {
                            override fun createOutline(
                                size: androidx.compose.ui.geometry.Size,
                                layoutDirection: LayoutDirection,
                                density: Density
                            ): Outline {
                                val clip = props.clip


                                val cx1 = clip.x1 * scaleX
                                val cy1 = clip.y1 * scaleY
                                val cx2 = clip.x2 * scaleX
                                val cy2 = clip.y2 * scaleY

                                var currX = x
                                var currY = y
                                if (props.position != null) {
                                    currX = props.position.x
                                    currY = props.position.y
                                }
                                // Ignore move for clip rect calculation for now (assume text is at pos)

                                val screenX = currX * scaleX
                                val screenY = currY * scaleY

                                // Re-calculate alignment offset (same logic)
                                // We need pWidth/pHeight. `size` parameter gives us that!
                                val pWidth = size.width
                                val pHeight = size.height

                                val offsetX = when (align % 3) {
                                    1 -> 0f
                                    2 -> -pWidth / 2f
                                    0 -> -pWidth
                                    else -> 0f
                                }
                                val offsetY = when ((align - 1) / 3) {
                                    0 -> -pHeight
                                    1 -> -pHeight / 2f
                                    2 -> 0f
                                    else -> 0f
                                }

                                val transX = with(density) { screenX.dp.toPx() } + offsetX
                                val transY = with(density) { screenY.dp.toPx() } + offsetY + with(density) { verticalShift.dp.toPx() }

                                val localCx1 = with(density) { cx1.dp.toPx() } - transX
                                val localCy1 = with(density) { cy1.dp.toPx() } - transY
                                val localCx2 = with(density) { cx2.dp.toPx() } - transX
                                val localCy2 = with(density) { cy2.dp.toPx() } - transY

                                val path = Path()
                                path.addRect(androidx.compose.ui.geometry.Rect(localCx1, localCy1, localCx2, localCy2))
                                return Outline.Generic(path)
                            }
                        })
                    } else Modifier
                )
        )
    }

    // 2. Render Flow Cues (Stacked based on alignment)
    if (flowCues.isNotEmpty()) {
        val groupedCues = flowCues.groupBy { it.assProps?.alignment ?: 2 }

        groupedCues.forEach { (align, cues) ->
            // Map alignment to Compose Alignment
            val alignment = when (align) {
                1 -> Alignment.BottomStart
                2 -> Alignment.BottomCenter
                3 -> Alignment.BottomEnd
                4 -> Alignment.CenterStart
                5 -> Alignment.Center
                6 -> Alignment.CenterEnd
                7 -> Alignment.TopStart
                8 -> Alignment.TopCenter
                9 -> Alignment.TopEnd
                else -> Alignment.BottomCenter
            }

            // Map alignment to Horizontal Alignment for Column
            val horizontalAlignment = when (align % 3) {
                1 -> Alignment.Start
                2 -> Alignment.CenterHorizontally
                0 -> Alignment.End
                else -> Alignment.CenterHorizontally
            }
            
            // Only apply vertical position adjustment for bottom-aligned subtitles (1, 2, 3)
            val bottomPadding = if (align in 1..3) (maxHeight * settings.verticalPosition) else 0.dp

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = bottomPadding),
                contentAlignment = alignment
            ) {
                Column(
                    horizontalAlignment = horizontalAlignment
                ) {
                    cues.forEach { cue ->
                        val props = cue.assProps
                        if (props != null) {
                            // ASS Flow Rendering
                            val playResY = if (props.playResY > 0) props.playResY else 288
                            val scaleY = screenHeight / playResY
                            val fontSizeDp = props.fontSize * scaleY * settings.fontScale
                            val fontSizeSp = with(LocalDensity.current) { fontSizeDp.dp.toSp() }

                            Text(
                                text = cue.text,
                                style = TextStyle(
                                    fontSize = fontSizeSp
                                ),
                                textAlign = TextAlign.Center // Default to center for text content
                            )
                        } else {
                            // Legacy/Simple Rendering for non-ASS
                            Text(
                                text = cue.text,
                                style = TextStyle(
                                    color = Color.White,
                                    fontSize = 40.sp * settings.fontScale,
                                    fontWeight = FontWeight.Bold,
                                    shadow = Shadow(
                                        color = Color.Black,
                                        offset = Offset(2f, 2f),
                                        blurRadius = 4f
                                    )
                                ),
                                textAlign = TextAlign.Center,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
