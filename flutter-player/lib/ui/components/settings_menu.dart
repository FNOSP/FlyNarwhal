import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';

// --- Quality Flyout ---
class QualityFlyout extends HookWidget {
  final Player player;
  final VoidCallback onClose;

  const QualityFlyout({super.key, required this.player, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 400,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("视频质量", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24, height: 24),
          const Expanded(
            child: Center(
              child: Text("当前播放引擎暂不支持切换画质", style: TextStyle(color: Colors.white70)),
            ),
          ),
          ListTile(
            title: const Text("返回", style: TextStyle(color: Colors.blue)),
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class IntroOutroDialog extends HookConsumerWidget {
  final Duration duration;
  final Duration currentPosition;
  final int initialIntroEndMs;
  final int initialOutroStartMs;
  final Function(int, int) onSave;
  final VoidCallback onReset;

  const IntroOutroDialog({
    super.key,
    required this.duration,
    required this.currentPosition,
    required this.initialIntroEndMs,
    required this.initialOutroStartMs,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final introEnd = initialIntroEndMs.toDouble();
    final outroStart = initialOutroStartMs > 0
        ? initialOutroStartMs.toDouble()
        : duration.inMilliseconds.toDouble();

    useEffect(() {
      ref.read(_introOutroProvider.notifier).setInitial(introEnd, outroStart);
      return null;
    }, [introEnd, outroStart]);

    final state = ref.watch(_introOutroProvider);
    final maxMs = duration.inMilliseconds.toDouble();

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(230), // 0.9 * 255 = 230
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('跳过片头/片尾', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: onReset,
                child: const Text('重置', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
          const Text('生效范围：《...》第 1 季', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const Divider(color: Colors.white24, height: 24),

          // Intro Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('片头时长', style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                    child: Text(_formatDuration(state.introEnd), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  final value = currentPosition.inMilliseconds.toDouble();
                  ref.read(_introOutroProvider.notifier).setIntroEnd(value);
                  onSave(value.toInt(), state.outroStart.toInt());
                },
                child: Text('将当前时间 ${_formatDuration(currentPosition.inMilliseconds.toDouble())} 设为片头',
                    style: const TextStyle(color: Colors.blue, fontSize: 12)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue,
              thumbColor: Colors.white,
              trackHeight: 2,
            ),
            child: Slider(
              value: state.introEnd.clamp(0.0, maxMs),
              min: 0.0,
              max: maxMs / 2, // Limit intro to first half
              onChanged: (val) {
                ref.read(_introOutroProvider.notifier).setIntroEnd(val);
              },
              onChangeEnd: (val) => onSave(val.toInt(), state.outroStart.toInt()),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('开始', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text('10 分钟', style: TextStyle(color: Colors.white38, fontSize: 10)), // Dynamic max
            ],
          ),

          const SizedBox(height: 16),

          // Outro Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('片尾时长', style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                    child: Text(_formatDuration(maxMs - state.outroStart), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  final value = currentPosition.inMilliseconds.toDouble();
                  ref.read(_introOutroProvider.notifier).setOutroStart(value);
                  onSave(state.introEnd.toInt(), value.toInt());
                },
                child: Text('将当前剩余时长 ${_formatDuration(maxMs - currentPosition.inMilliseconds.toDouble())} 设为片尾',
                    style: const TextStyle(color: Colors.blue, fontSize: 12)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue,
              thumbColor: Colors.white,
              trackHeight: 2,
            ),
            child: Slider(
              value: state.outroStart.clamp(0.0, maxMs),
              min: maxMs / 2, // Limit outro to second half
              max: maxMs,
              onChanged: (val) {
                ref.read(_introOutroProvider.notifier).setOutroStart(val);
              },
              onChangeEnd: (val) => onSave(state.introEnd.toInt(), val.toInt()),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10 分钟', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text('结束', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(double ms) {
    final duration = Duration(milliseconds: ms.toInt());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

class IntroOutroState {
  final double introEnd;
  final double outroStart;

  const IntroOutroState({
    this.introEnd = 0,
    this.outroStart = 0,
  });

  IntroOutroState copyWith({
    double? introEnd,
    double? outroStart,
  }) {
    return IntroOutroState(
      introEnd: introEnd ?? this.introEnd,
      outroStart: outroStart ?? this.outroStart,
    );
  }
}

class IntroOutroController extends StateNotifier<IntroOutroState> {
  IntroOutroController() : super(const IntroOutroState());

  void setInitial(double introEnd, double outroStart) {
    state = IntroOutroState(introEnd: introEnd, outroStart: outroStart);
  }

  void setIntroEnd(double value) {
    state = state.copyWith(introEnd: value);
  }

  void setOutroStart(double value) {
    state = state.copyWith(outroStart: value);
  }
}

final _introOutroProvider = StateNotifierProvider.autoDispose<IntroOutroController, IntroOutroState>(
  (ref) => IntroOutroController(),
);

class SettingsMenu extends ConsumerWidget {
  final Player player;
  final String currentAspectRatio;
  final String currentWindowRatio;
  final Function(String) onAspectRatioChanged;
  final Function(String) onWindowRatioChanged;
  final VoidCallback onIntroOutroTap;
  final VoidCallback onClose;

  const SettingsMenu({
    super.key,
    required this.player,
    required this.currentAspectRatio,
    required this.currentWindowRatio,
    required this.onAspectRatioChanged,
    required this.onWindowRatioChanged,
    required this.onIntroOutroTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuState = ref.watch(_settingsMenuProvider);
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildCurrentMenu(ref, menuState.subMenu),
      ),
    );
  }

  Widget _buildCurrentMenu(WidgetRef ref, String? subMenu) {
    switch (subMenu) {
      case 'aspect_ratio':
        return _buildSelectionMenu(
           ref: ref,
           title: '画面比例',
           options: ['默认', '4:3', '16:9', '21:9'],
           current: currentAspectRatio,
           onSelect: (val) {
             onAspectRatioChanged(val);
             ref.read(_settingsMenuProvider.notifier).closeSubMenu();
           },
           onBack: () => ref.read(_settingsMenuProvider.notifier).closeSubMenu(),
        );
      case 'window_ratio':
         return _buildSelectionMenu(
           ref: ref,
           title: '窗口比例',
           options: ['自动', '4:3', '16:9', '21:9'],
           current: currentWindowRatio,
           onSelect: (val) {
             onWindowRatioChanged(val);
             ref.read(_settingsMenuProvider.notifier).closeSubMenu();
           },
           onBack: () => ref.read(_settingsMenuProvider.notifier).closeSubMenu(),
         );
      default:
        return _buildMainMenu(ref);
    }
  }

  Widget _buildMainMenu(WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text("设置", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const Divider(color: Colors.white24, height: 1),
        _buildMenuItem("画面比例", currentAspectRatio, () => ref.read(_settingsMenuProvider.notifier).openSubMenu('aspect_ratio')),
        _buildMenuItem("窗口比例", currentWindowRatio, () => ref.read(_settingsMenuProvider.notifier).openSubMenu('window_ratio')),
        _buildMenuItem("设置片头/片尾", "", onIntroOutroTap),
        _buildMenuItem("音频", "暂不支持", () {}),
        _buildMenuItem("字幕", "暂不支持", () {}),
      ],
    );
  }

  Widget _buildMenuItem(String title, String value, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              value, 
              style: const TextStyle(color: Colors.white70, fontSize: 12), 
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }
  
  Widget _buildSelectionMenu({
     required WidgetRef ref,
     required String title,
     required List<String> options,
     required String current,
     required Function(String) onSelect,
     required VoidCallback onBack,
   }) {
     return Column(
       mainAxisSize: MainAxisSize.min,
       children: [
         Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: onBack,
              ),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
         const Divider(color: Colors.white24, height: 1),
         ...options.map((opt) {
           final isSelected = opt == current;
           return ListTile(
             title: Text(opt, style: TextStyle(color: isSelected ? Colors.blue : Colors.white)),
             trailing: isSelected ? const Icon(Icons.check, color: Colors.blue, size: 16) : null,
             onTap: () => onSelect(opt),
           );
         }),
       ],
     );
   }
}

class SettingsMenuState {
  final String? subMenu;

  const SettingsMenuState({this.subMenu});

  SettingsMenuState copyWith({String? subMenu}) {
    return SettingsMenuState(subMenu: subMenu);
  }
}

class SettingsMenuController extends StateNotifier<SettingsMenuState> {
  SettingsMenuController() : super(const SettingsMenuState());

  void openSubMenu(String value) {
    state = state.copyWith(subMenu: value);
  }

  void closeSubMenu() {
    state = state.copyWith(subMenu: null);
  }
}

final _settingsMenuProvider = StateNotifierProvider.autoDispose<SettingsMenuController, SettingsMenuState>(
  (ref) => SettingsMenuController(),
);

class SubtitleFlyout extends HookWidget {
  final Player player;
  final VoidCallback onClose;
  final VoidCallback onSearchTap;

  const SubtitleFlyout({
    super.key, 
    required this.player, 
    required this.onClose,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 400,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("字幕设置", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24, height: 24),
          const Expanded(
            child: Center(
              child: Text("当前播放引擎暂不支持切换字幕", style: TextStyle(color: Colors.white70)),
            ),
          ),
          ListTile(
            title: const Text("返回", style: TextStyle(color: Colors.blue)),
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class VolumeFlyout extends HookWidget {
  final double volume;
  final Function(double) onVolumeChanged;

  const VolumeFlyout({super.key, required this.volume, required this.onVolumeChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text("${volume.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: Colors.blue,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: volume,
                  min: 0,
                  max: 100,
                  onChanged: onVolumeChanged,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Icon(Icons.volume_up, color: Colors.white, size: 20),
        ],
      ),
    );
  }
}



// TODO: Implement EpisodeFlyout and NextPreviewFlyout if data is available
// For now, these are placeholders or can be implemented when data models are ready
