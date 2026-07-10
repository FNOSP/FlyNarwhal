import 'package:fluent_ui/fluent_ui.dart';

import '../../../../providers/danmaku_controller.dart';
import 'player_action_button.dart';

enum DanmakuSettingsPage {
  main,
  advanced,
}

class DanmakuSettingsFlyout extends StatefulWidget {
  final DanmakuSettings settings;
  final DanmakuLoadStatus loadStatus;
  final double popupBottomOffset;
  final ValueChanged<double> onAreaChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onFontSizeScaleChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onSyncPlaybackSpeedChanged;
  final ValueChanged<bool> onDebugEnabledChanged;
  final ValueChanged<bool>? onHoverStateChanged;

  const DanmakuSettingsFlyout({
    super.key,
    required this.settings,
    required this.loadStatus,
    required this.popupBottomOffset,
    required this.onAreaChanged,
    required this.onOpacityChanged,
    required this.onFontSizeScaleChanged,
    required this.onSpeedChanged,
    required this.onSyncPlaybackSpeedChanged,
    required this.onDebugEnabledChanged,
    this.onHoverStateChanged,
  });

  @override
  State<DanmakuSettingsFlyout> createState() =>
      _DanmakuSettingsFlyoutState();
}

class _DanmakuSettingsFlyoutState extends State<DanmakuSettingsFlyout> {
  final FlyoutController _flyoutController = FlyoutController();
  DanmakuSettingsPage _page = DanmakuSettingsPage.main;

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: _flyoutController,
      child: PlayerActionButton.svg(
        key: const ValueKey('player-danmaku-settings'),
        svgAssetPath: 'assets/images/danmu_setting.svg',
        onPressed: _toggleFlyout,
        tooltip: '弹幕设置',
        size: 30,
        iconSize: 20,
      ),
    );
  }

  void _toggleFlyout() {
    if (_flyoutController.isOpen) {
      _flyoutController.close();
      return;
    }

    _flyoutController.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      placementMode: FlyoutPlacementMode.topCenter,
      builder: (context) {
        return MouseRegion(
          onEnter: (_) => widget.onHoverStateChanged?.call(true),
          onExit: (_) => widget.onHoverStateChanged?.call(false),
          child: StatefulBuilder(
            builder: (context, setFlyoutState) {
              return Container(
                key: const ValueKey('player-danmaku-settings-flyout'),
                width: 340,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xF2181818),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x667F7F7F)),
                ),
                child: _page == DanmakuSettingsPage.main
                    ? _buildMainPage(setFlyoutState)
                    : _buildAdvancedPage(setFlyoutState),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMainPage(StateSetter setFlyoutState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader('弹幕设置'),
        if (_statusText != null) ...[
          const SizedBox(height: 4),
          Text(
            _statusText!,
            style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 13),
          ),
        ],
        const SizedBox(height: 18),
        const Text('显示区域', style: TextStyle(color: Color(0xE6FFFFFF))),
        const SizedBox(height: 8),
        Wrap(
          key: const ValueKey('player-danmaku-area-control'),
          spacing: 8,
          children: [0.1, 0.25, 0.5, 0.75, 1.0].map((area) {
            return Button(
              onPressed: () => widget.onAreaChanged(area),
              child: Text('${(area * 100).round()}%'),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildSlider(
          key: const ValueKey('player-danmaku-opacity-slider'),
          label: '不透明度 ${(widget.settings.opacity * 100).round()}%',
          value: widget.settings.opacity,
          minimum: 0,
          maximum: 1,
          onChanged: widget.onOpacityChanged,
        ),
        _buildSlider(
          key: const ValueKey('player-danmaku-font-size-slider'),
          label: '字号 ${(widget.settings.fontSizeScale * 100).round()}%',
          value: widget.settings.fontSizeScale,
          minimum: 0.5,
          maximum: 1.7,
          onChanged: widget.onFontSizeScaleChanged,
        ),
        _buildSlider(
          key: const ValueKey('player-danmaku-speed-slider'),
          label: '速度 ${_speedLabel(widget.settings.speed)}',
          value: widget.settings.speed,
          minimum: 0.5,
          maximum: 2.0,
          onChanged: widget.onSpeedChanged,
        ),
        const SizedBox(height: 4),
        Button(
          onPressed: () {
            setFlyoutState(() => _page = DanmakuSettingsPage.advanced);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('高级设置'), Icon(FluentIcons.chevron_right)],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedPage(StateSetter setFlyoutState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.chevron_left),
              onPressed: () {
                setFlyoutState(() => _page = DanmakuSettingsPage.main);
              },
            ),
            const SizedBox(width: 8),
            _buildHeader('高级设置'),
          ],
        ),
        const SizedBox(height: 18),
        ToggleSwitch(
          key: const ValueKey('player-danmaku-sync-speed-switch'),
          checked: widget.settings.syncPlaybackSpeed,
          onChanged: widget.onSyncPlaybackSpeedChanged,
          content: const Text('弹幕速度同步播放倍速'),
        ),
        const SizedBox(height: 16),
        ToggleSwitch(
          key: const ValueKey('player-danmaku-debug-switch'),
          checked: widget.settings.debugEnabled,
          onChanged: widget.onDebugEnabledChanged,
          content: const Text('显示弹幕调试信息'),
        ),
      ],
    );
  }

  Widget _buildHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSlider({
    required Key key,
    required String label,
    required double value,
    required double minimum,
    required double maximum,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xE6FFFFFF))),
          const SizedBox(height: 6),
          Slider(
            key: key,
            value: value,
            min: minimum,
            max: maximum,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String? get _statusText {
    return switch (widget.loadStatus) {
      DanmakuLoadStatus.loading => '加载弹幕中',
      DanmakuLoadStatus.empty => '暂无弹幕',
      DanmakuLoadStatus.failure => '弹幕加载失败',
      DanmakuLoadStatus.idle || DanmakuLoadStatus.loaded => null,
    };
  }

  String _speedLabel(double speed) {
    const labels = <(double, String)>[
      (0.5, '极慢'),
      (0.875, '较慢'),
      (1.25, '适中'),
      (1.625, '较快'),
      (2.0, '极快'),
    ];
    var nearest = labels.first;
    for (final label in labels.skip(1)) {
      if ((label.$1 - speed).abs() < (nearest.$1 - speed).abs()) {
        nearest = label;
      }
    }
    return '${nearest.$2} ${speed.toStringAsFixed(2)}x';
  }
}
