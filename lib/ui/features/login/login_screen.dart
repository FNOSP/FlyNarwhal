import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform;
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
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/common/app_loading_progress_ring.dart';
import '../../shared/dialogs/app_dialog.dart';
import '../../shared/toast.dart';

import '../../../core/error/login_exception.dart';
import '../../../core/input/desktop_ime_service.dart';
import '../../../core/network/access_code_session.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/ssl/ssl_error_detector.dart';
import '../../../core/utils/log/app_talker.dart';
import '../../../data/models/login_history.dart';
import '../../../data/storage/preferences_manager.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../providers/global_refresh.dart';
import '../../../providers/providers.dart';
import 'widgets/history_sidebar.dart';
import '../../shared/window_caption.dart';
import 'login_js_injection.dart';
import 'login_view_model.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';

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
  final _accessCodeDialogController = TextEditingController();
  final _accessCodeFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isHttps = false;
  bool _accessCodeDialogVisible = false;
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
  WebViewEnvironment? _fnConnectWebViewEnvironment;
  _NetworkMessageProcessor? _networkMessageProcessor;

  @override
  void initState() {
    super.initState();
    _accessCodeFocusNode.addListener(_syncImeEnglishOnly);
    _passwordFocusNode.addListener(_syncImeEnglishOnly);
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
    final webViewEnvironment = _fnConnectWebViewEnvironment;
    if (webViewEnvironment != null) {
      unawaited(webViewEnvironment.dispose());
    }
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fnIdController.dispose();
    _accessCodeDialogController.dispose();
    _accessCodeFocusNode.removeListener(_syncImeEnglishOnly);
    _accessCodeFocusNode.dispose();
    _passwordFocusNode.removeListener(_syncImeEnglishOnly);
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// Keeps the OS input method in English while a credential field (the login
  /// password or the access code) holds focus, restoring it afterwards, so a
  /// CJK input method cannot be used to type into them.
  void _syncImeEnglishOnly() {
    final shouldForceEnglish =
        _passwordFocusNode.hasFocus || _accessCodeFocusNode.hasFocus;
    unawaited(
      const DesktopImeService().setEnglishOnly(shouldForceEnglish),
    );
  }

  Future<bool> _populateFields(
    LoginHistory item, {
    bool allowAutoLogin = false,
  }) async {
    final passwordResult = await ref
        .read(loginHistoryPasswordServiceProvider)
        .decryptForDisplay(item);
    if (!mounted) {
      return false;
    }
    final hasRememberedPassword =
        item.rememberPassword && (passwordResult.password?.isNotEmpty ?? false);
    if (passwordResult.shouldClear) {
      await ref.read(loginHistoryNotifierProvider.notifier).clearPassword(item);
    }
    if (!mounted) {
      return false;
    }
    setState(() {
      final displayHost = item.displayHost;
      final displayPort = item.displayPort ?? item.port;
      _hostController.text = displayHost.isEmpty ? item.host : displayHost;
      _portController.text = displayPort.toString();
      _usernameController.text = item.username;
      _passwordController.text = passwordResult.password ?? '';
      _isHttps = item.isHttps;
      _rememberPassword = hasRememberedPassword;
      _isNasLogin = item.isNasLogin;
      _fnIdController.text = item.fnId;
      _displayHost = _hostController.text;
      _displayPort = displayPort;
      _autoLoginFromHistory = allowAutoLogin;
    });
    return hasRememberedPassword;
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
        _showToast(AppLocalizations.of(context).loginHostOrFnIdPlaceholder);
        return;
      }
      final shouldAutoLogin =
          _autoLoginFromHistory && _rememberPassword && password.isNotEmpty;
      await _openFnConnectWebView(
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
        _showToast(AppLocalizations.of(context).loginHostValidationMessage);
        return;
      }
      await _openFnConnectWebView(url: probeUrl, isProbe: true);
      return;
    }

    if (host.trim().isEmpty) {
      _showToast(AppLocalizations.of(context).loginHostRequiredMessage);
      return;
    }
    if (username.trim().isEmpty) {
      _showToast(AppLocalizations.of(context).loginUsernameRequiredMessage);
      return;
    }
    if (password.isEmpty) {
      _showToast(AppLocalizations.of(context).loginPasswordRequiredMessage);
      return;
    }

    try {
      _displayHost = host.trim();
      _displayPort = port;
      AppTalker.info('Login', 'direct login start');
      final loggedIn = await _attemptDirectLogin(
        host: host,
        port: port,
        username: username,
        password: password,
        displayHost: _displayHost,
        displayPort: _displayPort,
      );
      if (!loggedIn) return;
      AppTalker.info('Login', 'direct login success, navigate');
      if (mounted) context.go('/home');
    } catch (e) {
      AppTalker.warning('Login', 'direct login error: $e');
      _handleLoginError(e);
    }
  }

  /// Runs a direct login. When the server turns out to be access-code
  /// protected, prompts for the code on the login screen and retries.
  /// Returns true when logged in, false when the user dismissed the prompt.
  Future<bool> _attemptDirectLogin({
    required String host,
    required int port,
    required String username,
    required String password,
    required String displayHost,
    required int displayPort,
  }) async {
    final notifier = ref.read(loginViewModelProvider.notifier);
    final l10n = AppLocalizations.of(context);
    String? accessCode;
    while (true) {
      try {
        await notifier.login(
          host: host,
          port: port,
          username: username,
          password: password,
          isHttps: _isHttps,
          rememberPassword: _rememberPassword,
          isNasLogin: false,
          fnIdEmptyMessage: l10n.loginFnIdEmpty,
          displayHost: displayHost,
          displayPort: displayPort,
          accessCode: accessCode,
        );
        return true;
      } on AccessCodeRequiredException {
        if (!mounted) return false;
        final code = await _promptAccessCode();
        if (code == null) return false;
        accessCode = code;
      } on AccessCodeVerificationException catch (e) {
        if (!mounted) return false;
        _showToast(e.isRejected
            ? l10n.loginAccessCodeInvalid
            : l10n.loginFailedCheckNetwork);
        final code = await _promptAccessCode();
        if (code == null) return false;
        accessCode = code;
      }
    }
  }

  /// Prompts for the NAS access code, returning null when the user cancels.
  Future<String?> _promptAccessCode() async {
    final l10n = AppLocalizations.of(context);
    _accessCodeDialogController.clear();
    _accessCodeDialogVisible = false;
    try {
      final action = await showAppDialog<String>(
        context: context,
        title: l10n.loginAccessCodeTitle,
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextBox(
                key: const ValueKey('login-access-code-input'),
                controller: _accessCodeDialogController,
                focusNode: _accessCodeFocusNode,
                obscureText: !_accessCodeDialogVisible,
                // Access codes are plain ASCII; reject CJK/IME input so a
                // Chinese input method can never fill this field.
                inputFormatters: const [_AsciiOnlyTextInputFormatter()],
                onSubmitted: (_) =>
                    Navigator.of(context, rootNavigator: true).pop('confirm'),
                suffix: AppIconButton(
                  icon: Icon(
                    _accessCodeDialogVisible
                        ? FluentIcons.hide3
                        : FluentIcons.view,
                  ),
                  onPressed: () => setDialogState(() {
                    _accessCodeDialogVisible = !_accessCodeDialogVisible;
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.loginAccessCodeHint,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        secondaryButtonText: l10n.commonCancel,
        primaryButtonText: l10n.commonConfirm,
        primaryResult: 'confirm',
        secondaryResult: 'cancel',
        autoDismiss: true,
      );
      if (action != 'confirm') return null;
      final code = _accessCodeDialogController.text.trim();
      return code.isEmpty ? null : code;
    } finally {
      // The dialog can close while its field is still focused, so re-derive
      // the input mode from the fields that actually hold focus.
      _syncImeEnglishOnly();
    }
  }

  Future<void> _openFnConnectWebView({
    required String url,
    required bool isProbe,
    String? autoLoginUsername,
    String? autoLoginPassword,
    bool allowAutoLogin = false,
  }) async {
    final normalizedUrl = _normalizeFnConnectUrl(url, true);
    _baseUrl = _originFromUrl(normalizedUrl);
    _allowAutoLogin = allowAutoLogin;
    _autoLoginUsername = autoLoginUsername?.trim() ?? '';
    _autoLoginPassword = autoLoginPassword ?? '';
    _capturedUsername = '';
    _capturedPassword = '';
    _capturedRememberPassword = false;
    try {
      // Create a shared Windows environment before accessing its cookie store.
      if (!kIsWeb && Platform.isWindows) {
        _fnConnectWebViewEnvironment ??= await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            userDataFolder: await _resolveWindowsWebViewUserDataFolder(),
          ),
        );
      }

      // Clear cookies through the same environment that will host the WebView.
      await _fnConnectCookieManager.deleteAllCookies();
    } catch (error) {
      AppTalker.warning(
        'LoginBridge',
        'prepare WebView environment failed: $error',
      );
      _showToast(AppLocalizations.of(context).loginWebViewInitFailed);
      return;
    }

    setState(() {
      _fnConnectUrl = normalizedUrl;
      _showFnConnectWebView = true;
      _isProbeMode = isProbe;
    });
    _prepareNetworkProcessor();
  }

  CookieManager get _fnConnectCookieManager {
    return CookieManager.instance(
      webViewEnvironment: _fnConnectWebViewEnvironment,
    );
  }

  /// WebView2 defaults to a user data folder next to the executable, which
  /// fails for installs under Program Files. Point it at a writable user
  /// directory instead.
  Future<String> _resolveWindowsWebViewUserDataFolder() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'webview2'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  void _prepareNetworkProcessor() {
    final prefs = ref.read(preferencesManagerProvider);
    final dioClient = ref.read(dioClientProvider);
    // Initialize network processor for NAS auth flow
    AppTalker.info('LoginBridge', 'prepare network processor');
    _networkMessageProcessor = _NetworkMessageProcessor(
      l10n: AppLocalizations.of(context),
      dioClient: dioClient,
      preferencesManager: prefs,
      onError: _showToast,
      setCookie: _setWebViewCookie,
      loadUrl: _loadWebViewUrl,
      onLoginSuccess: _onNasLoginSuccess,
      onBaseUrlChange: (value) => _baseUrl = value,
      encryptPassword:
          ref.read(loginHistoryPasswordServiceProvider).encryptForStorage,
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
    FocusNode? focusNode,
    bool obscureText = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return GlassTextField(
      controller: controller,
      placeholder: placeholder,
      focusNode: focusNode,
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
      rememberPasswordLabel:
          jsonEncode(AppLocalizations.of(context).loginRememberPassword),
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
      _completeProbe(baseUrl);
    }
  }

  /// Finishes probe mode once the real base URL is known: hide the webview and
  /// continue with the direct login using the form's credentials.
  void _completeProbe(String baseUrl) {
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
      return;
    }
    if (method == 'CaptureAccessCode') {
      unawaited(_handleAccessCodeCaptured(params));
      return;
    }
    if (method == 'ReportGateState') {
      try {
        final data = jsonDecode(params);
        if (data is Map) {
          _networkMessageProcessor?.reportWebViewGateState(
            gated: data['gated'] == true,
            cleared: data['cleared'] == true,
          );
        }
      } catch (_) {}
    }
  }

  /// Verifies the fnOS access code captured from the webview and stores the
  /// gateway session so native NAS API requests are authorized (the gateway
  /// otherwise answers API paths with the HTML page, stalling the login).
  Future<void> _handleAccessCodeCaptured(String params) async {
    String code = '';
    try {
      final data = jsonDecode(params);
      if (data is Map) {
        code = (data['code'] ?? '').toString().trim();
      }
    } catch (_) {}
    if (code.isEmpty || _baseUrl.isEmpty) return;
    AppTalker.info(
      'LoginBridge',
      'access code captured for "$_baseUrl" length=${code.length}',
    );
    try {
      final result = await AccessCodeSession.establish(
        dio: ref.read(dioClientProvider).dio,
        baseUrl: _baseUrl,
        accessCode: code,
      );
      AppTalker.info(
        'LoginBridge',
        'access code session established origin="${result.baseUrl}"',
      );
      if (_isProbeMode) {
        // Probe mode only needs the real base URL. The access code was entered
        // in the webview and captured into the gateway session, so finish the
        // probe and log in with the form's credentials.
        _completeProbe(result.baseUrl);
        return;
      }
      // The native sys/config fallback may already have run (and been rejected)
      // before the grant was ready; retry it now so the flow can continue.
      await _networkMessageProcessor?.retrySysConfig(result.baseUrl);
    } on AccessCodeVerificationException catch (e) {
      AppTalker.warning('LoginBridge', 'access code verify failed: $e');
      if (mounted && e.isRejected) {
        _showToast(AppLocalizations.of(context).loginAccessCodeInvalid);
      }
    } catch (e) {
      AppTalker.warning('LoginBridge', 'access code session error: $e');
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
    await _fnConnectCookieManager.setCookie(
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
    // Fold any access-code gateway session into the persisted cookie so media
    // API requests keep working after the app restarts.
    final persistedCookie = mergeCookies([
      getAccessCookieHeader(result.baseUrl),
      result.cookie,
    ]);
    await prefs.saveCookie(persistedCookie);
    await prefs.saveBaseUrl(result.baseUrl);
    await prefs.saveLoginHistory(result.history);
    ref.invalidate(loginHistoryNotifierProvider);

    // Clear cached user info so the next home entry validates
    // permissions for the newly authenticated NAS session.
    ref.read(userInfoProvider.notifier).clear();

    // Clear WebView cookies after login so the next NAS login starts fresh.
    // Account credentials are managed exclusively by the app (PreferencesManager),
    // not by WebView's persistent session storage.
    try {
      await _fnConnectCookieManager.deleteAllCookies();
    } catch (error) {
      AppTalker.warning(
        'LoginBridge',
        'clear WebView cookies after login failed: $error',
      );
    }

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
                settings: const LiquidGlassSettings(
                  thickness: 28.0,
                  blur: 8.0,
                  refractiveIndex: 1.8,
                ),
                // Keep grouped login controls on the cross-platform shader path.
                quality: GlassQuality.standard,
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
                            KeyedSubtree(
                              key: const ValueKey('login-history-button'),
                              child: _buildGlassField(
                                controller: _fnIdController,
                                placeholder: AppLocalizations.of(context)
                                    .loginHostOrFnIdPlaceholder,
                                onChanged: (_) => _autoLoginFromHistory = false,
                                suffixIcon: const Icon(
                                  material.Icons.history,
                                  color: _hintColor,
                                  size: 20,
                                ),
                                onSuffixTap: _toggleHistorySidebar,
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildGlassField(
                                    controller: _hostController,
                                    placeholder: AppLocalizations.of(context)
                                        .loginHostPlaceholder,
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
                                    placeholder: AppLocalizations.of(context)
                                        .loginPortPlaceholder,
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
                              placeholder: AppLocalizations.of(context)
                                  .loginUsernameLabel,
                              onChanged: (_) => _autoLoginFromHistory = false,
                            ),
                            const SizedBox(height: 16),
                            _buildGlassField(
                              controller: _passwordController,
                              placeholder: AppLocalizations.of(context)
                                  .loginPasswordLabel,
                              focusNode: _passwordFocusNode,
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
                                Expanded(
                                  child: Text(
                                      AppLocalizations.of(context)
                                          .loginRememberPassword,
                                      style: const TextStyle(color: _textColor)),
                                ),
                                _withClickCursor(
                                  material.TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    style: material.TextButton.styleFrom(
                                      enabledMouseCursor:
                                          SystemMouseCursors.click,
                                    ),
                                    child: Text(AppLocalizations.of(context)
                                        .forgotPasswordTitle),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    AppLocalizations.of(context)
                                        .loginUseNasLogin,
                                    style: const TextStyle(color: _hintColor)),
                              ),
                              _withClickCursor(
                                GlassSwitch(
                                  value: _isNasLogin,
                                  onChanged: (v) => setState(() {
                                    _isNasLogin = v;
                                    _autoLoginFromHistory = false;
                                  }),
                                  activeColor: _primaryBlue,
                                  useOwnLayer: true,
                                  quality: GlassQuality.standard,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    AppLocalizations.of(context)
                                        .loginHttpsSecureAccess,
                                    style: const TextStyle(color: _hintColor)),
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
                                  : Text(
                                      _isNasLogin
                                          ? AppLocalizations.of(context)
                                              .loginNext
                                          : AppLocalizations.of(context)
                                              .loginSignIn,
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
                        final hasRememberedPassword = await _populateFields(
                          item,
                          allowAutoLogin: false,
                        );
                        if (!mounted) return;
                        final allowNasAutoLogin =
                            item.isNasLogin && hasRememberedPassword;
                        setState(() {
                          _autoLoginFromHistory = allowNasAutoLogin;
                        });
                        _hideHistorySidebar();
                        if (item.isNasLogin || hasRememberedPassword) {
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
                            AppButton(
                              child: Text(
                                  AppLocalizations.of(context).commonCancel),
                              onPressed: () {
                                setState(() {
                                  _showFnConnectWebView = false;
                                });
                                _disposeWebView();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(AppLocalizations.of(context).loginVerifyingServer,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: InAppWebView(
                        webViewEnvironment: _fnConnectWebViewEnvironment,
                        initialUrlRequest:
                            URLRequest(url: _tryParseWebUri(_fnConnectUrl)),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          incognito: true,
                          cacheEnabled: false,
                        ),
                        onWebViewCreated: (controller) {
                          _inAppWebViewController = controller;
                          controller.addJavaScriptHandler(
                            handlerName: 'CaptureLoginInfo',
                            callback: (arguments) {
                              if (arguments.isNotEmpty) {
                                _handleJsBridgeMessage(
                                  'CaptureLoginInfo',
                                  arguments.first.toString(),
                                );
                              }
                              return null;
                            },
                          );
                          controller.addJavaScriptHandler(
                            handlerName: 'LogNetwork',
                            callback: (arguments) {
                              if (arguments.isNotEmpty) {
                                unawaited(
                                  _handleNetworkLog(arguments.first.toString()),
                                );
                              }
                              return null;
                            },
                          );
                          controller.addJavaScriptHandler(
                            handlerName: 'CaptureAccessCode',
                            callback: (arguments) {
                              if (arguments.isNotEmpty) {
                                unawaited(
                                  _handleAccessCodeCaptured(
                                    arguments.first.toString(),
                                  ),
                                );
                              }
                              return null;
                            },
                          );
                          controller.addJavaScriptHandler(
                            handlerName: 'ReportGateState',
                            callback: (arguments) {
                              if (arguments.isNotEmpty) {
                                _handleJsBridgeMessage(
                                  'ReportGateState',
                                  arguments.first.toString(),
                                );
                              }
                              return null;
                            },
                          );
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
    // A bare token is an FN ID and maps to the 5ddd.com portal; the FN Connect
    // family always uses HTTPS.
    final isFnConnect = !host.contains('.') || isFnConnectHost(host);
    final protocolPrefix =
        isFnConnect ? 'https://' : (https ? 'https://' : 'http://');
    return '$protocolPrefix$normalizedHost$path';
  }

  bool _needsProbe(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) return false;
    // A bare token is an FN ID; an FN Connect domain also needs the webview.
    return !h.contains('.') || isFnConnectHost(h);
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
      // The FN ID / FN domain probe already ran in the webview: the access
      // code (if any) was entered there and captured into the gateway session,
      // so finish with a plain direct login using the form's credentials.
      await ref.read(loginViewModelProvider.notifier).login(
            host: host,
            port: port,
            username: username,
            password: password,
            isHttps: _isHttps,
            rememberPassword: _rememberPassword,
            isNasLogin: false,
            fnIdEmptyMessage: AppLocalizations.of(context).loginFnIdEmpty,
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
      _handleLoginError(e);
    } finally {
      _isFinalizing = false;
    }
  }

  void _handleLoginError(Object error) {
    if (error is LoginException) {
      if (error.code == -15) {
        _showToast(AppLocalizations.of(context).loginInvalidCredentials);
        return;
      }
      _showToast(error.message);
      return;
    }
    _showToast(_humanizeLoginError(error));
  }

  /// Translates low-level network errors into plain text for users.
  /// Keep the original class names out of the toast; release obfuscation makes
  /// them unreadable anyway (e.g. `Instance of 'wNa'`).
  String _humanizeLoginError(Object error) {
    final l10n = AppLocalizations.of(context);
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return l10n.loginServerHttpError('$statusCode');
      }
      // A TLS failure normally arrives as `DioExceptionType.unknown` wrapping a
      // HandshakeException, not as `badCertificate`, so inspect the cause chain
      // before falling through to the generic messages.
      if (isCertificateException(error.error ?? error)) {
        return l10n.loginSslCertificateFailed;
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return l10n.loginConnectionTimeout;
        case DioExceptionType.connectionError:
          return l10n.loginConnectionFailed;
        case DioExceptionType.badCertificate:
          return l10n.loginSslCertificateFailed;
        case DioExceptionType.cancel:
          return l10n.loginRequestCancelled;
        case DioExceptionType.unknown:
        case DioExceptionType.badResponse:
          return l10n.loginFailedCheckServer;
      }
    }
    return l10n.loginFailedCheckNetwork;
  }

  void _showToast(String message) {
    ref.read(toastManagerProvider.notifier).showToast(
          message,
          type: ToastType.failed,
          style: ToastStyle.liquidGlass,
          duration: const Duration(seconds: 3),
        );
  }

  void _showForgotPasswordDialog() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showAppDialog<void>(
      context: context,
      title: l10n.forgotPasswordTitle,
      content: Text(l10n.forgotPasswordBody),
      primaryButtonText: l10n.commonConfirm,
      onPrimaryPressed: () {},
      autoDismiss: true,
    );
  }
}

/// Keeps a text field to printable ASCII, so CJK/IME input is simply dropped
/// instead of being inserted.
class _AsciiOnlyTextInputFormatter extends TextInputFormatter {
  const _AsciiOnlyTextInputFormatter();

  static final RegExp _printableAscii = RegExp(r'^[\x20-\x7E]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _printableAscii.hasMatch(newValue.text) ? newValue : oldValue;
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
    required this.l10n,
    required this.dioClient,
    required this.preferencesManager,
    required this.onError,
    required this.setCookie,
    required this.loadUrl,
    required this.onLoginSuccess,
    required this.onBaseUrlChange,
    required this.encryptPassword,
    required this.fnId,
    required this.autoLoginUsername,
  });

  final AppLocalizations l10n;
  final DioClient dioClient;
  final PreferencesManager preferencesManager;
  final void Function(String message) onError;
  final Future<void> Function(String baseUrl, String name, String value)
      setCookie;
  final Future<void> Function(String url) loadUrl;
  final Future<void> Function(_NasLoginResult result) onLoginSuccess;
  final void Function(String baseUrl) onBaseUrlChange;
  final Future<String?> Function(String? plainPassword) encryptPassword;
  final String fnId;
  final String autoLoginUsername;

  bool _isAuthRequested = false;
  bool _isSysConfigInFlight = false;
  bool _isSysConfigLoaded = false;
  String _lastSysCookie = '';

  /// The WebView page is showing the fnOS access-code gate.
  bool _isWebViewAccessCodeGated = false;

  /// The WebView page cleared its own access-code gate.
  bool _isWebViewGateCleared = false;

  /// Signin URL held back until the WebView page clears its gateway gate.
  String? _pendingSigninUrl;

  /// Records the WebView page's access-code gate state, reported by the
  /// in-page script. Navigating to `/signin` while the page is still gated
  /// would reload the gate with an empty field. The page clears the gate by
  /// running its own `/access_code_verify`; that is reported as `cleared`.
  void reportWebViewGateState({required bool gated, required bool cleared}) {
    if (gated) {
      _isWebViewAccessCodeGated = true;
    }
    if (cleared) {
      _isWebViewAccessCodeGated = false;
      _isWebViewGateCleared = true;
    }
    final pending = _pendingSigninUrl;
    if (pending == null || !_isWebViewGateCleared) return;
    _pendingSigninUrl = null;
    unawaited(loadUrl(pending));
  }

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
    _lastSysCookie = normalizedCookie;
    await _fetchSysConfig(baseUrl, normalizedCookie);
  }

  /// Re-runs the native sys/config lookup once the access-code gateway session
  /// is available (the first attempt may have run before the grant existed).
  Future<void> retrySysConfig(String baseUrl) async {
    if (_isSysConfigLoaded) return;
    _isSysConfigInFlight = false;
    await _fetchSysConfig(baseUrl, _lastSysCookie);
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
    _lastSysCookie = cookie;
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
    // The fnOS page runs its own access-code gate in the WebView, and the
    // WebView uses its own (incognito) cookie jar, so the native grant does
    // not authorize the page. Navigating to /signin while the page is still
    // gated reloads it back onto the access-code prompt with an empty field,
    // forcing the user to re-enter the code. Wait for the page to clear its
    // own gate (its /access_code_verify succeeded) before navigating.
    if (_isWebViewAccessCodeGated && !_isWebViewGateCleared) {
      _pendingSigninUrl = targetUrl;
      return;
    }
    _pendingSigninUrl = null;
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
        onError(l10n.loginFailedTokenEmpty);
        return;
      }
      final relayCookie =
          _normalizeRelayCookie('Trim-MC-token=$token', resolvedBaseUrl);
      final username = capturedUsername.trim().isNotEmpty
          ? capturedUsername.trim()
          : autoLoginUsername.trim();
      final shouldRemember =
          capturedRememberPassword && capturedPassword.isNotEmpty;
      final storedPassword =
          shouldRemember ? await encryptPassword(capturedPassword) : null;
      final historyItem = LoginHistory(
        host: '',
        port: 0,
        username: username,
        password: storedPassword,
        passwordEncrypted: storedPassword != null,
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
      onError(l10n.loginFailedWithError('$e'));
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
        final msg = data['msg']?.toString() ??
            l10n.loginAuthFailed;
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
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final headers = payload['headers'];
    if (headers is Map) {
      final lowered = headers.map((key, value) =>
          MapEntry(key.toString().toLowerCase(), value.toString()));
      final cookie = lowered['set-cookie'] ?? lowered['cookie'];
      if (cookie != null && cookie.isNotEmpty) {
        return cookie;
      }
    }
    if (headers is String) {
      final lines = headers.split('\n');
      for (final line in lines) {
        final parts = line.split(':');
        if (parts.length < 2) continue;
        final key = parts.first.trim().toLowerCase();
        final value = parts.sublist(1).join(':').trim();
        if (key == 'set-cookie' || key == 'cookie') {
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    }
    return null;
  }

  String _normalizeRelayCookie(String cookie, String baseUrl) {
    final host = Uri.tryParse(baseUrl)?.host ?? '';
    if (!isFnConnectHost(host)) {
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
