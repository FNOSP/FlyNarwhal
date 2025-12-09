package com.jankinwu.fntv.client.ui.component.common.dialog

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ProgressIndicatorDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.BuildConfig
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.manager.UpdateInfo
import com.jankinwu.fntv.client.manager.UpdateStatus
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.DialogSize
import io.github.composefluent.component.FluentDialog
import io.github.composefluent.component.Text

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UpdateDialog(
    status: UpdateStatus,
    onDownload: (UpdateInfo) -> Unit,
    onInstall: (UpdateInfo) -> Unit,
    onDismiss: () -> Unit
) {
    if (status !is UpdateStatus.Idle) {
        FluentDialog(
            visible = true,
            size = DialogSize.Standard
        ) {
            Column(modifier = Modifier.padding(24.dp)) {
                when (status) {
                    is UpdateStatus.Checking -> {
                        Text("检查更新中...", style = FluentTheme.typography.bodyLarge)
                    }

                    is UpdateStatus.Available -> {
                        Text("更新", style = FluentTheme.typography.subtitle)
                        Spacer(Modifier.height(12.dp))
                        Text("有新版本可以更新。最新版本为 ${status.info.version}，当前版本为 ${BuildConfig.VERSION_NAME}")
                        Spacer(Modifier.height(12.dp))
                        Text("【更新内容】")
                        Spacer(Modifier.height(8.dp))
                        Text(status.info.releaseNotes)
                        Spacer(Modifier.height(24.dp))
                        Row(
                            horizontalArrangement = Arrangement.End,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            DialogSecondaryButton("稍后再说", onClick = onDismiss)
                            Spacer(Modifier.width(8.dp))
                            DialogAccentButton("下载更新", onClick = { onDownload(status.info) })
                        }
                    }

                    is UpdateStatus.Downloading -> {
                        Text("下载中...", style = FluentTheme.typography.subtitle)
                        Spacer(Modifier.height(12.dp))
                        LinearProgressIndicator(
                            progress = { status.progress },
                            modifier = Modifier.fillMaxWidth(),
                            color = Colors.AccentColorDefault,
                            trackColor = Color.DarkGray.copy(alpha = 0.4f),
                            strokeCap = ProgressIndicatorDefaults.CircularDeterminateStrokeCap,
                            gapSize = 0.dp,
                            drawStopIndicator = {}
                        )
                        Spacer(Modifier.height(8.dp))
                        val currentMb = FnDataConvertor.formatToMb(status.currentBytes)
                        val totalMb = FnDataConvertor.formatToMb(status.totalBytes)
                        Text("$currentMb MB / $totalMb MB")
                        Spacer(Modifier.height(24.dp))
                        Row(
                            horizontalArrangement = Arrangement.End,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            DialogSecondaryButton("取消", onClick = onDismiss)
                        }
                    }

                    is UpdateStatus.Downloaded -> {
                        Text("安装更新", style = FluentTheme.typography.subtitle)
                        Spacer(Modifier.height(12.dp))
                        Text("是否安装更新？")
                        Spacer(Modifier.height(24.dp))
                        Row(
                            horizontalArrangement = Arrangement.End,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            DialogSecondaryButton("取消", onClick = onDismiss)
                            Spacer(Modifier.width(8.dp))
                            DialogAccentButton("退出并安装", onClick = { onInstall(status.info) })
                        }
                    }

                    is UpdateStatus.Error -> {
                        Text("更新异常", style = FluentTheme.typography.subtitle)
                        Spacer(Modifier.height(12.dp))
                        Text(status.message)
                        Spacer(Modifier.height(24.dp))
                        Row(
                            horizontalArrangement = Arrangement.End,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            DialogAccentButton("好的", onClick = onDismiss)
                        }
                    }

                    is UpdateStatus.UpToDate -> {
                        Text("更新", style = FluentTheme.typography.subtitle)
                        Spacer(Modifier.height(12.dp))
                        Text("当前已是最新版本")
                        Spacer(Modifier.height(24.dp))
                        Row(
                            horizontalArrangement = Arrangement.End,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            DialogAccentButton("好的", onClick = onDismiss)
                        }
                    }

                    else -> {}
                }
            }
        }
    }
}

