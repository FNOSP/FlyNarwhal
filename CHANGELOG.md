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

## [2.1.1-beta] - 2026-08-16

> 💡 **如遇自动更新失败，请访问 [https://github.com/FNOSP/FlyNarwhal/releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载最新安装包后手动更新。**

### Added

- **GitHub 标签版本校验**：发布构建时校验 GitHub tag 与 pubspec 版本一致，避免资产文件名与 release 版本不匹配。

### Changed

- **移除旧版 Go 更新器**：清理已弃用的 Go 更新器相关代码。
- **Windows 原生安装交接**：优化 Windows 端更新下载后的原生安装流程，提升升级交接可靠性。

### Fixed

- **更新徽章对齐**：修复标题栏更新徽章未垂直居中的问题。
- **更新缓存信任状态**：保留更新缓存的信任状态，避免重复提示。
- **libmpv 校验下载重试**：在 libmpv 校验文件下载失败时增加重试机制。
- **播放器文本控制触发区域**：为文本型控制触发区域增加内边距，与图标按钮间距保持一致。
- **电视直播切换线路 UI 不隐藏**：修复电视直播切换线路后 UI 和光标不自动隐藏的问题。
- **最近观看直播进度条**：在最近观看的直播频道卡片中隐藏进度条。
- **硬解探测音频泄漏**：静音硬解探测过程，防止探测期间的开播声音泄漏到恢复播放。
- **快捷键设置滚动条位置**：调整快捷键设置弹窗滚动条位置，避免与输入框重叠。

## [2.1.0-alpha] - 2026-08-15

> ⚠️ **此版本为测试版本（Alpha），仅供内部验证，禁止下载安装使用。**
> ⚠️ **This is a test (Alpha) build for internal verification only. Do NOT download or install.**
>
> 💡 **如遇自动更新失败，请访问 [https://github.com/FNOSP/FlyNarwhal/releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载最新安装包后手动更新。**

### Added

- **IPTV 直播播放器**：新增与 Web 端直播体验对齐的独立 IPTV 直播播放器。
- **硬解/解码模式设置**：播放器设置新增客户端解码模式菜单，支持手动选择硬件解码器。
- **直播/媒体库布局切换**：为直播库与普通媒体库提供可切换的布局菜单，最小化布局下支持导航展开/收起按钮。
- **macOS 全局设置快捷键**：在播放器外的页面按 `Cmd + ,` 可直接打开设置。
- **Banner 海报悬停 overlay**：媒体库横幅海报新增类 Web 的悬停遮罩层。
- **直播库偏好持久化**：直播库的布局、排序与筛选偏好按用户持久化存储。
- **关于/支持作者入口**：设置中新增支持作者入口，可打开 GitHub 仓库对话框。

### Changed

- **日志策略**：控制台日志保持截断，文件日志保留完整内容；Release 构建中启用完整的 Dio 请求/响应日志。
- **macOS 签名**：DMG 打包前对 macOS bundle 进行 ad-hoc 签名。
- **Windows libmpv 固定**：Windows 构建改从自托管仓库 `Jankin-Wu/fly-narwhal-libmpv` 的 latest release 获取 libmpv，避免上游 zhongfly release 删除导致构建失败；继续固定无底部绿边问题的 2026-05-31 构建。
- **README 文档**：补充 2.0 核心功能说明章节。
- **快捷键设置弹窗**：使用统一的 `AppDialog` 重构快捷键设置弹窗。

### Fixed

- **直链播放恢复**：关闭“强制 H.264 / SDR”开关后恢复直接播放链路。
- **用户画质记忆**：恢复按用户持久化的画质选择记忆。
- **片头跳过提示**：切换画质后若片头已结束，不再弹出片头跳过提示。
- **IPTV 占位图**：无海报的 IPTV 库卡片显示占位图。
- **剧集分集定位**：获取播放信息时跳过缓存，避免分集列表定位到旧集数。
- **播放器退出导航**：退出播放器后返回到进入前的页面。
- **播放信息 title 字段兼容**：兼容服务端 play/info 接口剧集缺少 `title` 字段的情况。
- **播放详情面板自动隐藏**：将播放信息面板与控制条自动隐藏逻辑解耦，避免关闭面板后自动隐藏失效。
- **更新弹窗浅色模式适配**：更新弹窗跟随应用主题使用浅色配色，不再固定深色外观。
- **更新说明引用块对比度**：修复深色模式下更新弹窗中引用块（如 Alpha 警告）背景与文字颜色相近导致难以阅读的问题。

## [2.0.1-alpha] - 2026-08-11

> ⚠️ **此版本为测试版本（Alpha），仅供内部验证，禁止下载安装使用。**
> ⚠️ **This is a test (Alpha) build for internal verification only. Do NOT download or install.**

### Added

- **完整应用版本号支持**：实现应用完整版本号（含预发布后缀）的读取与展示。
- **Windows ARM64 支持**：新增 Windows arm64 构建流程与本地 media_kit 依赖覆盖。
- **安装器图标与文件校验**：Windows 安装程序配置自定义图标，并增加构建产物文件存在性校验。

### Changed

- **发布分页优化**：优化更新检查的发布分页逻辑与版本解析算法。
- **更新器健壮性提升**：改用 FFI 查询 Windows 磁盘剩余空间，减少外部命令依赖；增强可执行文件类型兼容性。
- **主布局更新角标**：在主导航添加更新提示角标，并优化窗口标题栏结构。
- **播放器设置菜单**：新增播放器设置菜单高度测量能力。

### Fixed

- **主题默认值**：修复主题设置默认值异常。

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
- **功能更完整**：新增 Live TV、媒体信息面板、播放详细信息面板，以及强制 H.264 / SDR 色调映射等进阶播放选项。