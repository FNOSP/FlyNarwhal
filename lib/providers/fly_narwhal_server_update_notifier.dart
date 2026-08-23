import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/log/app_talker.dart';
import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/datasources/remote/fly_narwhal_server_release_data_source.dart';

/// Lifecycle of the FlyNarwhal server self-update flow.
enum FlyNarwhalServerUpdatePhase {
  idle,
  checking,
  upToDate,
  updateAvailable,
  updating,
  waitingForRestart,
  succeeded,
  failed,
}

/// Observable state of the FlyNarwhal server self-update flow.
final class FlyNarwhalServerUpdateState {
  const FlyNarwhalServerUpdateState({
    this.phase = FlyNarwhalServerUpdatePhase.idle,
    this.message,
    this.currentVersion,
    this.targetVersion,
  });

  final FlyNarwhalServerUpdatePhase phase;
  final String? message;
  final String? currentVersion;
  final String? targetVersion;

  FlyNarwhalServerUpdateState copyWith({
    FlyNarwhalServerUpdatePhase? phase,
    String? message,
    bool clearMessage = false,
    String? currentVersion,
    String? targetVersion,
  }) {
    return FlyNarwhalServerUpdateState(
      phase: phase ?? this.phase,
      message: clearMessage ? null : message ?? this.message,
      currentVersion: currentVersion ?? this.currentVersion,
      targetVersion: targetVersion ?? this.targetVersion,
    );
  }
}

/// Orchestrates the FlyNarwhal server self-update, mirroring the KMP
/// `UpdateViewModel.checkServerUpdate` / `performServerUpdate` /
/// `pollForServerRecovery` flow.
final class FlyNarwhalServerUpdateNotifier
    extends StateNotifier<FlyNarwhalServerUpdateState> {
  FlyNarwhalServerUpdateNotifier({
    required FlyNarwhalRemoteDataSource dataSource,
    required Future<FlyNarwhalServerRelease?> Function(String tagName)
        fetchServerRelease,
    required String targetVersion,
    required bool Function() isEnabled,
    required String Function() getProxyUrl,
    DateTime Function()? now,
  })  : _dataSource = dataSource,
        _fetchServerRelease = fetchServerRelease,
        _targetVersion = targetVersion,
        _isEnabled = isEnabled,
        _getProxyUrl = getProxyUrl,
        _now = now ?? DateTime.now,
        super(const FlyNarwhalServerUpdateState());

  static const Duration _checkCooldown = Duration(seconds: 10);
  static const Duration _updateCooldown = Duration(seconds: 60);
  static const Duration _recoveryTimeout = Duration(minutes: 5);
  static const Duration _recoveryPollInterval = Duration(seconds: 5);

  final FlyNarwhalRemoteDataSource _dataSource;
  final Future<FlyNarwhalServerRelease?> Function(String tagName)
      _fetchServerRelease;
  final String _targetVersion;
  final bool Function() _isEnabled;
  final String Function() _getProxyUrl;
  final DateTime Function() _now;

  bool _checkRunning = false;
  bool _updateRunning = false;
  DateTime? _lastCheckAt;
  DateTime? _lastUpdateAt;

  /// Checks the server version and triggers a self-update when it is behind
  /// [targetVersion]. Idempotent: single-flight plus a short cooldown.
  Future<void> checkServerUpdate() async {
    if (!_isEnabled()) return;
    if (_checkRunning) return;
    final now = _now();
    if (_lastCheckAt != null &&
        now.difference(_lastCheckAt!) < _checkCooldown) {
      return;
    }
    _checkRunning = true;
    _lastCheckAt = now;
    try {
      if (!_isEnabled()) return;
      state = const FlyNarwhalServerUpdateState(
        phase: FlyNarwhalServerUpdatePhase.checking,
      );
      AppTalker.info('FlyNarwhalServerUpdate', '检查服务端版本...');
      final result = await _dataSource.getVersion();
      final current = result.dataOrNull?.data?.trim() ?? '';
      if (current.isEmpty) {
        AppTalker.error(
          'FlyNarwhalServerUpdate',
          error: result.failureOrNull ?? Exception('服务端未返回版本号'),
          message: '获取服务端版本失败',
        );
        state = FlyNarwhalServerUpdateState(
          phase: FlyNarwhalServerUpdatePhase.failed,
          message: '获取服务端版本失败',
          targetVersion: _targetVersion,
        );
        return;
      }
      AppTalker.info(
        'FlyNarwhalServerUpdate',
        '服务端版本: $current, 目标: $_targetVersion',
      );
      if (compareVersions(current, _targetVersion) < 0) {
        state = FlyNarwhalServerUpdateState(
          phase: FlyNarwhalServerUpdatePhase.updateAvailable,
          currentVersion: current,
          targetVersion: _targetVersion,
        );
        await _performServerUpdate(
          _targetVersion,
          preferFnAppJar: current.endsWith('-fnapp'),
        );
      } else {
        state = FlyNarwhalServerUpdateState(
          phase: FlyNarwhalServerUpdatePhase.upToDate,
          currentVersion: current,
          targetVersion: _targetVersion,
        );
      }
    } catch (error, stackTrace) {
      AppTalker.error(
        'FlyNarwhalServerUpdate',
        error: error,
        stackTrace: stackTrace,
        message: '检查服务端更新异常',
      );
      state = FlyNarwhalServerUpdateState(
        phase: FlyNarwhalServerUpdatePhase.failed,
        message: '检查服务端更新异常: $error',
      );
    } finally {
      _checkRunning = false;
    }
  }

  Future<void> _performServerUpdate(
    String targetVersion, {
    required bool preferFnAppJar,
  }) async {
    if (_updateRunning) return;
    final now = _now();
    if (_lastUpdateAt != null &&
        now.difference(_lastUpdateAt!) < _updateCooldown) {
      return;
    }
    _updateRunning = true;
    _lastUpdateAt = now;
    try {
      AppTalker.info(
        'FlyNarwhalServerUpdate',
        '拉取服务端 release: v$targetVersion',
      );
      final release = await _fetchServerRelease('v$targetVersion');
      if (release == null) {
        AppTalker.warning(
          'FlyNarwhalServerUpdate',
          '目标版本 $targetVersion 在 GitHub 上没有发布',
        );
        state = state.copyWith(
          phase: FlyNarwhalServerUpdatePhase.failed,
          message: '服务端更新包未找到',
        );
        return;
      }

      final asset = _selectAsset(release, preferFnAppJar: preferFnAppJar);
      if (asset == null) {
        AppTalker.warning(
          'FlyNarwhalServerUpdate',
          '目标版本 $targetVersion 没有可用的 jar 资产',
        );
        state = state.copyWith(
          phase: FlyNarwhalServerUpdatePhase.failed,
          message: '服务端更新包资产缺失',
        );
        return;
      }

      AppTalker.info(
        'FlyNarwhalServerUpdate',
        '开始服务端自更新: ${asset.browserDownloadUrl}',
      );
      state = state.copyWith(
        phase: FlyNarwhalServerUpdatePhase.updating,
        message: '开始服务端更新...',
      );

      final started = await _streamStartUpdate(
        downloadUrl: asset.browserDownloadUrl,
        hash: asset.digest,
        proxyUrl: _getProxyUrl(),
      );
      if (!started) {
        return;
      }

      await _pollForRecovery();
    } catch (error, stackTrace) {
      AppTalker.error(
        'FlyNarwhalServerUpdate',
        error: error,
        stackTrace: stackTrace,
        message: '服务端更新失败',
      );
      state = state.copyWith(
        phase: FlyNarwhalServerUpdatePhase.failed,
        message: '服务端更新失败: $error',
      );
    } finally {
      _updateRunning = false;
    }
  }

  FlyNarwhalServerAsset? _selectAsset(
    FlyNarwhalServerRelease release, {
    required bool preferFnAppJar,
  }) {
    bool isJar(String name) =>
        !name.contains('sources') && !name.contains('javadoc');
    final candidates = <FlyNarwhalServerAsset>[];
    if (preferFnAppJar) {
      candidates.addAll(
        release.assets.where(
          (asset) => asset.name.endsWith('.jar.fnapp') && isJar(asset.name),
        ),
      );
    }
    candidates.addAll(
      release.assets.where(
        (asset) => asset.name.endsWith('.jar') && isJar(asset.name),
      ),
    );
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<bool> _streamStartUpdate({
    required String downloadUrl,
    String? hash,
    required String proxyUrl,
  }) async {
    await for (final status in _dataSource.startUpdate(
      downloadUrl: downloadUrl,
      hash: hash,
      proxyUrl: proxyUrl,
    )) {
      AppTalker.info('FlyNarwhalServerUpdate', '服务端更新状态: $status');
      state = state.copyWith(message: status);
      if (status.contains('started') || status.contains('restart')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pollForRecovery() async {
    state = state.copyWith(
      phase: FlyNarwhalServerUpdatePhase.waitingForRestart,
      message: '等待服务端重启...',
    );
    final deadline = _now().add(_recoveryTimeout);
    var connected = false;
    while (_now().isBefore(deadline)) {
      await Future<void>.delayed(_recoveryPollInterval);
      try {
        final result = await _dataSource.getVersion();
        final version = result.dataOrNull?.data?.trim() ?? '';
        if (result.isSuccess && version.isNotEmpty) {
          connected = true;
          state = FlyNarwhalServerUpdateState(
            phase: FlyNarwhalServerUpdatePhase.succeeded,
            message: '服务端已更新到 $version',
            currentVersion: version,
            targetVersion: _targetVersion,
          );
          AppTalker.info('FlyNarwhalServerUpdate', '服务端恢复，新版本: $version');
          break;
        }
      } catch (_) {
        // 重启期间的连接中断是正常现象，继续轮询。
      }
    }
    if (!connected) {
      state = state.copyWith(
        phase: FlyNarwhalServerUpdatePhase.failed,
        message: '服务端更新超时，请检查服务端日志',
      );
      AppTalker.error(
        'FlyNarwhalServerUpdate',
        error: TimeoutException('服务端恢复超时'),
        message: '服务端恢复超时',
      );
    }
    await Future<void>.delayed(_recoveryPollInterval);
    state = state.copyWith(clearMessage: true);
  }

  /// Compares version strings, ignoring any `-suffix` (e.g. `-fnapp`), exactly
  /// mirroring the KMP `compareVersions` semantics. Deliberately not using
  /// [SemanticVersion], whose prerelease ordering would treat `0.6.4-fnapp`
  /// as older than `0.6.4` and wrongly trigger an update.
  static int compareVersions(String v1, String v2) {
    final base1 = v1.split('-').first;
    final base2 = v2.split('-').first;
    final parts1 = base1.split('.').map(int.tryParse).toList();
    final parts2 = base2.split('.').map(int.tryParse).toList();
    final length = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (var i = 0; i < length; i++) {
      final p1 = i < parts1.length ? (parts1[i] ?? 0) : 0;
      final p2 = i < parts2.length ? (parts2[i] ?? 0) : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }
}
