import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/history_sidebar.dart';
import 'login_view_model.dart';
import '../../../providers/providers.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io' show Platform, Directory;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static bool _winEnvInitialized = false;
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
  String _fnConnectUrl = '';
  String _displayHost = '';
  int _displayPort = 0;
  WebviewController? _winWebviewController;
  bool _winWebviewReady = false;
  StreamSubscription<String>? _winUrlSub;
  StreamSubscription<LoadingState>? _winLoadingSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final history = ref.read(loginHistoryNotifierProvider);
      if (history.isNotEmpty) {
        final last = history.first;
        _populateFields(last);
      }
    });
  }

  @override
  void dispose() {
    _disposeWindowsWebView();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fnIdController.dispose();
    super.dispose();
  }

  void _populateFields(var item) {
    setState(() {
      final displayHost = item.displayHost.toString();
      final displayPort = item.displayPort ?? item.port;
      _hostController.text = displayHost.isEmpty ? item.host : displayHost;
      _portController.text = displayPort.toString();
      _usernameController.text = item.username;
      _passwordController.text = item.password ?? '';
      _isHttps = item.isHttps;
      _rememberPassword = item.rememberPassword;
      _isNasLogin = item.isNasLogin;
      _fnIdController.text = item.fnId;
      _displayHost = _hostController.text;
      _displayPort = displayPort;
    });
  }

  void _onLogin() async {
    final host = _hostController.text;
    final port = int.tryParse(_portController.text) ?? 5666;
    final username = _usernameController.text;
    final password = _passwordController.text;
    final fnId = _fnIdController.text;
    debugPrint('[Login] start: isNasLogin=$_isNasLogin host="$host" port=$port fnId="$fnId" isHttps=$_isHttps');

    if (_isNasLogin) {
      _displayHost = fnId.trim();
      _displayPort = 0;
      final url = _normalizeFnConnectUrl(fnId, true);
      debugPrint('[Login] nas login: normalizedUrl="$url"');
      if (url.isEmpty) {
        debugPrint('[Login] nas login: empty url, abort');
        _showErrorDialog('请输入 FN ID');
        return;
      }
      setState(() {
        _fnConnectUrl = url;
        _showFnConnectWebView = true;
      });
      if (Platform.isWindows) {
        debugPrint('[Login] nas login: init windows webview');
        _initWindowsWebView();
      }
      return;
    }

    final needsProbe = _needsProbe(host);
    debugPrint('[Login] needsProbe=$needsProbe');
    if (needsProbe) {
      _displayHost = host.trim();
      _displayPort = port;
      final probeUrl = _normalizeFnConnectUrl(host, true);
      debugPrint('[Login] probe: normalizedUrl="$probeUrl"');
      if (probeUrl.isEmpty) {
        debugPrint('[Login] probe: empty url, abort');
        _showErrorDialog('请填写正确的 IP、域名或 FN ID');
        return;
      }
      setState(() {
        _fnConnectUrl = probeUrl;
        _showFnConnectWebView = true;
      });
      if (Platform.isWindows) {
        debugPrint('[Login] probe: init windows webview');
        _initWindowsWebView();
      }
      return;
    }

    try {
      _displayHost = host.trim();
      _displayPort = port;
      debugPrint('[Login] direct login start');
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
      debugPrint('[Login] direct login success, navigate');
      if (mounted) context.go('/home');
    } catch (e) {
      debugPrint('[Login] direct login error: $e');
      _showErrorDialog(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(loginHistoryNotifierProvider);
    final loginState = ref.watch(loginViewModelProvider);
    
    return ScaffoldPage(
      content: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_background.webp',
              fit: BoxFit.cover,
            ),
          ),
          
          // Login Form
          Center(
            child: Acrylic(
              tint: Colors.black.withValues(alpha: 0.6),
              blurAmount: 20,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    SvgPicture.asset(
                      'assets/images/fnarwhal_login.svg',
                      width: 174,
                    ),
                    const SizedBox(height: 8),
                    const Text('Fly Narwhal', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 32),
                    
                    if (_isNasLogin)
                      InfoLabel(
                        label: '请输入 IP:Port、域名或 FN ID',
                        child: TextFormBox(
                          controller: _fnIdController,
                          placeholder: '请输入 IP:Port、域名或 FN ID',
                          suffix: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              icon: const Icon(FluentIcons.history),
                              onPressed: () => setState(() => _showHistorySidebar = true),
                            ),
                          ),
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 2,
                            child: InfoLabel(
                              label: '请输入 IP、域名或 FN ID',
                              child: TextFormBox(
                                controller: _hostController,
                                placeholder: 'IP、域名或 FN ID',
                                suffix: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: IconButton(
                                    icon: const Icon(FluentIcons.history),
                                    onPressed: () => setState(() => _showHistorySidebar = true),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Text(':', style: TextStyle(fontSize: 20, color: Colors.grey)),
                          ),
                          Expanded(
                            flex: 1,
                            child: TextFormBox(
                              controller: _portController,
                              placeholder: '端口',
                            ),
                          ),
                        ],
                      ),
                      
                    const SizedBox(height: 16),
                    InfoLabel(
                      label: '用户名或邮箱',
                      child: TextFormBox(
                        controller: _usernameController,
                      ),
                    ),
                    const SizedBox(height: 16),
                    InfoLabel(
                      label: '密码',
                      child: TextFormBox(
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        suffix: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            icon: Icon(_passwordVisible ? FluentIcons.red_eye : FluentIcons.hide),
                            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Checkbox(
                            checked: _rememberPassword,
                            onChanged: (v) => setState(() => _rememberPassword = v ?? false),
                            content: const Text('记住密码'),
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: HyperlinkButton(
                            child: const Text('忘记密码'),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         const Text('使用 NAS 登录', style: TextStyle(color: Colors.grey)),
                         MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ToggleSwitch(
                            checked: _isNasLogin,
                            onChanged: (v) => setState(() => _isNasLogin = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         const Text('HTTPS 安全访问', style: TextStyle(color: Colors.grey)),
                         MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ToggleSwitch(
                            checked: _isHttps,
                            onChanged: (v) => setState(() => _isHttps = v),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: MouseRegion(
                        cursor: loginState.isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
                        child: FilledButton(
                          onPressed: loginState.isLoading ? null : _onLogin,
                          child: loginState.isLoading 
                              ? const ProgressRing() 
                              : Text(_isNasLogin ? '下一步' : '登录', style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // History Sidebar
          if (_showHistorySidebar)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: HistorySidebar(
                historyList: history,
                onDismiss: () => setState(() => _showHistorySidebar = false),
                onDelete: (item) {
                   ref.read(loginHistoryNotifierProvider.notifier).delete(item);
                },
                onSelect: (item) {
                  _populateFields(item);
                  setState(() => _showHistorySidebar = false);
                },
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
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Button(
                              child: const Text('关闭'),
                              onPressed: () {
                                setState(() {
                                  _showFnConnectWebView = false;
                                });
                                _disposeWindowsWebView();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('正在验证服务器...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Platform.isWindows
                          ? (_winWebviewController != null && _winWebviewReady
                              ? Webview(
                                  _winWebviewController!,
                                  permissionRequested: _onWinPermissionRequested,
                                )
                              : const Center(child: ProgressRing()))
                          : InAppWebView(
                              initialUrlRequest: URLRequest(url: Uri.parse(_fnConnectUrl)),
                              initialOptions: InAppWebViewGroupOptions(
                                crossPlatform: InAppWebViewOptions(
                                  javaScriptEnabled: true,
                                ),
                              ),
                              onLoadStop: (controller, url) async {
                                if (url == null) return;
                                _handleResolvedUrl(url.toString());
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

  Future<void> _initWindowsWebView() async {
    _disposeWindowsWebView();
    try {
      String? userDataPath;
      if (Platform.isWindows) {
        try {
          final supportDir = await getApplicationSupportDirectory();
          userDataPath = p.join(supportDir.path, 'fly_narwhal', 'webview_data');
          final dir = Directory(userDataPath);
          if (!dir.existsSync()) {
            await dir.create(recursive: true);
          }
        } catch (e) {
          debugPrint('Failed to initialize webview data folder: $e');
        }
      }
      if (!_winEnvInitialized) {
        try {
          await WebviewController.initializeEnvironment(
            userDataPath: userDataPath,
          );
          _winEnvInitialized = true;
          debugPrint('[Login][WinWebView] environment initialized userDataPath="$userDataPath"');
        } catch (_) {}
      }
      final controller = WebviewController();
      _winWebviewController = controller;
      await controller.initialize();
      debugPrint('[Login][WinWebView] controller initialized, loadUrl="$_fnConnectUrl"');
      _winUrlSub = controller.url.listen((url) {
        debugPrint('[Login][WinWebView] url event: $url');
        _handleResolvedUrl(url);
      });
      await controller.setBackgroundColor(const Color(0x00000000));
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
      _winLoadingSub = controller.loadingState.listen((state) async {
        debugPrint('[Login][WinWebView] loadingState=$state');
        if (state == LoadingState.navigationCompleted) {
          final value = await controller.executeScript('window.location.href');
          debugPrint('[Login][WinWebView] navigationCompleted href="$value"');
          if (value is String) {
            _handleResolvedUrl(value);
          }
        }
      });
      await controller.loadUrl(_fnConnectUrl);
      if (!mounted) return;
      setState(() {
        _winWebviewReady = true;
      });
      debugPrint('[Login][WinWebView] ready');
    } catch (_) {
      // Fallback: close overlay on error
      setState(() {
        _showFnConnectWebView = false;
        _winWebviewReady = false;
      });
      debugPrint('[Login][WinWebView] init failed');
    }
  }

  void _disposeWindowsWebView() {
    _winUrlSub?.cancel();
    _winUrlSub = null;
    _winLoadingSub?.cancel();
    _winLoadingSub = null;
    _winWebviewController = null;
    _winWebviewReady = false;
  }

  Future<WebviewPermissionDecision> _onWinPermissionRequested(
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    return WebviewPermissionDecision.allow;
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
    final protocolPrefix = normalizedHost.contains('5ddd.com') || normalizedHost.contains('fnos.net')
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

  String? _extractBaseUrl(String url) {
    final trimmed = url.trim();
    final normalized = trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length > 1
        ? trimmed.substring(1, trimmed.length - 1)
        : trimmed;
    final index = normalized.indexOf('/login');
    if (index == -1) return null;
    return normalized.substring(0, index);
  }

  void _handleResolvedUrl(String url) {
    debugPrint('[Login] handleResolvedUrl: $url');
    final baseUrl = _extractBaseUrl(url);
    if (baseUrl == null) {
      debugPrint('[Login] handleResolvedUrl ignored: baseUrl not found');
      return;
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) {
      debugPrint('[Login] handleResolvedUrl ignored: invalid baseUrl="$baseUrl"');
      return;
    }
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    setState(() {
      _showFnConnectWebView = false;
    });
    _disposeWindowsWebView();
    _hostController.text = uri.host;
    _portController.text = (uri.hasPort ? uri.port : 0).toString();
    _isHttps = scheme == 'https';
    debugPrint('[Login] handleResolvedUrl resolved: scheme=$scheme host="${uri.host}" port=${uri.hasPort ? uri.port : 0} baseUrl="$baseUrl"');
    _finalizeLogin();
  }
  Future<void> _finalizeLogin({String? displayHost, int? displayPort}) async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? 0;
    final username = _usernameController.text;
    final password = _passwordController.text;
    try {
      debugPrint('[Login] finalize login start: host="$host" port=$port isHttps=$_isHttps');
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
      debugPrint('[Login] finalize login success, navigate');
      final prefs = ref.read(preferencesManagerProvider);
      final token = prefs.getToken();
      final baseUrl = prefs.getBaseUrl();
      debugPrint('[Login] prefs after login: token=${token != null} tokenLength=${token?.length ?? 0} baseUrl=${baseUrl != null}');
      final refreshNotifier = ref.read(authRefreshProvider.notifier);
      refreshNotifier.state = refreshNotifier.state + 1;
      debugPrint('[Login] auth refresh from screen=${refreshNotifier.state}');
      if (mounted) context.go('/home');
    } catch (e) {
      debugPrint('[Login] finalize login error: $e');
      _showErrorDialog(e.toString());
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
          Button(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
