import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';

import '../../../../core/network/ssl/ssl_trust_manager.dart';
import '../../../../providers/providers.dart';
import '../../../shared/dialogs/app_dialog.dart';

/// The trusted-certificate list, shown as a dialog.
///
/// Reads the list from the provider rather than taking it as a parameter so a
/// removal inside the dialog is reflected immediately without the caller having
/// to rebuild.
class SslWhitelistDialog extends ConsumerWidget {
  const SslWhitelistDialog({super.key});

  /// How far the scrollbar is pushed to the right of the scrollable area,
  /// mirroring the shortcut settings dialog so both dialogs look the same.
  static const double _scrollbarOffset = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(settingsProvider).sslWhitelist;
    final secondaryTextColor =
        FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.7);

    return AppDialog<bool>(
      title: 'SSL 证书信任列表',
      constraints: const BoxConstraints(
        minWidth: 420,
        maxWidth: 520,
        maxHeight: 640,
      ),
      content: entries.isEmpty
          ? Text(
              key: const ValueKey('settings-ssl-whitelist-empty'),
              '暂无信任的证书。当服务器证书校验失败时，可以在提示中选择「信任此证书」。',
              style: TextStyle(fontSize: 13, color: secondaryTextColor),
            )
          : SizedBox(
              width: double.infinity,
              // The list can outgrow the dialog; scroll it so the actions stay
              // reachable instead of overflowing. Same scrollbar treatment as
              // the shortcut settings dialog.
              child: ScrollbarTheme.merge(
                data: const ScrollbarThemeData(
                  crossAxisMargin: -_scrollbarOffset,
                  hoveringCrossAxisMargin: -_scrollbarOffset,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 12),
                  children: [
                    for (final group in _groupByHost(entries))
                      Padding(
                        key: ValueKey(
                          'settings-ssl-whitelist-host-${group.host}',
                        ),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HostGroup(
                          group: group,
                          secondaryTextColor: secondaryTextColor,
                          onRemove: (entry) =>
                              _confirmRemove(context, ref, entry),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      // The tertiary slot is the left-aligned slot for an additional
      // destructive action, which is exactly what "clear all" is.
      tertiaryButtonText: entries.isEmpty ? null : '全部清除',
      onTertiaryPressed: () => _confirmClear(context, ref),
      primaryButtonText: '关闭',
      primaryResult: true,
      autoDismiss: true,
    );
  }

  /// Groups entries by host, preserving the order hosts first appear in.
  ///
  /// Several certificates can be trusted for one host (a rotated certificate, or
  /// the same hostname on a different port), and listing the hostname once per
  /// certificate reads like a duplicate.
  static List<_SslHostGroup> _groupByHost(List<SslTrustEntry> entries) {
    final groups = <String, List<SslTrustEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.host, () => <SslTrustEntry>[]).add(entry);
    }
    return groups.entries
        .map((e) => _SslHostGroup(host: e.key, entries: e.value))
        .toList(growable: false);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    SslTrustEntry entry,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      type: AppDialogType.danger,
      title: '移除信任的证书',
      content: Text(
        '移除后，再次访问「${entry.host}」时该证书会重新校验。',
      ),
      secondaryButtonText: '取消',
      primaryButtonText: '移除',
      secondaryResult: false,
      primaryResult: true,
      autoDismiss: true,
    );
    if (confirmed != true) return;
    await ref.read(settingsProvider.notifier).removeSslWhitelistEntry(entry);
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      type: AppDialogType.danger,
      title: '清除全部信任的证书',
      content: const Text('清除后，所有服务器的证书都会重新校验。'),
      secondaryButtonText: '取消',
      primaryButtonText: '全部清除',
      secondaryResult: false,
      primaryResult: true,
      autoDismiss: true,
    );
    if (confirmed != true) return;
    await ref.read(settingsProvider.notifier).clearSslWhitelist();
  }
}

/// One host and every certificate trusted for it.
class _SslHostGroup {
  const _SslHostGroup({required this.host, required this.entries});

  final String host;
  final List<SslTrustEntry> entries;
}

/// A host header with its trusted certificates listed underneath.
///
/// A host with a single certificate renders as one compact row; a host with
/// several indents them so the hostname is not repeated.
class _HostGroup extends StatelessWidget {
  const _HostGroup({
    required this.group,
    required this.secondaryTextColor,
    required this.onRemove,
  });

  final _SslHostGroup group;
  final Color? secondaryTextColor;
  final Future<void> Function(SslTrustEntry entry) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The host is the group header; every certificate under it is indented
        // to the same level, whether the group holds one or several.
        Text(
          group.host,
          key: ValueKey('settings-ssl-whitelist-host-label-${group.host}'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        for (final entry in group.entries) _row(entry),
      ],
    );
  }

  Widget _row(SslTrustEntry entry) {
    return Padding(
      key: ValueKey(
        'settings-ssl-whitelist-item-${entry.host}-${entry.fingerprintSha256}',
      ),
      padding: const EdgeInsets.only(left: _certificateIndent, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // Reserve the fingerprint column so the timestamps line up
                // down the list instead of drifting with each value's width.
                SizedBox(
                  width: _fingerprintColumnWidth,
                  child: Text(
                    shortFingerprint(entry.fingerprintSha256),
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
                if (entry.addedAt != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '添加时间：${_formatAddedAt(entry.addedAt!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppButton(
            key: ValueKey(
              'settings-ssl-whitelist-remove-'
              '${entry.host}-${entry.fingerprintSha256}',
            ),
            onPressed: () => onRemove(entry),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }
}

/// Horizontal offset of a certificate row from its host header.
const double _certificateIndent = 16;

/// Width reserved for the 8-character short fingerprint, so every row's
/// timestamp starts at the same x.
const double _fingerprintColumnWidth = 64;

/// Formats a trust timestamp as `yyyy-MM-dd HH:mm` in local time.
///
/// Hand-rolled rather than using `intl`: the app has no date-format
/// initialisation for this locale, and the pattern is fixed.
String _formatAddedAt(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
