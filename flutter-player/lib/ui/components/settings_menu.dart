import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

// --- Quality Flyout ---
class QualityFlyout extends StatefulWidget {
  final Player player;
  final VoidCallback onClose;

  const QualityFlyout({super.key, required this.player, required this.onClose});

  @override
  State<QualityFlyout> createState() => _QualityFlyoutState();
}

class _QualityFlyoutState extends State<QualityFlyout> {
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
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }
}

class IntroOutroDialog extends StatefulWidget {
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
  State<IntroOutroDialog> createState() => _IntroOutroDialogState();
}

class _IntroOutroDialogState extends State<IntroOutroDialog> {
  late double _introEnd;
  late double _outroStart;

  @override
  void initState() {
    super.initState();
    _introEnd = widget.initialIntroEndMs.toDouble();
    _outroStart = widget.initialOutroStartMs > 0
        ? widget.initialOutroStartMs.toDouble()
        : widget.duration.inMilliseconds.toDouble();
  }

  String _formatDuration(double ms) {
    final duration = Duration(milliseconds: ms.toInt());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = widget.duration.inMilliseconds.toDouble();

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
                onPressed: widget.onReset,
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
                    child: Text(_formatDuration(_introEnd), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _introEnd = widget.currentPosition.inMilliseconds.toDouble();
                    widget.onSave(_introEnd.toInt(), _outroStart.toInt());
                  });
                },
                child: Text('将当前时间 ${_formatDuration(widget.currentPosition.inMilliseconds.toDouble())} 设为片头',
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
              value: _introEnd.clamp(0.0, maxMs),
              min: 0.0,
              max: maxMs / 2, // Limit intro to first half
              onChanged: (val) {
                setState(() => _introEnd = val);
              },
              onChangeEnd: (val) => widget.onSave(val.toInt(), _outroStart.toInt()),
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
                    child: Text(_formatDuration(maxMs - _outroStart), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                   setState(() {
                    _outroStart = widget.currentPosition.inMilliseconds.toDouble();
                    widget.onSave(_introEnd.toInt(), _outroStart.toInt());
                  });
                },
                child: Text('将当前剩余时长 ${_formatDuration(maxMs - widget.currentPosition.inMilliseconds.toDouble())} 设为片尾',
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
              value: _outroStart.clamp(0.0, maxMs),
              min: maxMs / 2, // Limit outro to second half
              max: maxMs,
              onChanged: (val) {
                setState(() => _outroStart = val);
              },
              onChangeEnd: (val) => widget.onSave(_introEnd.toInt(), val.toInt()),
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
}

class SettingsMenu extends StatefulWidget {
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
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  String? _subMenu; // 'aspect_ratio', 'window_ratio'

  @override
  Widget build(BuildContext context) {
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
        child: _buildCurrentMenu(),
      ),
    );
  }

  Widget _buildCurrentMenu() {
    switch (_subMenu) {
      case 'aspect_ratio':
        return _buildSelectionMenu(
           title: '画面比例',
           options: ['默认', '4:3', '16:9', '21:9'],
           current: widget.currentAspectRatio,
           onSelect: (val) {
             widget.onAspectRatioChanged(val);
             setState(() => _subMenu = null);
           },
           onBack: () => setState(() => _subMenu = null),
        );
      case 'window_ratio':
         return _buildSelectionMenu(
           title: '窗口比例',
           options: ['自动', '4:3', '16:9', '21:9'],
           current: widget.currentWindowRatio,
           onSelect: (val) {
             widget.onWindowRatioChanged(val);
             setState(() => _subMenu = null);
           },
           onBack: () => setState(() => _subMenu = null),
         );
      default:
        return _buildMainMenu();
    }
  }

  Widget _buildMainMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text("设置", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const Divider(color: Colors.white24, height: 1),
        _buildMenuItem("画面比例", widget.currentAspectRatio, () => setState(() => _subMenu = 'aspect_ratio')),
        _buildMenuItem("窗口比例", widget.currentWindowRatio, () => setState(() => _subMenu = 'window_ratio')),
        _buildMenuItem("设置片头/片尾", "", widget.onIntroOutroTap),
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

class SubtitleFlyout extends StatefulWidget {
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
  State<SubtitleFlyout> createState() => _SubtitleFlyoutState();
}

class _SubtitleFlyoutState extends State<SubtitleFlyout> {
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
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }
}

class VolumeFlyout extends StatefulWidget {
  final double volume;
  final Function(double) onVolumeChanged;

  const VolumeFlyout({super.key, required this.volume, required this.onVolumeChanged});

  @override
  State<VolumeFlyout> createState() => _VolumeFlyoutState();
}

class _VolumeFlyoutState extends State<VolumeFlyout> {
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
          Text("${widget.volume.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
                  value: widget.volume,
                  min: 0,
                  max: 100,
                  onChanged: widget.onVolumeChanged,
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
