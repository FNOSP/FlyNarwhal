import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/log/app_talker.dart';
import '../core/utils/sliding_window_rate_limiter.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/shared/toast.dart';
import '../data/datasources/remote/fly_narwhal_server_release_data_source.dart';
import 'fly_narwhal_server_update_notifier.dart';

/// Checks whether the server repository has a release newer than the version
/// the connected server reports, purely to tell the user to update it through
/// the fnOS app center. Unlike [FlyNarwhalServerUpdateNotifier] this never
/// touches the server; the app center is where fnOS installs and updates it.
final class FlyNarwhalServerUpdateAvailableNotifier
    extends StateNotifier<String?> {
  FlyNarwhalServerUpdateAvailableNotifier({
    required Future<FlyNarwhalServerRelease?> Function() fetchLatestRelease,
    required bool Function() isEnabled,
    DateTime Function()? now,
  })  : _fetchLatestRelease = fetchLatestRelease,
        _isEnabled = isEnabled,
        _latestReleaseLimiter = SlidingWindowRateLimiter(
          maxCalls: maxLatestReleaseFetchesPerHour,
          window: latestReleaseFetchWindow,
          now: now,
        ),
        super(null);

  final Future<FlyNarwhalServerRelease?> Function() _fetchLatestRelease;
  final bool Function() _isEnabled;

  /// GitHub rate-limits unauthenticated callers, so the repository is asked
  /// for its latest release at most twice in any rolling hour, app-wide.
  static const int maxLatestReleaseFetchesPerHour = 2;
  static const Duration latestReleaseFetchWindow = Duration(hours: 1);

  final SlidingWindowRateLimiter _latestReleaseLimiter;

  bool _running = false;

  /// The newest release version, when it is ahead of [currentVersion]; null
  /// otherwise. Never throws: a failed lookup just leaves nothing to report.
  Future<String?> check(String currentVersion) async {
    final current = currentVersion.trim();
    if (current.isEmpty || !_isEnabled()) return null;
    if (_running) return state;
    if (!_latestReleaseLimiter.tryAcquire()) {
      AppTalker.info(
        'FlyNarwhalServerUpdate',
        '本小时已查询服务端最新版本 $maxLatestReleaseFetchesPerHour 次，跳过本次查询',
      );
      return state;
    }
    _running = true;
    try {
      final release = await _fetchLatestRelease();
      if (!mounted) return null;
      final tag = release?.tagName.trim() ?? '';
      // Release tags carry a `v` prefix (`v2.1.0`); the server reports the
      // bare version. compareVersions compares only the numeric part anyway.
      final latest = tag.startsWith('v') || tag.startsWith('V')
          ? tag.substring(1)
          : tag;
      if (latest.isEmpty) {
        AppTalker.info('FlyNarwhalServerUpdate', '未找到服务端最新 release，跳过更新提示');
        return null;
      }
      final isNewer =
          FlyNarwhalServerUpdateNotifier.compareVersions(latest, current) > 0;
      AppTalker.info(
        'FlyNarwhalServerUpdate',
        '服务端版本 $current，仓库最新 $latest，有新版本=$isNewer',
      );
      state = isNewer ? latest : null;
      return state;
    } catch (error) {
      AppTalker.warning('FlyNarwhalServerUpdate', '检查服务端最新版本失败: $error');
      return null;
    } finally {
      _running = false;
    }
  }
}

/// Shows the "new server release" toast for [version], if a check found one.
///
/// One category, so the startup check and a settings-page check that both see
/// the same release collapse into a single toast instead of stacking.
void showServerUpdateAvailableToast(
  WidgetRef ref,
  AppLocalizations l10n,
  String? version,
) {
  if (version == null) return;
  ref.read(toastManagerProvider.notifier).showToast(
        l10n.settingsServerUpdateAvailable(version),
        type: ToastType.info,
        category: 'fly-narwhal-server-update',
        coalesce: true,
      );
}
