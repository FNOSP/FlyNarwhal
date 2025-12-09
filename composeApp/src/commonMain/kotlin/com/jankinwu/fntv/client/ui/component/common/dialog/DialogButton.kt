package com.jankinwu.fntv.client.ui.component.common.dialog

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import com.jankinwu.fntv.client.ui.customAccentButtonColors
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.AccentButton
import io.github.composefluent.component.Button
import io.github.composefluent.component.Text

@Composable
fun DialogAccentButton(
    text: String,
    onClick: () -> Unit,
    disabled: Boolean = false,
) {
    AccentButton(
        modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
        onClick = onClick,
        disabled = disabled,
        buttonColors = customAccentButtonColors()
    ) {
        Text(
            text,
            style = LocalTypography.current.bodyStrong,
            color = Color.White
        )
    }
}

@Composable
fun DialogSecondaryButton(
    text: String,
    onClick: () -> Unit,
    disabled: Boolean = false,
) {
    Button(
        modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
        onClick = onClick,
        disabled = disabled
    ) {
        Text(
            text,
            style = LocalTypography.current.bodyStrong,
            color = FluentTheme.colors.text.text.primary
        )
    }
}