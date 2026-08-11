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
>
> 💡 **如遇自动更新失败，请访问 [https://github.com/FNOSP/FlyNarwhal/releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载最新安装包后手动更新。**

2.0.x 系列使用 Flutter 对桌面端进行了全面重写，不再依赖 JVM 运行时，UI 与窗口交互更贴近原生系统体验。相比 1.x（Kotlin Multiplatform / Compose Desktop）版本，本版本在启动速度、播放性能、平台覆盖和功能完整性上均有质的飞跃。

### 核心升级

- **Flutter 原生重写**：2.0.x 基于 Flutter 框架重新构建桌面端，渲染与窗口调度更贴近原生系统，告别 JVM 运行时的额外开销，安装包更轻量、运行更高效。
- **启动与起播更快**：启动链路、播放器初始化与首帧渲染均经过优化，应用打开与视频起播速度较 1.x 显著提升。
- **内置 mpv 播放器，本地解码能力大幅增强**：采用 media_kit + 全量 libmpv 作为播放内核，支持 GPU 硬解与本地解码；macOS / Linux 打包完整 libmpv，支持 PGS/SUP 字幕（HDMV PGS 字幕解码），可直接处理 HDR / HLG / Dolby Vision 等动态范围视频。相比 1.x 受限于 Compose Desktop 渲染机制、硬解画面需经 RGBA 回读 CPU 再渲染导致的高 CPU 占用与被迫服务端转 SDR，2.x 显著降低 CPU 占用并保留原片动态范围。
- **过渡动画更流畅**：重构并精简动画链路，移除冗余过渡控制器，页面切换与播放相关交互动画更加顺滑。
- **Windows 全屏体验提升**：Windows 端改用伪全屏模式，解决 1.x 使用系统全屏时无法在播放器窗口上同时显示其他应用的问题。
- **Liquid Glass 视觉设计**：登录页引入 Liquid Glass 设计语言，配合 Acrylic 毛玻璃质感与更现代的布局，整体视觉更通透、更贴近原生系统美学。
- **登录密码加密存储**：登录历史中的密码不再明文落盘：基于 AES-256-GCM 认证加密 + HKDF 派生密钥，配合随机 salt/nonce、认证标签与密文完整性校验；加密完成后对敏感内存进行零化，密钥异常或密文被篡改时自动清除旧密码，避免本地持久化泄露风险。
- **支持更多平台与 CPU 架构**：1.x 仅覆盖 Windows 与 macOS；2.0.0-alpha 新增 Linux，完整覆盖 Windows x64、macOS x64 / arm64（Intel / Apple Silicon）、Linux x64 / arm64，安装包格式包括 .exe、.dmg、.deb、.rpm 与 .AppImage。
- **功能更完整**：新增 Live TV、本地字幕选择器、文件媒体信息对话框、播放详情面板、按媒体持久化的画面比例与窗口几何管理，以及强制 H.264 / SDR 色调映射等进阶播放选项。