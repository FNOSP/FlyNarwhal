package com.jankinwu.fntv.client.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.data.constants.Colors
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.CheckBoxColor
import io.github.composefluent.component.ListItemColor
import io.github.composefluent.component.SwitcherStyle
import io.github.composefluent.scheme.PentaVisualScheme

@Stable
@Composable
fun selectedSwitcherStyle(
    default: SwitcherStyle = SwitcherStyle(
        fillColor = Color(0xFF3A7BFF),
        labelColor = FluentTheme.colors.text.text.primary,
        controlColor = FluentTheme.colors.text.onAccent.primary,
        controlSize = DpSize(width = 12.dp, height = 12.dp),
        borderBrush = SolidColor(Color.Transparent)
    ),
    hovered: SwitcherStyle = default.copy(
        fillColor = Color(0xFF3A7BFF),
        controlSize = DpSize(width = 14.dp, height = 14.dp)
    ),
    pressed: SwitcherStyle = default.copy(
        fillColor = Color(0xFF3A7BFF),
        controlSize = DpSize(width = 17.dp, height = 14.dp)
    ),
    disabled: SwitcherStyle = default.copy(
        fillColor = FluentTheme.colors.fillAccent.disabled,
        borderBrush = SolidColor(FluentTheme.colors.fillAccent.disabled),
        controlColor = FluentTheme.colors.text.onAccent.disabled,
        labelColor = FluentTheme.colors.text.text.disabled
    )
) = SwitcherStyleScheme(
    default = default,
    hovered = hovered,
    pressed = pressed,
    disabled = disabled
)

typealias SwitcherStyleScheme = PentaVisualScheme<SwitcherStyle>

@Stable
@Composable
fun selectedCheckBoxColors(
    default: CheckBoxColor = CheckBoxColor(
        fillColor = Color(0xFF3A7BFF),
        contentColor = Color.White,
        borderColor = Color.Transparent,
        labelTextColor = Colors.TextSecondaryColor
    ),
    hovered: CheckBoxColor = default.copy(
        fillColor = Color(0xFF3A7BFF),
    ),
    pressed: CheckBoxColor = default.copy(
        fillColor = FluentTheme.colors.fillAccent.tertiary,
        contentColor = FluentTheme.colors.text.onAccent.secondary
    ),
    disabled: CheckBoxColor = CheckBoxColor(
        fillColor = FluentTheme.colors.fillAccent.disabled,
        contentColor = FluentTheme.colors.text.onAccent.disabled,
        borderColor = FluentTheme.colors.fillAccent.disabled,
        labelTextColor = Colors.TextSecondaryColor
    )
) = CheckBoxColorScheme(
    default = default,
    hovered = hovered,
    pressed = pressed,
    disabled = disabled
)

typealias CheckBoxColorScheme = PentaVisualScheme<CheckBoxColor>

@Composable
@Stable
fun FlyoutTitleItemColors(
    default: ListItemColor = ListItemColor(
        fillColor = FluentTheme.colors.subtleFill.transparent,
        contentColor = FluentTheme.colors.text.text.primary,
        trailingColor = FluentTheme.colors.text.text.secondary,
        borderBrush = SolidColor(Color.Transparent)
    ),
    hovered: ListItemColor = default.copy(
        fillColor = FluentTheme.colors.subtleFill.transparent
    ),
    pressed: ListItemColor = default.copy(
        fillColor = FluentTheme.colors.subtleFill.transparent,
        contentColor = FluentTheme.colors.text.text.secondary
    ),
    disabled: ListItemColor = default.copy(
        fillColor = FluentTheme.colors.subtleFill.disabled,
        contentColor = FluentTheme.colors.text.text.disabled,
        trailingColor = FluentTheme.colors.text.text.disabled,
    )
) = ListItemColorScheme(
    default = default,
    hovered = hovered,
    pressed = pressed,
    disabled = disabled
)

typealias ListItemColorScheme = PentaVisualScheme<ListItemColor>