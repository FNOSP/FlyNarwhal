package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.icons.UpdateNoBorder
import com.jankinwu.fntv.client.viewmodel.UpdateViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.Icon
import io.github.composefluent.component.Text
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun HasNewVersionTag(modifier: Modifier = Modifier) {
    val updateViewModel: UpdateViewModel = koinViewModel()
    val latestVersion by updateViewModel.latestVersion.collectAsState()

    if (latestVersion != null) {
        Row(
            modifier = modifier
                .padding(start = 8.dp)
                .border(1.dp, Colors.AccentColorDefault, RoundedCornerShape(50))
                .padding(horizontal = 4.dp, vertical = 1.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                UpdateNoBorder,
                "版本升级", modifier = Modifier.size(10.dp),
                tint = Colors.AccentColorDefault
            )
            Text(
                text = "NEW",
                style = FluentTheme.typography.caption,
                color = Colors.AccentColorDefault,
                modifier = Modifier
                    .padding(start = 2.dp)
            )
        }
    }
}