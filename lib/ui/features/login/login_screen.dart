import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../shared/common/app_loading_progress_ring.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/log/app_talker.dart';
import '../../../data/models/login_history.dart';
import '../../../data/storage/preferences_manager.dart';
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import 'widgets/history_sidebar.dart';
import '../../shared/window_caption.dart';
import 'login_js_injection.dart';
import 'login_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const Color _primaryBlue = Color(0xFF3A7BFF);
  static const Color _hintColor = Color(0xFF9BA0A6);
  static const Color _textColor = Color(0xFFE6E8EC);
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '5666');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fnIdController = TextEditingController();

  bool _isHttps = false;
  bool _rememberPassword = false;
  bool _isNasLogin = false;
  bool _showHistorySidebar = false;
  bool _passwordVisible = false;
  bool _showFnConnectWebView = false;
  bool _isProbeMode = false;
  bool _isFinalizing = false;
  bool _allowAutoLogin = false;
  bool _autoLoginFromHistory = false;
  String _fnConnectUrl = '';
  String _displayHost = '';
  int _displayPort = 0;
  String _baseUrl = '';
  String _autoLoginUsername = '';
  String _autoLoginPassword = '';
  String _capturedUsername = '';
  String _capturedPassword = '';
  bool _capturedRememberPassword = false;
  InAppWebViewController? _inAppWebViewController;
  _NetworkMessageProcessor? _networkMessageProcessor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final history = ref.read(loginHistoryNotifierProvider);
      if (history.isNotEmpty) {
        final last = history.first;
        unawaited(_populateFields(last, allowAutoLogin: false));
      }
    });
  }

  @override
  void dispose() {
    _disposeWebView();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fnIdController.dispose();
    super.dispose();
  }

  Future<void> _populateFields(
    LoginHistory item, {
    bool allowAutoLogin = false,
  }) async {
    final passwordResult = await ref
        .read(loginHistoryPasswordServiceProvider)
        .decryptForDisplay(item);
    if (!mounted) {
      return;
    }
    if (passwordResult.shouldClear) {
      await ref.read(loginHistoryNotifierProvider.notifier).clearPassword(item);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      final displayHost = item.displayHost;
      final displayPort = item.displayPort ?? item.port;
      _hostController.text = displayHost.isEmpty ? item.host : displayHost;
      _portController.text = displayPort.toString();
      _usernameController.text = item.username;
      _passwordController.text = passwordResult.password ?? '';
      _isHttps = item.isHttps;
      _rememberPassword = item.rememberPassword;
      _isNasLogin = item.isNasLogin;
      _fnIdController.text = item.fnId;
      _displayHost = _hostController.text;
      _displayPort = displayPort;
      _autoLoginFromHistory = allowAutoLogin;
    });
  }

  void _toggleHistorySidebar() {
    setState(() => _showHistorySidebar = !_showHistorySidebar);
  }

  void _hideHistorySidebar() {
    setState(() => _showHistorySidebar = false);
  }

  void _onLogin() async {
    final host = _hostController.text;
    final port = int.tryParse(_portController.text) ?? 5666;
    final username = _usernameController.text;
    final password = _passwordController.text;
    final fnId = _fnIdController.text;
    AppTalker.info(
      'Login',
      'start: isNasLogin=$_isNasLogin host="$host" port=$port fnId="$fnId" isHttps=$_isHttps',
    );

    if (_isNasLogin) {
      _displayHost = fnId.trim();
      _displayPort = 0;
      // Use the actual HTTPS switch state, matching KMP behavior.
      final url = _normalizeFnConnectUrl(fnId, _isHttps);
      AppTalker.info('Login', 'nas login: normalizedUrl="$url"');
      if (url.isEmpty) {
        AppTalker.warning('Login', 'nas login: empty url, abort');
        _showErrorDialog('请输入 FN ID');
        return;
      }
      final shouldAutoLogin =
          _autoLoginFromHistory && _rememberPassword && password.isNotEmpty;
      _openFnConnectWebView(
        url: url,
        isProbe: false,
        autoLoginUsername: username,
        autoLoginPassword: shouldAutoLogin ? password : null,
        allowAutoLogin: shouldAutoLogin,
      );
      return;
    }

    final needsProbe = _needsProbe(host);
    AppTalker.info('Login', 'needsProbe=$needsProbe');
    if (needsProbe) {
      _displayHost = host.trim();
      _displayPort = port;
      final probeUrl = _normalizeFnConnectUrl(host, true);
      AppTalker.info('Login', 'probe: normalizedUrl="$probeUrl"');
      if (probeUrl.isEmpty) {
        AppTalker.warning('Login', 'probe: empty url, abort');
        _showErrorDialog('请输入正确的 IP、域名或 FN ID');
        return;
      }
      _openFnConnectWebView(url: probeUrl, isProbe: true);
      return;
    }

    try {
      _displayHost = host.trim();
      _displayPort = port;
      AppTalker.info('Login', 'direct login start');
      await ref.read(loginViewModelProvider.notifier).login(
            host: host,
            port: port,
            username: username,
            password: password,
            isHttps: _isHttps,
            rememberPassword: _rememberPassword,
            isNasLogin: false,
            fnId: null,
            displayHost: _displayHost,
            displayPort: _displayPort,
          );
      AppTalker.info('Login', 'direct login success, navigate');
      if (mounted) context.go('/home');
    } catch (e) {
      AppTalker.warning('Login', 'direct login error: $e');
      _showErrorDialog(e.toString());
    }
  }

  void _openFnConnectWebView({
    required String url,
    required bool isProbe,
    String? autoLoginUsername,
    String? autoLoginPassword,
    bool allowAutoLogin = false,
  }) {
    final normalizedUrl = _normalizeFnConnectUrl(url, true);
    _baseUrl = _originFromUrl(normalizedUrl);
    _allowAutoLogin = allowAutoLogin;
    _autoLoginUsername = autoLoginUsername?.trim() ?? '';
    _autoLoginPassword = autoLoginPassword ?? '';
    // Clear WebView cookies before opening to prevent stale login sessions.
    // This ensures every NAS login starts from a clean /login page so JS hooks
    // can reliably capture subsequent status requests and trigger the signin flow.
    CookieManager.instance().deleteAllCookies();
    setState(() {
      _fnConnectUrl = normalizedUrl;
      _showFnConnectWebView = true;
      _isProbeMode = isProbe;
    });
    _prepareNetworkProcessor();
  }

  void _prepareNetworkProcessor() {
    final prefs = ref.read(preferencesManagerProvider);
    final dioClient = ref.read(dioClientProvider);
    // Initialize network processor for NAS auth flow
    AppTalker.info('LoginBridge', 'prepare network processor');
    _networkMessageProcessor = _NetworkMessageProcessor(
      dioClient: dioClient,
      preferencesManager: prefs,
      onError: _showErrorDialog,
      setCookie: _setWebViewCookie,
      loadUrl: _loadWebViewUrl,
      onLoginSuccess: _onNasLoginSuccess,
      onBaseUrlChange: (value) => _baseUrl = value,
      fnId: _fnIdController.text.trim(),
      autoLoginUsername: _autoLoginUsername,
    );
  }

  material.ThemeData _buildMaterialTheme() {
    return material.ThemeData(
      useMaterial3: true,
      brightness: material.Brightness.dark,
      colorScheme: material.ColorScheme.fromSeed(
        seedColor: _primaryBlue,
        brightness: material.Brightness.dark,
      ),
    );
  }

  Widget _withClickCursor(Widget child) {
    // Show a pointer cursor for clickable controls on desktop/web platforms.
    return MouseRegion(cursor: SystemMouseCursors.click, child: child);
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String placeholder,
    Widget? suffixIcon,
    VoidCallback? onSuffixTap,
    bool obscureText = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return GlassTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      suffixIcon: suffixIcon,
      onSuffixTap: onSuffixTap,
      inputFormatters: inputFormatters,
      textStyle: const TextStyle(color: _textColor, fontSize: 16),
      placeholderStyle: const TextStyle(color: _hintColor, fontSize: 13),
      shape: const LiquidRoundedSuperellipse(borderRadius: 10),
    );
  }

  String _originFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return '';
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$portPart';
  }

  WebUri? _tryParseWebUri(String url) {
    final normalizedUrl = url.trim();
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return null;
    return WebUri(normalizedUrl);
  }

  List<String> _buildUsernameHistory(List<LoginHistory> history) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in history) {
      final username = item.username.trim();
      if (username.isEmpty) continue;
      if (seen.add(username)) {
        result.add(username);
      }
    }
    return result;
  }

  Future<void> _injectInAppWebViewScript(List<LoginHistory> history) async {
    final controller = _inAppWebViewController;
    if (controller == null) return;
    // Inject login helper script for mobile/web WebView
    AppTalker.info('LoginBridge', 'inject script for InAppWebView');
    final script = LoginJsInjectionBuilder(
      autoLoginUsernameLiteral: jsonEncode(_autoLoginUsername),
      autoLoginPasswordLiteral: jsonEncode(_autoLoginPassword),
      allowAutoLogin: _allowAutoLogin,
      usernameHistoryJsonLiteral: jsonEncode(_buildUsernameHistory(history)),
    ).build();
    await controller.evaluateJavascript(source: script);
  }

  void _handlePageUrl(String url) {
    final normalized = _stripQuotes(url);
    if (_handleBridgeMessageFromUrl(normalized)) {
      AppTalker.info('LoginBridge', 'handled bridge url');
      return;
    }
    _updateBaseUrlFromUrl(normalized);
    if (_isProbeMode) {
      final baseUrl = _extractBaseUrlFromLogin(normalized);
      if (baseUrl == null) return;
      final uri = Uri.tryParse(baseUrl);
      if (uri == null || uri.host.isEmpty) return;
      final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
      _isProbeMode = false;
      setState(() {
        _showFnConnectWebView = false;
      });
      _disposeWebView();
      _hostController.text = uri.host;
      _portController.text = (uri.hasPort ? uri.port : 0).toString();
      _isHttps = scheme == 'https';
      _finalizeLogin();
    }
  }

  bool _handleBridgeMessageFromUrl(String url) {
    final hashIndex = url.indexOf('#flynarwhal_bridge');
    if (hashIndex == -1) return false;
    final fragment = url.substring(hashIndex + 1);
    final queryIndex = fragment.indexOf('?');
    if (queryIndex == -1) {
      AppTalker.warning('LoginBridge', 'invalid fragment="$fragment"');
      return false;
    }
    final query = fragment.substring(queryIndex + 1);
    final uri = Uri.tryParse('scheme://bridge?$query');
    if (uri == null) {
      AppTalker.warning(
        'LoginBridge',
        'parse failed queryLength=${query.length}',
      );
      return false;
    }
    final method = uri.queryParameters['method'] ?? '';
    final params = uri.queryParameters['params'] ?? '';
    if (method.isEmpty) {
      AppTalker.warning(
        'LoginBridge',
        'empty method queryLength=${query.length}',
      );
      return false;
    }
    String decodedParams;
    try {
      decodedParams = Uri.decodeComponent(params);
    } catch (e) {
      AppTalker.warning(
        'LoginBridge',
        'decode failed method="$method" paramsLength=${params.length} error=$e',
      );
      decodedParams = params;
    }
    AppTalker.info(
      'LoginBridge',
      'receive message method="$method" paramsLength=${params.length} decodedLength=${decodedParams.length}',
    );
    _handleJsBridgeMessage(method, decodedParams);
    return true;
  }

  void _updateBaseUrlFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    _baseUrl = '$scheme://${uri.host}$portPart';
  }

  void _handleJsBridgeMessage(String method, String params) {
    if (method == 'CaptureLoginInfo') {
      try {
        final data = jsonDecode(params);
        if (data is! Map) return;
        _capturedUsername = (data['username'] ?? '').toString();
        _capturedPassword = (data['password'] ?? '').toString();
        _capturedRememberPassword = data['rememberPassword'] == true;
      } catch (_) {}
      return;
    }
    if (method == 'LogNetwork') {
      AppTalker.info('LoginBridge', 'receive network log payload');
      _handleNetworkLog(params);
    }
  }

  Future<void> _handleNetworkLog(String params) async {
    final processor = _networkMessageProcessor;
    if (processor == null) {
      AppTalker.warning('LoginBridge', 'skip network log: processor=null');
      return;
    }
    AppTalker.info(
      'LoginBridge',
      'process network log baseUrl="$_baseUrl" capturedUser="${_capturedUsername.isNotEmpty}" remember=$_capturedRememberPassword',
    );
    await processor.process(
      params: params,
      baseUrl: _baseUrl,
      displayHost: _displayHost,
      displayPort: _displayPort,
      isHttps: _isHttps,
      capturedUsername: _capturedUsername,
      capturedPassword: _capturedPassword,
      capturedRememberPassword: _capturedRememberPassword,
    );
  }

  Future<void> _setWebViewCookie(
      String baseUrl, String name, String value) async {
    if (baseUrl.isEmpty || name.isEmpty) return;
    final uri = Uri.tryParse(baseUrl);
    final webUri = _tryParseWebUri(baseUrl);
    if (uri == null || webUri == null) return;
    await CookieManager.instance().setCookie(
      url: webUri,
      name: name,
      value: value,
      path: '/',
      isSecure: uri.scheme == 'https',
    );
  }

  Future<void> _loadWebViewUrl(String url) async {
    if (url.isEmpty) return;
    final controller = _inAppWebViewController;
    if (controller == null) return;
    final webUri = _tryParseWebUri(url);
    if (webUri == null) return;
    await controller.loadUrl(urlRequest: URLRequest(url: webUri));
  }

  Future<void> _reloadLoginWebView() async {
    if (!_showFnConnectWebView) return;
    await _inAppWebViewController?.reload();
  }

  Future<void> _onNasLoginSuccess(_NasLoginResult result) async {
    final prefs = ref.read(preferencesManagerProvider);
    await prefs.saveToken(result.token);
    await prefs.saveCookie(result.cookie);
    await prefs.saveBaseUrl(result.baseUrl);
    await prefs.saveLoginHistory(result.history);
    ref.invalidate(loginHistoryNotifierProvider);

    // Clear cached user info so the next home entry validates
    // permissions for the newly authenticated NAS session.
    ref.read(userInfoProvider.notifier).clear();

    // Clear WebView cookies after login so the next NAS login starts fresh.
    // Account credentials are managed exclusively by the app (PreferencesManager),
    // not by WebView's persistent session storage.
    CookieManager.instance().deleteAllCookies();

    final refreshNotifier = ref.read(authRefreshProvider.notifier);
    refreshNotifier.state = refreshNotifier.state + 1;
    if (!mounted) return;
    setState(() {
      _showFnConnectWebView = false;
    });
    _disposeWebView();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(loginHistoryNotifierProvider);
    final loginState = ref.watch(loginViewModelProvider);
    final globalRefreshManager = ref.read(globalRefreshManagerProvider);
    final titleBarRefreshVisibility =
        ref.watch(titleBarRefreshVisibilityProvider);

    // Consume the global refresh only when the login WebView overlay is active.
    ref.listen<GlobalRefreshRequest?>(
      currentGlobalRefreshRequestProvider,
      (_, next) {
        if (!_showFnConnectWebView) {
          return;
        }
        unawaited(
          globalRefreshManager.handleRefresh(
            consumerId: 'login-webview',
            request: next,
            refreshBaseMediaLibrary: false,
            onRefresh: _reloadLoginWebView,
          ),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      globalRefreshManager.updateCurrentRoutePath('/login');
    });

    final isWindows = !kIsWeb && Platform.isWindows;
    final isLinux = !kIsWeb && Platform.isLinux;
    final isMacOS = !kIsWeb && Platform.isMacOS;
    final showWindowCaption = isWindows || isLinux;
    const double kMacOSTrafficLightInset = 80.0;

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          if (showWindowCaption)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: WindowCaption(
                brightness: Brightness.dark,
                backgroundColor: Colors.transparent,
                showRefreshAction:
                    titleBarRefreshVisibility.shouldShowRefreshAction,
                onRefreshPressed: () => globalRefreshManager.requestRefresh(),
              ),
            ),
          Positioned.fill(
            top: showWindowCaption ? kWindowTitleBarHeight : 0,
            child: Center(
              child: AdaptiveLiquidGlassLayer(
                settings:
                    const LiquidGlassSettings(thickness: 24.0, blur: 12.0),
                child: GlassContainer(
                  width: 420,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                  shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                  child: material.Theme(
                    data: _buildMaterialTheme(),
                    child: material.Material(
                      type: material.MaterialType.transparency,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: SvgPicture.asset(
                              'assets/images/fnarwhal_login.svg',
                              width: 174,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text('Fly Narwhal',
                                style:
                                    TextStyle(color: _hintColor, fontSize: 16)),
                          ),
                          const SizedBox(height: 28),
                          if (_isNasLogin)
                            _buildGlassField(
                              controller: _fnIdController,
                              placeholder: '请输入 IP:Port、域名或 FN ID',
                              onChanged: (_) => _autoLoginFromHistory = false,
                              suffixIcon: const Icon(material.Icons.history,
                                  color: _hintColor, size: 20),
                              onSuffixTap: _toggleHistorySidebar,
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildGlassField(
                                    controller: _hostController,
                                    placeholder: '请输入 IP、域名或 FN ID',
                                    onChanged: (_) =>
                                        _autoLoginFromHistory = false,
                                    suffixIcon: const Icon(
                                        material.Icons.history,
                                        color: _hintColor,
                                        size: 20),
                                    onSuffixTap: _toggleHistorySidebar,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: _buildGlassField(
                                    controller: _portController,
                                    placeholder: '端口',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (_) =>
                                        _autoLoginFromHistory = false,
                                  ),
                                ),
                              ],
                            ),
                          if (!_isNasLogin) ...[
                            const SizedBox(height: 16),
                            _buildGlassField(
                              controller: _usernameController,
                              placeholder: '用户名',
                              onChanged: (_) => _autoLoginFromHistory = false,
                            ),
                            const SizedBox(height: 16),
                            _buildGlassField(
                              controller: _passwordController,
                              placeholder: '密码',
                              obscureText: !_passwordVisible,
                              onChanged: (_) => _autoLoginFromHistory = false,
                              suffixIcon: Icon(
                                _passwordVisible
                                    ? material.Icons.visibility
                                    : material.Icons.visibility_off,
                                color: _hintColor,
                                size: 20,
                              ),
                              onSuffixTap: () => setState(
                                  () => _passwordVisible = !_passwordVisible),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _withClickCursor(
                                  material.Checkbox(
                                    value: _rememberPassword,
                                    onChanged: (v) => setState(() {
                                      _rememberPassword = v ?? false;
                                      _autoLoginFromHistory = false;
                                    }),
                                    activeColor: _primaryBlue,
                                  ),
                                ),
                                const Expanded(
                                  child: Text('记住密码',
                                      style: TextStyle(color: _textColor)),
                                ),
                                _withClickCursor(
                                  material.TextButton(
                                    onPressed: () {},
                                    child: const Text('忘记密码'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Expanded(
                                child: Text('使用 NAS 登录',
                                    style: TextStyle(color: _hintColor)),
                              ),
                              _withClickCursor(
                                GlassSwitch(
                                  value: _isNasLogin,
                                  onChanged: (v) => setState(() {
                                    _isNasLogin = v;
                                    _autoLoginFromHistory = false;
                                  }),
                                  activeColor: _primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Expanded(
                                child: Text('HTTPS 安全访问',
                                    style: TextStyle(color: _hintColor)),
                              ),
                              _withClickCursor(
                                GlassSwitch(
                                  value: _isHttps,
                                  onChanged: (v) =>
                                      setState(() => _isHttps = v),
                                  activeColor: _primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _withClickCursor(
                            GlassButton.custom(
                              key: const ValueKey('login-submit'),
                              onTap: _onLogin,
                              height: 48,
                              enabled: !loginState.isLoading,
                              shape: const LiquidRoundedSuperellipse(
                                  borderRadius: 10),
                              child: loginState.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: AppLoadingProgressRing(
                                          size: 22, strokeWidth: 2),
                                    )
                                  : Text(_isNasLogin ? '下一步' : '登录',
                                      style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // History sidebar backdrop
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showHistorySidebar ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 280),
              curve: _showHistorySidebar ? Curves.easeOut : Curves.easeIn,
              child: IgnorePointer(
                ignoring: !_showHistorySidebar,
                child: GestureDetector(
                  onTap: _hideHistorySidebar,
                  child: Container(color: const Color(0x8A000000)),
                ),
              ),
            ),
          ),
          // History sidebar panel
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: ClipRect(
              child: AnimatedSlide(
                offset:
                    _showHistorySidebar ? Offset.zero : const Offset(-1.0, 0.0),
                duration: const Duration(milliseconds: 280),
                curve: _showHistorySidebar ? Curves.easeOut : Curves.easeIn,
                child: AnimatedOpacity(
                  opacity: _showHistorySidebar ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 280),
                  child: IgnorePointer(
                    ignoring: !_showHistorySidebar,
                    child: HistorySidebar(
                      historyList: history,
                      onDismiss: _hideHistorySidebar,
                      onDelete: (item) {
                        ref
                            .read(loginHistoryNotifierProvider.notifier)
                            .delete(item);
                      },
                      onSelect: (item) async {
                        final canAutoLogin = item.rememberPassword &&
                            (item.password ?? '').isNotEmpty;
                        // Await field population so decrypted credentials are
                        // available before _onLogin reads them for auto-fill.
                        await _populateFields(
                          item,
                          allowAutoLogin: item.isNasLogin && canAutoLogin,
                        );
                        if (!mounted) return;
                        _hideHistorySidebar();
                        // Auto-trigger login from history.
                        // NAS login items always open the WebView (JS auto-clicks
                        // login/authorize only when canAutoLogin is true).
                        // Normal login items directly login when password is saved,
                        // otherwise just fill the form for manual submission.
                        if (item.isNasLogin || canAutoLogin) {
                          _onLogin();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showFnConnectWebView)
            Positioned.fill(
              child: Acrylic(
                tint: Colors.black.withValues(alpha: 0.7),
                blurAmount: 30,
                shape: const RoundedRectangleBorder(),
                child: Column(
                  children: [
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          if (isMacOS)
                            const SizedBox(width: kMacOSTrafficLightInset),
                          _withClickCursor(
                            Button(
                              child: const Text('关闭'),
                              onPressed: () {
                                setState(() {
                                  _showFnConnectWebView = false;
                                });
                                _disposeWebView();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('正在验证服务器...',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: InAppWebView(
                        initialUrlRequest:
                            URLRequest(url: _tryParseWebUri(_fnConnectUrl)),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          incognito: true,
                          cacheEnabled: false,
                        ),
                        onWebViewCreated: (controller) {
                          _inAppWebViewController = controller;
                        },
                        onLoadStop: (controller, url) async {
                          if (url == null) return;
                          _handlePageUrl(url.toString());
                          await _injectInAppWebViewScript(history);
                        },
                        onUpdateVisitedHistory: (controller, url, _) async {
                          if (url == null) return;
                          _handlePageUrl(url.toString());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _disposeWebView({bool keepProcessor = false}) {
    _inAppWebViewController = null;
    if (!keepProcessor) {
      _networkMessageProcessor = null;
    }
  }

  String _normalizeFnConnectUrl(String input, bool https) {
    final raw = input.trim();
    if (raw.isEmpty) return '';
    final hasScheme = raw.startsWith('http://') || raw.startsWith('https://');
    if (hasScheme) return raw;
    final slashIndex = raw.indexOf('/');
    final host = slashIndex == -1 ? raw : raw.substring(0, slashIndex);
    final path = slashIndex == -1 ? '' : raw.substring(slashIndex);
    final normalizedHost = host.contains('.') ? host : '5ddd.com/$host';
    final protocolPrefix = normalizedHost.contains('5ddd.com') ||
            normalizedHost.contains('fnos.net')
        ? 'https://'
        : (https ? 'https://' : 'http://');
    return '$protocolPrefix$normalizedHost$path';
  }

  bool _needsProbe(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) return false;
    if (!h.contains('.')) return true;
    if (h.contains('5ddd.com') || h.contains('fnos.net')) return true;
    return false;
  }

  String _stripQuotes(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('"') &&
        trimmed.endsWith('"') &&
        trimmed.length > 1) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  String? _extractBaseUrlFromLogin(String url) {
    final normalized = _stripQuotes(url);
    final index = normalized.indexOf('/login');
    if (index == -1) return null;
    return normalized.substring(0, index);
  }

  Future<void> _finalizeLogin({String? displayHost, int? displayPort}) async {
    if (_isFinalizing) {
      AppTalker.info('Login', 'finalize login skipped: already running');
      return;
    }
    _isFinalizing = true;
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? 0;
    final username = _usernameController.text;
    final password = _passwordController.text;
    try {
      AppTalker.info(
        'Login',
        'finalize login start: host="$host" port=$port isHttps=$_isHttps',
      );
      await ref.read(loginViewModelProvider.notifier).login(
            host: host,
            port: port,
            username: username,
            password: password,
            isHttps: _isHttps,
            rememberPassword: _rememberPassword,
            isNasLogin: false,
            displayHost: displayHost ?? _displayHost,
            displayPort: displayPort ?? _displayPort,
          );
      AppTalker.info('Login', 'finalize login success, navigate');
      final prefs = ref.read(preferencesManagerProvider);
      final token = prefs.getToken();
      final baseUrl = prefs.getBaseUrl();
      AppTalker.info(
        'Login',
        'prefs after login: token=${token != null} tokenLength=${token?.length ?? 0} baseUrl=${baseUrl != null}',
      );
      final refreshNotifier = ref.read(authRefreshProvider.notifier);
      refreshNotifier.state = refreshNotifier.state + 1;
      AppTalker.info(
        'Login',
        'auth refresh from screen=${refreshNotifier.state}',
      );
      if (mounted) context.go('/home');
    } catch (e) {
      AppTalker.warning('Login', 'finalize login error: $e');
      _showErrorDialog(e.toString());
    } finally {
      _isFinalizing = false;
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          _withClickCursor(
            Button(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _NasLoginResult {
  final String token;
  final String cookie;
  final String baseUrl;
  final List<LoginHistory> history;

  const _NasLoginResult({
    required this.token,
    required this.cookie,
    required this.baseUrl,
    required this.history,
  });
}

class _NetworkMessageProcessor {
  _NetworkMessageProcessor({
    required this.dioClient,
    required this.preferencesManager,
    required this.onError,
    required this.setCookie,
    required this.loadUrl,
    required this.onLoginSuccess,
    required this.onBaseUrlChange,
    required this.fnId,
    required this.autoLoginUsername,
  });

  final DioClient dioClient;
  final PreferencesManager preferencesManager;
  final void Function(String message) onError;
  final Future<void> Function(String baseUrl, String name, String value)
      setCookie;
  final Future<void> Function(String url) loadUrl;
  final Future<void> Function(_NasLoginResult result) onLoginSuccess;
  final void Function(String baseUrl) onBaseUrlChange;
  final String fnId;
  final String autoLoginUsername;

  bool _isAuthRequested = false;
  bool _isSysConfigInFlight = false;
  bool _isSysConfigLoaded = false;

  // Route network logs to NAS OAuth flow handlers
  Future<void> process({
    required String params,
    required String baseUrl,
    required String displayHost,
    required int displayPort,
    required bool isHttps,
    required String capturedUsername,
    required String capturedPassword,
    required bool capturedRememberPassword,
  }) async {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(params);
      if (decoded is! Map) return;
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    final url = (payload['url'] ?? '').toString();
    if (url.isEmpty) return;
    var currentBaseUrl = baseUrl;
    final derivedBaseUrl = _originFromUrl(url);
    if (derivedBaseUrl.isNotEmpty && derivedBaseUrl != currentBaseUrl) {
      AppTalker.info(
        'LoginBridge',
        'baseUrl updated from url="$url" baseUrl="$derivedBaseUrl"',
      );
      onBaseUrlChange(derivedBaseUrl);
      currentBaseUrl = derivedBaseUrl;
    }
    AppTalker.info(
      'LoginBridge',
      'network url="$url" baseUrl="$currentBaseUrl"',
    );
    if (url.contains('/sac/rpcproxy/v1/new-user-guide/status')) {
      await _handleStatusMessage(payload, currentBaseUrl);
      return;
    }
    if (url.contains('/v/api/v1/sys/config')) {
      await _handleSysConfigMessage(payload, currentBaseUrl);
      return;
    }
    if (url.contains('/oauthapi/authorize')) {
      await _handleOauthAuthorize(
        payload,
        currentBaseUrl,
        displayHost,
        displayPort,
        isHttps,
        capturedUsername,
        capturedPassword,
        capturedRememberPassword,
      );
    }
  }

  Future<void> _handleStatusMessage(
      Map<String, dynamic> payload, String baseUrl) async {
    if (_isSysConfigLoaded || _isSysConfigInFlight) return;
    final cookie = _extractCookie(payload);
    if (cookie == null || cookie.isEmpty) return;
    final normalizedCookie = _normalizeRelayCookie(cookie, baseUrl);
    await _fetchSysConfig(baseUrl, normalizedCookie);
  }

  Future<void> _handleSysConfigMessage(
      Map<String, dynamic> payload, String baseUrl) async {
    if (_isSysConfigLoaded) return;
    final body = (payload['body'] ?? '').toString();
    final cookie = _extractCookie(payload);
    // Determine whether the JS-fetched body is a usable sys/config response.
    // The in-page fetch lacks the signature header (authx), so the NAS often
    // rejects it with {"code":5000,"msg":"invalid sign"} or returns the FN
    // Connect relay HTML. In those cases, re-fetch via the native Dio client
    // which injects authx through the AuthInterceptor.
    final bool jsBodyValid = payload['validSysConfig'] == true ||
        (body.contains('nas_oauth') && body.contains('app_id'));
    if (jsBodyValid) {
      if (body.isEmpty) return;
      await _handleSysConfigBody(baseUrl, body, cookie);
      return;
    }
    // Fallback: native signed request. Requires a cookie and a real NAS base.
    if (cookie == null || cookie.isEmpty) return;
    if (_isSysConfigInFlight) return;
    final normalizedCookie = _normalizeRelayCookie(cookie, baseUrl);
    await _fetchSysConfig(baseUrl, normalizedCookie);
  }

  Future<void> _fetchSysConfig(String baseUrl, String cookie) async {
    if (baseUrl.isEmpty) return;
    _isSysConfigInFlight = true;
    try {
      // Authx is injected by the AuthInterceptor.
      final response = await dioClient.dio.get(
        '$baseUrl/v/api/v1/sys/config',
        options: Options(
          headers: {
            'Cookie': cookie,
          },
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        await _handleSysConfigBody(baseUrl, jsonEncode(data), cookie);
      }
      _isSysConfigInFlight = false;
    } catch (e) {
      // Keep silent and allow a later status/sysconfig message to retry,
      // since the very first attempt right after login can fail transiently.
      _isSysConfigInFlight = false;
    }
  }

  Future<void> _handleSysConfigBody(
      String baseUrl, String body, String? cookie) async {
    Map<String, dynamic> jsonBody;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return;
      jsonBody = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    final data = jsonBody['data'];
    if (data is! Map) return;
    final oauth = data['nas_oauth'];
    if (oauth is! Map) return;
    final appId = (oauth['app_id'] ?? '').toString();
    if (appId.isEmpty) return;
    final oauthUrl = (oauth['url'] ?? '').toString();
    final targetBaseUrl =
        (oauthUrl.isNotEmpty && oauthUrl != '://') ? oauthUrl : baseUrl;
    if (targetBaseUrl.isEmpty) return;
    // Build OAuth URL from sys config
    AppTalker.info(
      'LoginBridge',
      'sys config resolved oauthBase="$targetBaseUrl"',
    );
    onBaseUrlChange(targetBaseUrl);
    final redirectUri = '$targetBaseUrl/v/oauth/result';
    final targetUrl =
        '$targetBaseUrl/signin?client_id=$appId&redirect_uri=$redirectUri';
    if (cookie != null && cookie.isNotEmpty) {
      await _applyCookieToDomain(targetBaseUrl, cookie);
    }
    _isSysConfigLoaded = true;
    _isSysConfigInFlight = false;
    await loadUrl(targetUrl);
  }

  Future<void> _handleOauthAuthorize(
    Map<String, dynamic> payload,
    String baseUrl,
    String displayHost,
    int displayPort,
    bool isHttps,
    String capturedUsername,
    String capturedPassword,
    bool capturedRememberPassword,
  ) async {
    if (_isAuthRequested) return;
    final payloadUrl = payload['url']?.toString() ?? '';
    final derivedBaseUrl = _originFromUrl(payloadUrl);
    final resolvedBaseUrl =
        derivedBaseUrl.isNotEmpty ? derivedBaseUrl : baseUrl;
    if (resolvedBaseUrl.isNotEmpty && resolvedBaseUrl != baseUrl) {
      AppTalker.info(
        'LoginBridge',
        'oauth baseUrl sync="$resolvedBaseUrl" from url="$payloadUrl"',
      );
      onBaseUrlChange(resolvedBaseUrl);
    }
    AppTalker.info(
      'LoginBridge',
      'oauth authorize received baseUrl="$resolvedBaseUrl" payloadKeys=${payload.keys.join(',')}',
    );
    final directCode = payload['code']?.toString();
    var code = directCode ?? '';
    if (code.isEmpty) {
      final body = payload['body']?.toString() ?? '';
      if (body.isNotEmpty) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            final data = decoded['data'];
            if (data is Map && data['code'] != null) {
              code = data['code'].toString();
            }
          }
        } catch (_) {}
      }
    }
    if (code.isEmpty) {
      AppTalker.warning(
        'LoginBridge',
        'oauth code empty, skip token exchange',
      );
      return;
    }
    // Exchange OAuth code for token
    AppTalker.info(
      'LoginBridge',
      'oauth code captured, exchange token codeLength=${code.length}',
    );
    _isAuthRequested = true;
    try {
      final token = await _exchangeCodeForToken(resolvedBaseUrl, code);
      if (token.isEmpty) {
        _isAuthRequested = false;
        onError('登录失败: Token 为空');
        return;
      }
      final relayCookie =
          _normalizeRelayCookie('Trim-MC-token=$token', resolvedBaseUrl);
      final username = capturedUsername.trim().isNotEmpty
          ? capturedUsername.trim()
          : autoLoginUsername.trim();
      final shouldRemember =
          capturedRememberPassword && capturedPassword.isNotEmpty;
      final historyItem = LoginHistory(
        host: '',
        port: 0,
        username: username,
        password: shouldRemember ? capturedPassword : null,
        isHttps: isHttps,
        rememberPassword: shouldRemember,
        isNasLogin: true,
        fnConnectUrl: baseUrl,
        fnId: fnId,
        displayHost: displayHost,
        displayPort: displayPort == 0 ? null : displayPort,
      );
      final currentHistory = preferencesManager.getLoginHistory();
      final updatedHistory =
          currentHistory.where((element) => element != historyItem).toList();
      updatedHistory.insert(0, historyItem);
      AppTalker.info(
        'LoginBridge',
        'oauth success, history=${updatedHistory.length}',
      );
      await onLoginSuccess(
        _NasLoginResult(
          token: token,
          cookie: relayCookie,
          baseUrl: resolvedBaseUrl,
          history: updatedHistory,
        ),
      );
    } catch (e) {
      _isAuthRequested = false;
      onError('登录失败: $e');
    }
  }

  Future<String> _exchangeCodeForToken(String baseUrl, String code) async {
    if (baseUrl.isEmpty) {
      AppTalker.warning(
        'LoginBridge',
        'exchange token aborted: baseUrl empty',
      );
      return '';
    }
    AppTalker.info(
      'LoginBridge',
      'exchange token request baseUrl="$baseUrl" codeLength=${code.length}',
    );
    // Authx is injected by the AuthInterceptor.
    final response = await dioClient.dio.post(
      '$baseUrl/v/api/v1/auth',
      data: {'source': 'Trim-NAS', 'code': code},
      options: Options(
        followRedirects: true,
        validateStatus: (status) =>
            status != null && status >= 200 && status <= 302,
      ),
    );
    AppTalker.info(
      'LoginBridge',
      'exchange token response status=${response.statusCode} contentType=${response.headers.value('content-type')}',
    );
    final data = response.data;
    if (data is Map) {
      AppTalker.info(
        'LoginBridge',
        'exchange token payload keys=${data.keys.join(',')}',
      );
      final codeValue = data['code'];
      if (codeValue is int && codeValue != 0) {
        final msg = data['msg']?.toString() ?? '认证失败';
        throw Exception(msg);
      }
      final body = data['data'];
      if (body is Map && body['token'] != null) {
        final tokenValue = body['token'].toString();
        AppTalker.info(
          'LoginBridge',
          'exchange token success tokenLength=${tokenValue.length}',
        );
        return tokenValue;
      }
      AppTalker.warning(
        'LoginBridge',
        'exchange token body missing token bodyKeys=${body is Map ? body.keys.join(',') : body.runtimeType}',
      );
      return '';
    }
    AppTalker.warning(
      'LoginBridge',
      'exchange token unexpected responseType=${data.runtimeType}',
    );
    return '';
  }

  String _originFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return '';
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$portPart';
  }

  String? _extractCookie(Map<String, dynamic> payload) {
    final direct = payload['cookie']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final headers = payload['headers'];
    if (headers is Map) {
      final lowered = headers.map((key, value) =>
          MapEntry(key.toString().toLowerCase(), value.toString()));
      final cookie = lowered['set-cookie'] ?? lowered['cookie'];
      if (cookie != null && cookie.isNotEmpty) return cookie;
    }
    if (headers is String) {
      final lines = headers.split('\n');
      for (final line in lines) {
        final parts = line.split(':');
        if (parts.length < 2) continue;
        final key = parts.first.trim().toLowerCase();
        final value = parts.sublist(1).join(':').trim();
        if (key == 'set-cookie' || key == 'cookie') {
          if (value.isNotEmpty) return value;
        }
      }
    }
    return null;
  }

  String _normalizeRelayCookie(String cookie, String baseUrl) {
    if (!baseUrl.contains('5ddd.com') && !baseUrl.contains('fnos.net')) {
      return cookie;
    }
    if (cookie.contains('mode=relay')) {
      return cookie;
    }
    return '$cookie; mode=relay';
  }

  Future<void> _applyCookieToDomain(String baseUrl, String cookie) async {
    final pairs = cookie.split(';');
    for (final pair in pairs) {
      final trimmed = pair.trim();
      if (trimmed.isEmpty) continue;
      final segments = trimmed.split('=');
      if (segments.length < 2) continue;
      final name = segments.first.trim();
      final value = segments.sublist(1).join('=').trim();
      if (name.isEmpty) continue;
      await setCookie(baseUrl, name, value);
    }
  }
}
