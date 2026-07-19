# 倍速弹框悬停不消失修复计划

## Summary

- 目标：继续修复播放器底栏倍速弹框的悬停逻辑，确保鼠标悬停在按钮或弹框本体上时弹框都不会消失。
- 范围：仅调整 `lib/ui/player/widgets/speed_control_flyout.dart` 的显示/隐藏与承载方式。
- 约束：保持现有视觉样式、尺寸、动画时长、文案与条目布局不变。
- 参考：对齐 Kotlin 版 `lib/ui/components/speed_control_flyout.dart` 的显隐控制思路，使用按钮 hover 与 popup hover 的组合状态控制关闭时机。

## Current State Analysis

- 当前 Flutter 实现在 `lib/ui/player/widgets/speed_control_flyout.dart` 中使用 `MouseRegion + Stack + Positioned` 将弹框绘制在按钮区域外。
- 为了连接按钮与上方弹框，当前实现额外放了一个透明 `SizedBox` 命中桥接区，但它和真实弹框是两个分离的 `Positioned`，鼠标从按钮移动到弹框过程中仍可能先触发按钮 `onExit`，再因命中切换不连续而进入延时关闭。
- 现有状态字段为 `_isButtonHovered`、`_popupHovered`、`_showPopup`，隐藏逻辑依赖 `_hideFlyoutWithDelay()`；这套状态机方向正确，但受限于父 `Stack` 越界绘制和分离命中区域，仍会出现悬停在弹框本体上时消失的问题。
- Kotlin 参考实现通过独立 Overlay 承载弹框，并在 Overlay 内部直接维护 popup hover 状态，避免了父组件裁剪边界与命中切换不稳定的问题。
- `player_screen.dart` 当前仅以组件方式挂载 `SpeedControlFlyout`，不需要改动调用接口。

## Proposed Changes

### `lib/ui/player/widgets/speed_control_flyout.dart`

- 将当前基于父级 `Stack` 越界绘制的弹框，改为基于 `OverlayEntry` 或 `OverlayPortal` 的独立 Overlay 承载。
- 为按钮建立稳定的锚点：
  - 保留按钮主体的 `MouseRegion` 负责 `_isButtonHovered`。
  - 通过 `GlobalKey` 或 `LayerLink` 获取按钮在全局坐标中的位置与尺寸。
- 将弹框与按钮之间的可悬停过渡区域放入同一个 Overlay 命中容器内，而不是拆成两个兄弟 `Positioned`：
  - Overlay 容器整体负责 popup hover。
  - 容器内包含现有视觉弹框和按钮到弹框之间的透明过渡区域。
  - 这样鼠标从按钮移动到弹框时，popup hover 能尽早建立，不会因命中断层触发关闭。
- 重构显隐逻辑，但保持行为与 Kotlin 参考一致：
  - `show`：进入按钮时立即取消隐藏定时器，并展示 Overlay。
  - `hide`：仅当 `_isButtonHovered == false` 且 `_popupHovered == false` 时，才启动延时关闭。
  - `close`：关闭时先反向播放现有动画，再移除 Overlay。
  - 选择倍速后：保持当前关闭行为，但通过统一关闭路径清理 hover/overlay 状态。
- 保留现有样式：
  - 不修改颜色、圆角、边框、宽度、文案、选中态、hover 背景样式。
  - 不修改 `_animationDurationMs`、缩放与透明度动画参数，除非 Overlay 化后必须做最小适配。
- 保留现有对外接口：
  - `defaultSpeed`
  - `yOffset`
  - `onHoverStateChanged`
  - `onSpeedSelected`

## Assumptions & Decisions

- 决定只修复倍速弹框，不同步改动 `quality_control_flyout.dart`、`episode_selection_flyout.dart`、`subtitle_control_flyout.dart`，避免扩大本次变更范围。
- 决定以“命中稳定性优先”为原则，优先替换承载方式，而不是继续微调当前透明桥接区尺寸。
- 决定不变更 `player_screen.dart` 的调用方式，除非在实现时发现 Overlay 化需要额外的锚点参数；按当前探索结果预计不需要。
- 假设当前 Flutter 版本可直接使用 Overlay 相关能力；若 `OverlayPortal` 在当前工程不可用，则退回 `OverlayEntry + GlobalKey`，但行为目标保持一致。

## Verification Steps

- 代码检查：
  - 确认 `SpeedControlFlyout` 在按钮 hover、弹框 hover、移出两者、点击条目四种路径下的状态流转闭合。
  - 确认 Overlay 生命周期在关闭与组件销毁时会被正确移除，不残留悬挂弹层。
- 手动验证：
  - 鼠标移入倍速按钮，弹框正常显示。
  - 鼠标从按钮移动到弹框中间过渡区域，再移动到弹框本体，弹框不消失。
  - 鼠标持续停留在弹框本体任意条目上，弹框不消失。
  - 鼠标同时离开按钮和弹框后，弹框按现有延时关闭。
  - 点击任意倍速项后，弹框正常关闭且倍速切换正常。
  - 视觉上确认弹框样式、位置、动画效果与当前版本保持一致。
- 验证工具：
  - 修改后运行 Flutter 分析或至少对目标文件执行诊断，确保无新增静态错误。
  - 如可运行桌面端，进入播放器页面进行实际鼠标悬停回归验证。
