import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';

class FlyNarwhalConnectionTestNotifier
    extends StateNotifier<AsyncValue<String?>> {
  final FlyNarwhalRemoteDataSource _remoteDataSource;

  FlyNarwhalConnectionTestNotifier(this._remoteDataSource)
      : super(const AsyncValue.data(null));

  Future<void> testConnection(String baseUrl) async {
    final normalizedBaseUrl = baseUrl.trim();
    final uri = Uri.tryParse(normalizedBaseUrl);
    final isValidServerUrl = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!isValidServerUrl) {
      state = AsyncValue.error('FlyNarwhal 服务端地址无效', StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final result = await _remoteDataSource.getVersion(
        baseUrl: normalizedBaseUrl,
      );
      final version = result.getOrThrow().data?.replaceAll('-fnapp', '') ?? '';
      if (version.isEmpty) {
        throw Exception('FlyNarwhal 服务端未返回版本号');
      }
      state = AsyncValue.data(version);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}
