# 播放器续播修复计划

## 一、Summary

- 目标：修复 Flutter 播放器在进入 [player_screen.dart](file:///Users/jankinwu/Desktop/workspace/flutter/fly-narwhal-flutter/lib/ui/screens/player/player_screen.dart) 时未从上次观看位置开始播放的问题。
- 参考基线：对齐 Kotlin 端 [PlayerScreen.kt](file:///Users/jankinwu/Desktop/workspace/kotlin/FlyNarwhal/composeApp/src/commonMain/kotlin/com/jankinwu/fntv/client/ui/screen/PlayerScreen.kt#L2691-L2803) 的续播流程：读取 `playInfoResponse.ts` → 解析播放链接时携带历史位置 → 起播后执行一次明确的初始 seek。
- 输出范围：仅调整 Flutter 播放器的起播与续播恢复逻辑，不扩展到详情页入口、播放记录接口或其他播放器功能。

## 二、Current State Analysis

### 1. Flutter 当前实现

- [player_screen.dart:L232-L353](file:///Users/jankinwu/Desktop/workspace/flutter/fly-narwhal-flutter/lib/ui/screens/player/player_screen.dart#L232-L353)
  - 已在 `_loadAndPlayMedia()` 中通过 `playInfo.ts * 1000` 计算 `historyMs`。
  - 已在 `_resolvePlayLink(... startPositionMs: historyMs ...)` 中把历史位置传给播放链接解析逻辑。
  - 已在 `_player.open(...)` 后直接调用 `_player.seek(...)`。
- [player_screen.dart:L208-L229](file:///Users/jankinwu/Desktop/workspace/flutter/fly-narwhal-flutter/lib/ui/screens/player/player_screen.dart#L208-L229)
  - MP4 直链场景优先尝试通过 `range=bytes=` 做字节偏移续播，成功时 `effectiveStartMs = 0`。
- [player_screen.dart:L382-L401](file:///Users/jankinwu/Desktop/workspace/flutter/fly-narwhal-flutter/lib/ui/screens/player/player_screen.dart#L382-L401)
  - 播放中每 5 秒上报一次 `/v/api/v1/play/record`，说明“保存进度”链路已存在。

### 2. Kotlin 参考实现

- [PlayerScreen.kt:L2691-L2755](file:///Users/jankinwu/Desktop/workspace/kotlin/FlyNarwhal/composeApp/src/commonMain/kotlin/com/jankinwu/fntv/client/ui/screen/PlayerScreen.kt#L2691-L2755)
  - 先读取 `historyStartPosition = playInfoResponse.ts * 1000`。
  - 保存一组“初始续播状态”，确保首次起播 seek 有明确目标。
- [PlayerScreen.kt:L2911-L2958](file:///Users/jankinwu/Desktop/workspace/kotlin/FlyNarwhal/composeApp/src/commonMain/kotlin/com/jankinwu/fntv/client/ui/screen/PlayerScreen.kt#L2911-L2958)
  - `startPlayback()` 中先起播，再在短暂延迟后调用 `onSeekTo(startPosition)`，而不是仅依赖“打开媒体后立即 seek”。

### 3. 初步问题判断

- Flutter 端“有续播数据，也有 seek 调用”，但续播失败，最可能的问题不在接口层，而在“首次起播 seek 的时机和稳定性”。
- 当前 Flutter 逻辑在 `open()` 后立即 `seek()`，缺少 Kotlin 端那种“起播后再执行一次受控初始 seek”的处理，容易在播放器尚未稳定时被忽略或被后续状态覆盖。
- 当前 Flutter 端没有显式记录“初始续播位置是否已应用”，后续如切画质、初始化状态切换时也缺乏统一入口。

## 三、Proposed Changes

### 1. 调整 Flutter 播放器的初始续播执行方式

- 文件：[player_screen.dart](file:///Users/jankinwu/Desktop/workspace/flutter/fly-narwhal-flutter/lib/ui/screens/player/player_screen.dart)
- 变更内容：
  - 抽出统一的“起播后恢复进度”流程，避免在多个位置直接散落 `open() + seek()`。
  - 引入 Flutter 侧的初始续播状态字段，例如：
    - 初始目标位置毫秒值
    - 是否已完成首次续播
    - 是否需要在媒体就绪后重试一次
  - 在首次加载媒体时，对齐 Kotlin 端思路：先打开媒体，再在合适时机执行一次明确的初始 seek；必要时基于播放器当前位置/时长状态判断是否需要补一次 seek。
- 目的：
  - 提升首次打开播放器时历史进度恢复的成功率。
  - 让续播逻辑从“单次立即 seek”改为“受控的初始化恢复流程”。

### 2. 统一首播与切画质场景的恢复入口

- 文件：[player_screen.dart](file:///Users/jankinwu/Desktop/workspace/flutter/fly-narwhal-flutter/lib/ui/screens/player/player_screen.dart#L470-L549)
- 变更内容：
  - 将首播和切画质后的重新打开媒体，统一走同一套“open + 恢复位置”流程。
  - 保持现有 MP4 直链字节偏移逻辑；当 `effectiveStartMs > 0` 时，统一使用新的恢复流程执行 seek。
- 目的：
  - 避免两个入口各自处理 seek，造成行为不一致。
  - 保持后续维护时对续播行为的单点治理。

### 3. 保留现有接口契约，不改动服务层协议

- 文件：
  - [player_service.dart](file:///Users/jankinwu/Desktop/workspace/flutter/fly-narwhal-flutter/lib/ui/player/player_service.dart)
  - [movie_detail_models.dart](file:///Users/jankinwu/Desktop/workspace/flutter/fly-narwhal-flutter/lib/data/models/movie_detail_models.dart#L498-L545)
- 变更策略：
  - 不修改 `play/info`、`play/record` 的接口结构。
  - 继续使用已有的 `PlayInfoResponse.ts` 作为唯一的历史进度来源。
- 原因：
  - 现有问题更像播放器时序问题，不是数据模型或接口缺失问题。

## 四、Assumptions & Decisions

- 假设 1：服务端 `play/info.ts` 返回值是正确的，且当前问题主要出现在 Flutter 播放器应用该进度的时机上。
- 假设 2：现有 `media_kit` 播放器允许在媒体打开后做二次 seek；如果首次立即 seek 不稳定，则可通过延迟/就绪判断补偿。
- 决策 1：修复优先聚焦播放器内部恢复流程，不改详情页跳转和播放记录上报协议。
- 决策 2：保留现有 MP4 直链偏移续播逻辑；仅在需要时间 seek 的场景加强执行稳定性。
- 决策 3：实现后需要实际运行验证“电影/剧集进入播放器时是否从历史位置开始播放”，而不是只依赖静态检查。

## 五、Verification

- 代码层验证
  - 检查 [player_screen.dart](file:///Users/jankinwu/Desktop/workspace/flutter/fly-narwhal-flutter/lib/ui/screens/player/player_screen.dart) 中首播与切画质是否都走统一的恢复入口。
  - 检查续播状态字段只在初始化恢复流程中读写，避免重复 seek 或状态残留。
- 运行验证
  - 启动 Flutter 应用并进入播放器页面。
  - 选择一个已有观看记录的视频，确认进入播放器后能从历史进度开始播放。
  - 验证至少一个电影场景；若仓库现有入口方便，也验证一个剧集场景。
  - 在播放到新位置后退出重进，确认新的观看进度可再次被正确恢复。
  - 切换画质后确认仍保持当前播放位置附近，不回到开头。
- 回归验证
  - 确认无历史进度时仍从开头正常播放。
  - 确认 MP4 直链与普通播放链接两种路径至少不出现明显回退。
