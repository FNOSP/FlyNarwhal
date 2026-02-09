import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/history_sidebar.dart';
import 'login_view_model.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io' show Platform;
import 'package:webview_windows/webview_windows.dart';
import 'dart:async';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
      _hostController.text = item.host;
      _portController.text = item.port.toString();
      _usernameController.text = item.username;
      _passwordController.text = item.password ?? '';
      _isHttps = item.isHttps;
      _rememberPassword = item.rememberPassword;
      _isNasLogin = item.isNasLogin;
      _fnIdController.text = item.fnId;
    });
  }

  void _onLogin() async {
    final host = _hostController.text;
    final port = int.tryParse(_portController.text) ?? 5666;
    final username = _usernameController.text;
    final password = _passwordController.text;
    final fnId = _fnIdController.text;

    if (_isNasLogin) {
      final url = _normalizeFnConnectUrl(fnId, true);
      if (url.isEmpty) {
        _showErrorDialog('请输入 FN ID');
        return;
      }
      setState(() {
        _fnConnectUrl = url;
        _showFnConnectWebView = true;
      });
      if (Platform.isWindows) {
        _initWindowsWebView();
      }
      return;
    }

    final needsProbe = _needsProbe(host);
    if (needsProbe) {
      final probeUrl = _normalizeFnConnectUrl(host, true);
      if (probeUrl.isEmpty) {
        _showErrorDialog('请填写正确的 IP、域名或 FN ID');
        return;
      }
      setState(() {
        _fnConnectUrl = probeUrl;
        _showFnConnectWebView = true;
      });
      if (Platform.isWindows) {
        _initWindowsWebView();
      }
      return;
    }

    try {
      await ref.read(loginViewModelProvider.notifier).login(
            host: host,
            port: port,
            username: username,
            password: password,
            isHttps: _isHttps,
            rememberPassword: _rememberPassword,
            isNasLogin: false,
            fnId: null,
          );
      if (mounted) context.go('/home');
    } catch (e) {
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
                          suffix: IconButton(
                            icon: const Icon(FluentIcons.history),
                            onPressed: () => setState(() => _showHistorySidebar = true),
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
                                suffix: IconButton(
                                  icon: const Icon(FluentIcons.history),
                                  onPressed: () => setState(() => _showHistorySidebar = true),
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
                        suffix: IconButton(
                          icon: Icon(_passwordVisible ? FluentIcons.red_eye : FluentIcons.hide),
                          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Checkbox(
                          checked: _rememberPassword,
                          onChanged: (v) => setState(() => _rememberPassword = v ?? false),
                          content: const Text('记住密码'),
                        ),
                        HyperlinkButton(
                          child: const Text('忘记密码'),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         const Text('使用 NAS 登录', style: TextStyle(color: Colors.grey)),
                         ToggleSwitch(
                          checked: _isNasLogin,
                          onChanged: (v) => setState(() => _isNasLogin = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         const Text('HTTPS 安全访问', style: TextStyle(color: Colors.grey)),
                         ToggleSwitch(
                          checked: _isHttps,
                          onChanged: (v) => setState(() => _isHttps = v),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: loginState.isLoading ? null : _onLogin,
                        child: loginState.isLoading 
                            ? const ProgressRing() 
                            : Text(_isNasLogin ? '下一步' : '登录', style: const TextStyle(fontSize: 16)),
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
                          Button(
                            child: const Text('关闭'),
                            onPressed: () {
                              setState(() {
                                _showFnConnectWebView = false;
                              });
                              _disposeWindowsWebView();
                            },
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
                                final uri = url;
                                final host = uri.host;
                                if (host.isEmpty) return;
                                final isRelay = host.contains('5ddd.com') || host.contains('fnos.net');
                                if (!isRelay) {
                                  final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
                                  setState(() {
                                    _showFnConnectWebView = false;
                                  });
                                  _hostController.text = host;
                                  _portController.text = (uri.hasPort ? uri.port : 0).toString();
                                  _isHttps = scheme == 'https';
                                  _finalizeLogin();
                                }
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
    final controller = WebviewController();
    _winWebviewController = controller;
    try {
      await controller.initialize();
      _winUrlSub = controller.url.listen((url) {
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        final host = uri.host;
        if (host.isEmpty) return;
        final isRelay = host.contains('5ddd.com') || host.contains('fnos.net');
        if (!isRelay) {
          final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
          setState(() {
            _showFnConnectWebView = false;
          });
          _hostController.text = host;
          _portController.text = (uri.hasPort ? uri.port : 0).toString();
          _isHttps = scheme == 'https';
          _finalizeLogin();
        }
      });
      await controller.setBackgroundColor(const Color(0x00000000));
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
      _winLoadingSub = controller.loadingState.listen((state) async {
        if (state == LoadingState.navigationCompleted) {
          final value = await controller.executeScript('window.location.href');
          if (value is String) {
            final uri = Uri.tryParse(value);
            if (uri != null) {
              _handleResolvedUri(uri);
            }
          }
        }
      });
      await controller.loadUrl(_fnConnectUrl);
      if (!mounted) return;
      setState(() {
        _winWebviewReady = true;
      });
    } catch (_) {
      // Fallback: close overlay on error
      setState(() {
        _showFnConnectWebView = false;
        _winWebviewReady = false;
      });
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
    if (raw.contains('.')) {
      if (hasScheme) return raw;
      return '${https ? 'https' : 'http'}://$raw';
    }
    return 'https://5ddd.com/$raw';
  }

  bool _needsProbe(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) return false;
    if (!h.contains('.')) return true;
    if (h.contains('5ddd.com') || h.contains('fnos.net')) return true;
    return false;
  }

  bool _isRelayHost(String host) {
    return host.contains('5ddd.com') || host.contains('fnos.net');
  }

  void _handleResolvedUri(Uri uri) {
    final host = uri.host;
    if (host.isEmpty || _isRelayHost(host)) return;
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    setState(() {
      _showFnConnectWebView = false;
    });
    _disposeWindowsWebView();
    _hostController.text = host;
    _portController.text = (uri.hasPort ? uri.port : 0).toString();
    _isHttps = scheme == 'https';
    _finalizeLogin();
  }
  Future<void> _finalizeLogin() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? 0;
    final username = _usernameController.text;
    final password = _passwordController.text;
    try {
      await ref.read(loginViewModelProvider.notifier).login(
            host: host,
            port: port,
            username: username,
            password: password,
            isHttps: _isHttps,
            rememberPassword: _rememberPassword,
            isNasLogin: false,
          );
      if (mounted) context.go('/home');
    } catch (e) {
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
