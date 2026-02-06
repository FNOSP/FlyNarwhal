import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/storage/preferences_manager.dart';
import '../data/network/dio_client.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final preferencesManagerProvider = Provider<PreferencesManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesManager(prefs);
});

final dioClientProvider = Provider<DioClient>((ref) {
  final prefsManager = ref.watch(preferencesManagerProvider);
  return DioClient(prefsManager);
});
