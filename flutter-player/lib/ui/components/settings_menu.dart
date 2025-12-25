import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'custom_ui.dart';

// --- Quality Flyout ---
class QualityFlyout extends StatefulWidget {
  final Player player;
  final VoidCallback onClose;

  const QualityFlyout({super.key, required this.player, required this.onClose});

  @override
  State<QualityFlyout> createState() => _QualityFlyoutState();
}

class _QualityFlyoutState extends State<QualityFlyout> {
  bool _isCustomPage = false;
  String? _selectedResolution;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 400,
      padding: const EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isCustomPage ? _buildCustomPage() : _buildSimplePage(),
      ),
    );
  }

  Widget _buildSimplePage() {
    final tracks = widget.player.state.tracks.video;
    // Aggregate by resolution (simplified logic)
    final resolutions = <String>{};
    for (var t in tracks) {
      if (t.w != null && t.h != null) {
        resolutions.add("${t.h}p");
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("视频质量", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => setState(() => _isCustomPage = true),
              child: const Text("自定义 >", style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          ],
        ),
        const Divider(color: Colors.white24, height: 24),
        Expanded(
          child: ListView(
            children: [
              _buildSimpleOption("原画质", "4k 11Mbps", true), // Mock data logic needed
              ...resolutions.map((r) => _buildSimpleOption(r, "", false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleOption(String title, String subtitle, bool isSelected) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(color: isSelected ? Colors.blue : Colors.white)),
      trailing: Text(subtitle, style: TextStyle(color: isSelected ? Colors.blue : Colors.white70, fontSize: 12)),
      onTap: () {
        // Logic to select best track for resolution
        widget.onClose();
      },
    );
  }

  Widget _buildCustomPage() {
    final tracks = widget.player.state.tracks.video;
    // Group by resolution
    final grouped = <String, List<VideoTrack>>{};
    for (var t in tracks) {
      final res = (t.w != null && t.h != null) ? "${t.h}p" : "Unknown";
      grouped.putIfAbsent(res, () => []).add(t);
    }
    
    final resolutions = grouped.keys.toList();
    _selectedResolution ??= resolutions.isNotEmpty ? resolutions.first : null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("自定义视频质量", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => setState(() => _isCustomPage = false),
              child: const Text("返回", style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          ],
        ),
        const Divider(color: Colors.white24, height: 24),
        Expanded(
          child: Row(
            children: [
              // Resolutions List
              Expanded(
                flex: 2,
                child: ListView(
                  children: resolutions.map((res) {
                    final isSel = res == _selectedResolution;
                    return ListTile(
                      title: Text(res, style: TextStyle(color: isSel ? Colors.blue : Colors.white)),
                      selected: isSel,
                      onTap: () => setState(() => _selectedResolution = res),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
                    );
                  }).toList(),
                ),
              ),
              const VerticalDivider(color: Colors.white24, width: 1),
              // Bitrates List
              Expanded(
                flex: 3,
                child: ListView(
                  children: (_selectedResolution != null ? grouped[_selectedResolution]! : []).map((track) {
                    final isCurrent = widget.player.state.track.video == track;
                    final bitrate = track.bitrate != null ? "${(track.bitrate! / 1000000).toStringAsFixed(1)}Mbps" : "Default";
                    return ListTile(
                      title: Text(bitrate, style: TextStyle(color: isCurrent ? Colors.blue : Colors.white)),
                      trailing: isCurrent ? const Icon(Icons.check, color: Colors.blue, size: 16) : null,
                      onTap: () {
                        widget.player.setVideoTrack(track);
                        widget.onClose();
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
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
        color: Colors.black.withOpacity(0.9),
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
  String? _subMenu; // 'audio', 'aspect_ratio', 'window_ratio'

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
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
      case 'audio':
        return _buildAudioSettings();
      case 'aspect_ratio':
        // Reuse similar structure for aspect ratio if needed, or keep simple
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
    final currentAudio = widget.player.state.track.audio;
    final audioTitle = "${currentAudio.language ?? '未知'} ${currentAudio.title ?? ''}";

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
        _buildMenuItem("音频", audioTitle, () => setState(() => _subMenu = 'audio')),
        _buildMenuItem("设置片头/片尾", "", widget.onIntroOutroTap),
      ],
    );
  }

  Widget _buildAudioSettings() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => setState(() => _subMenu = null),
              ),
              const Text("音频", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        SizedBox(
          height: 300,
          child: ListView(
            shrinkWrap: true,
            children: widget.player.state.tracks.audio.map((track) {
              final isSelected = widget.player.state.track.audio == track;
              return ListTile(
                title: Text(
                  "${track.language ?? '未知'} - ${track.id}", 
                  style: TextStyle(color: isSelected ? Colors.blue : Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title ?? "", 
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (track.channels != null)
                      Text(
                        "${track.channels} channels", 
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                  ],
                ),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blue, size: 16) : null,
                onTap: () {
                  widget.player.setAudioTrack(track);
                  widget.onClose();
                },
              );
            }).toList(),
          ),
        ),
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

class _SubtitleFlyoutState extends State<SubtitleFlyout> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _offset = 0.0;
  double _position = 0.1; // 0 (bottom) to 1 (top)
  double _size = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 450,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "字幕"),
              Tab(text: "调整"),
            ],
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.white70,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSubtitleList(),
                _buildAdjustPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleList() {
    final tracks = widget.player.state.tracks.subtitle;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text("搜索字幕"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () {
                    widget.onSearchTap();
                    widget.onClose();
                  },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.add, color: Colors.white),
                onSelected: (val) {
                  // TODO: Implement file picker logic
                  if (val == 'local') {
                    // Open file picker
                  } else if (val == 'nas') {
                    // Open NAS picker
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'local', child: Text("添加电脑字幕文件")),
                  const PopupMenuItem(value: 'nas', child: Text("添加 NAS 字幕文件")),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
               ListTile(
                  title: const Text("无", style: TextStyle(color: Colors.white)),
                  trailing: widget.player.state.track.subtitle == SubtitleTrack.no() ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    widget.player.setSubtitleTrack(SubtitleTrack.no());
                    widget.onClose();
                  },
                ),
              ...tracks.map((track) {
                final isSelected = widget.player.state.track.subtitle == track;
                return ListTile(
                  title: Text(track.title ?? track.language ?? "Track ${track.id}", style: TextStyle(color: isSelected ? Colors.blue : Colors.white)),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.blue, size: 16) : null,
                  onTap: () {
                    widget.player.setSubtitleTrack(track);
                    widget.onClose();
                  },
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdjustPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSlider("偏移", _offset, -5.0, 5.0, (val) {
             setState(() => _offset = val);
             // TODO: Apply subtitle offset
          }, suffix: "${_offset.toStringAsFixed(1)}s", hasReset: true, onReset: () => setState(() => _offset = 0.0)),
          
          const SizedBox(height: 16),
          _buildSlider("位置", _position, 0.0, 1.0, (val) {
             setState(() => _position = val);
             // TODO: Apply subtitle position (unsupported in pure media_kit for now, maybe custom renderer)
          }, minLabel: "底", maxLabel: "顶"),

          const SizedBox(height: 16),
          _buildSlider("字号", _size, 0.5, 2.0, (val) {
             setState(() => _size = val);
             // TODO: Apply subtitle scale
          }, minLabel: "小", maxLabel: "大"),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged, {String? suffix, String? minLabel, String? maxLabel, bool hasReset = false, VoidCallback? onReset}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white)),
            if (hasReset)
              GestureDetector(
                onTap: onReset,
                child: const Text("重置", style: TextStyle(color: Colors.blue, fontSize: 12)),
              ),
          ],
        ),
        Row(
          children: [
            if (minLabel != null) Text(minLabel, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                  activeColor: Colors.blue,
                  inactiveColor: Colors.white24,
                ),
              ),
            ),
            if (maxLabel != null) Text(maxLabel, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            if (suffix != null) 
              Container(
                width: 40, 
                alignment: Alignment.centerRight,
                child: Text(suffix, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
          ],
        ),
      ],
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
        color: Colors.black.withOpacity(0.9),
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

class SpeedFlyout extends StatelessWidget {
  final double currentSpeed;
  final Function(double) onSpeedChanged;
  final VoidCallback onClose;

  const SpeedFlyout({super.key, required this.currentSpeed, required this.onSpeedChanged, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final speeds = [2.0, 1.75, 1.5, 1.25, 1.0, 0.75, 0.5];
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: speeds.map((speed) {
          final isSelected = currentSpeed == speed;
          return ListTile(
            dense: true,
            title: Text("${speed}x", style: TextStyle(color: isSelected ? Colors.blue : Colors.white)),
            trailing: isSelected ? const Icon(Icons.check, color: Colors.blue, size: 16) : null,
            onTap: () {
              onSpeedChanged(speed);
              onClose();
            },
          );
        }).toList(),
      ),
    );
  }
}

// TODO: Implement EpisodeFlyout and NextPreviewFlyout if data is available
// For now, these are placeholders or can be implemented when data models are ready

