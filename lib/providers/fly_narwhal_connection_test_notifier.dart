import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../l10n/generated/app_localizations.dart';

class FlyNarwhalConnectionTestNotifier
    extends StateNotifier<AsyncValue<String?>> {
  final FlyNarwhalRemoteDataSource _remoteDataSource;
  final AppLocalizations Function() _getL10n;

  FlyNarwhalConnectionTestNotifier(this._remoteDataSource, this._getL10n)
      : super(const AsyncValue.data(null));

  Future<void> testConnection(String baseUrl) async {
    final normalizedBaseUrl = baseUrl.trim();
    final uri = Uri.tryParse(normalizedBaseUrl);
    final isValidServerUrl = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!isValidServerUrl) {
      state = AsyncValue.error(
          _getL10n().connectionTestInvalidUrl, StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final result = await _remoteDataSource.getVersion(
        baseUrl: normalizedBaseUrl,
      );
      result.when(
        success: (smartResult) {
          final version = smartResult.data?.replaceAll('-fnapp', '') ?? '';
          if (version.isEmpty) {
            state = AsyncValue.error(
              Exception(_getL10n().connectionTestNoVersion),
              StackTrace.current,
            );
            return;
          }
          state = AsyncValue.data(version);
        },
        failure: (failure) {
          state = AsyncValue.error(
            failure.displayMessage.isNotEmpty
                ? failure.displayMessage
                : failure.message,
            StackTrace.current,
          );
        },
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}
