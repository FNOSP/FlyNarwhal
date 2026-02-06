import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final GoRouterState state;

  const MainLayout({
    super.key,
    required this.child,
    required this.state,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int topIndex = 0;

  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _calculateSelectedIndex();
  }
  
  @override
  void initState() {
    super.initState();
    _calculateSelectedIndex();
  }

  void _calculateSelectedIndex() {
    final location = widget.state.uri.path;
    if (location.startsWith('/home')) {
      topIndex = 0;
    } else if (location.startsWith('/library')) {
      topIndex = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      pane: NavigationPane(
        header: const Padding(
          padding: EdgeInsets.only(left: 20.0),
          child: Text('Fly Narwhal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        selected: topIndex,
        onChanged: (index) {
          setState(() => topIndex = index);
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              // For now navigate to a dummy library
              context.go('/library/1');
              break;
            default:
              break;
          }
        },
        displayMode: PaneDisplayMode.compact,
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('首页'),
            body: const SizedBox.shrink(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.library),
            title: const Text('媒体库'),
            body: const SizedBox.shrink(),
          ),
        ],
        footerItems: [
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('设置'),
            body: const SizedBox.shrink(),
            onTap: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      paneBodyBuilder: (item, body) => widget.child,
    );
  }
}
