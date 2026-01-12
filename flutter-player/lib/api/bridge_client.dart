import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bridge_models.dart';

class BridgeApiClient {
  static const String _baseUrl = 'http://127.0.0.1:47921';

  Future<ProxyConfig> getProxyConfig() async {
    final response = await http.get(Uri.parse('$_baseUrl/proxy-config'));
    if (response.statusCode == 200) {
      return ProxyConfig.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load proxy config');
    }
  }

  Future<AppSettings> getAppSettings() async {
    final response = await http.get(Uri.parse('$_baseUrl/settings/app'));
    if (response.statusCode == 200) {
      return AppSettings.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load app settings');
    }
  }

  Future<void> updateAppSettings(AppSettings settings) async {
    await http.post(
      Uri.parse('$_baseUrl/settings/app'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(settings.toJson()),
    );
  }

  Future<PlayerSettings> getPlayerSettings() async {
    final response = await http.get(Uri.parse('$_baseUrl/settings/player'));
    if (response.statusCode == 200) {
      return PlayerSettings.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load player settings');
    }
  }

  Future<void> updatePlayerSettings(PlayerSettings settings) async {
    await http.post(
      Uri.parse('$_baseUrl/settings/player'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(settings.toJson()),
    );
  }

  Future<void> updateIntroOutroSettings(int introEndMs, int outroStartMs) async {
    await http.post(
      Uri.parse('$_baseUrl/settings/intro-outro'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'introEndMs': introEndMs,
        'outroStartMs': outroStartMs,
      }),
    );
  }
}
