# Changelog

All notable changes to FlyNarwhal will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
发版流程：
1. 把下方 `## [Unreleased]` 的内容整理为正式发布说明，并将标题改标为 `## [X.Y.Z] - 日期`
   （预发布版本保留后缀写法，如 `[X.Y.Z-alpha]`）。
2. 打与标题一一对应的 tag：去掉前导 `v` 后必须与节标题一致，例如节标题 `[2.0.3-alpha]`
   对应 tag `v2.0.3-alpha`。GitHub Release 会自动截取该段作为更新说明。
3. 提交并推送 tag，触发 release workflow。
-->

## [Unreleased]

### Added

### Changed

### Fixed

## [2.0.1-alpha] - 2026-08-09

> ⚠️ **此版本为测试版本（Alpha），仅供内部验证，禁止下载安装使用。**
> ⚠️ **This is a test (Alpha) build for internal verification only. Do NOT download or install.**

### Added

- **完整应用版本号支持**：实现应用完整版本号（含预发布后缀）的读取与展示。
- **发布分页优化**：优化更新检查的发布分页逻辑。

## [2.0.0-alpha] - 2026-08-10

> ⚠️ **此版本为测试版本（Alpha），仅供内部验证，禁止下载安装使用。**
> ⚠️ **This is a test (Alpha) build for internal verification only. Do NOT download or install.**

2.0.x 系列桌面端重写，聚焦播放器能力与跨平台构建稳定性。

### Added

- **播放器窗口独立几何管理**：支持画面比例（宽高比）控制与独立窗口几何状态管理，每个媒体可持久记忆画面比例设置。
- **画面比例与进阶设置**：新增视频填充模式（画面比例）设置并按媒体持久化；新增强制 H.264 与 SDR 色调映射等进阶选项。
- **自定义视频质量页**：重构视频质量列表，与 Web 端播放器样式对齐，并支持质量浮层对齐 Web 端。
- **本地字幕选择器**：支持 Windows/macOS 本地字幕文件选择，新增用户 GUID 参数以支持本地字幕识别；支持字幕删除与批量下载功能。
- **文件媒体信息**：新增文件媒体信息对话框，与飞牛影视 Web 端一致。
- **更新报告与启动上报**：新增应用启动上报功能；实现完整应用版本号支持与发布分页优化。
- **Live TV（直播电视）支持**：新增直播电视媒体库、直播电视搜索，以及直播电视分类功能。
- **播放详情面板**：新增播放详情面板，修复音频与视频图标路径。
- **macOS 原生交互**：启用 macOS 原生双击标题栏缩放；修复深色模式下窗口顶部白色高亮线。
- **全量 libmpv 打包**：macOS/Linux 打包完整 libmpv，支持 PGS/SUP 字幕（HDMV PGS 字幕解码）。

### Changed

- **登录页重构**：重构 JavaScript 注入逻辑与历史记录功能。
- **搜索组件重构**：将搜索结果下拉组件重构为有状态组件并支持滚动；实现 CapsuleSearchBox 标签切换。
- **媒体类型枚举化**：用枚举替换字符串比较进行媒体类型判断；优化媒体轨道语言名称解析逻辑。
- **字幕选择器重构**：重构电影详情页字幕选择器；重构应用对话框组件并更新样式。
- **播放器细节优化**：优化播放详情浮层布局与播放状态刷新逻辑、标题提示组件的计时显示逻辑；移除无用 PiP 过渡动画控制器。
- **窗口几何重构**：重构窗口几何存储与定位逻辑。
- **设置页与图标**：更新设置页图标与依赖。
- **Linux 中文字体**：修复 Linux 平台中文字体渲染问题。

### Fixed

- **播放器**：修复播放器初始化期间返回按钮不可见的问题；修复播放恢复位置功能；修复 macOS 剪贴板粘贴功能。
- **布局**：修复拖拽区域高度限制问题。
- **构建/发布**：修复 4/6 个失败的平台构建；修复 macOS/Linux 打包发布流程（.dmg、.deb 打包）；修复预发布资产版本后缀命名；修复 lint 嵌套产物路径处理。
- **Linux 兼容**：使用 GTK3 兼容的 `gdk_window_get_display`；调整 libmpv POST_BUILD 挂载到 runner target 作用域。