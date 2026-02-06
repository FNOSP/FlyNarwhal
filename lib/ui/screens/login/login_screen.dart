import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/history_sidebar.dart';
import 'login_view_model.dart';

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

    try {
      await ref.read(loginViewModelProvider.notifier).login(
            host: host,
            port: port,
            username: username,
            password: password,
            isHttps: _isHttps,
            rememberPassword: _rememberPassword,
            isNasLogin: _isNasLogin,
            fnId: fnId,
          );
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
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
        ],
      ),
    );
  }
}
