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

## [2.3.1] - 2026-08-29

> 💡 **如遇自动更新失败，请访问 [https://github.com/FNOSP/FlyNarwhal/releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载最新安装包后手动更新。**

### Added

- **Windows 便携版**：新增 Windows 便携版（zip）安装包，支持应用内自更新。
- **剧集分季切换**：剧集分季详情页新增分季切换功能，可直接跳转至其他分季详情页。
- **多显示器窗口记忆**：记住窗口所在显示器，主窗口跨屏移动时播放器窗口跟随。

### Changed

- **窗口最小尺寸**：主窗口最小尺寸降低至 800×450，在小屏幕启动时窗口自动适配。

### Fixed

- **返回页面定位**：从详情页或播放器返回后，恢复之前浏览的位置。
- **跳过片头片尾**：修复跳过片头片尾设置不生效的问题。
- **弹幕显示时机**：修复视频未开始播放时弹幕提前显示的问题。
- **播放器窗口尺寸**：修复全屏、最大化与画面比例切换时窗口尺寸异常的问题。
- **界面细节优化**：优化剧集简介弹框样式与左侧导航抽屉圆角显示。

## [2.3.0-beta] - 2026-08-24

> 💡 **如遇自动更新失败，请访问 [https://github.com/FNOSP/FlyNarwhal/releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载最新安装包后手动更新。**

### Added

- **STRM 直连播放**：对齐飞牛影视 Web 端 STRM 文件直连播放流程，解析后直连云端地址。
- **新增剧集详情页**：剧集详情页复用电影详情页，头部显示面包屑与集标题，隐藏演职人员区。

### Changed

- **媒体库分类图标复用**：抽取共享的媒体库分类图标映射，主布局与详情页复用同一套图标。

### Fixed

- **Windows 更新 Defender 行为收敛**：安装助手改用 /SILENT 安装器、恢复任务改用任务计划 COM，减少 Defender 误报与自我复制行为；回退改为直接重启宿主副本。
- **播放器 VOD 来源路径记录**：所有 VOD 播放入口记录播放器来源路径，修复播放器返回路径错误。
- **标题栏更新徽章对齐**：更新徽章与同级 caption 图标高度对齐。
- **自动隐藏失效**：修复点击「下一集」后，其他切换按钮悬浮弹框残留导致控制 UI 自动隐藏失效的问题。

## [2.2.1-beta] - 2026-08-23

> 💡 **如遇自动更新失败，请访问 [https://github.com/FNOSP/FlyNarwhal/releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载最新安装包后手动更新。**

### Added

- **Arch Linux 安装包**：支持 Arch Linux pacman（.pkg.tar.zst）安装包。
- **服务端自更新检查**：新增自动检测飞牛影视服务端自更新。
- **演员简介返回定位**：详情页点击演员后返回时，滚动条定位回被点击的演员。
- **授权码输入提示**：设置页中授权码新增引导提示。

### Changed

- **设置按用户隔离**：全局设置与播放器偏好迁移为按用户范围存储，并为旧数据提供一次性自动迁移。
- **更新徽章样式**：标题栏更新徽章改用新版图标并调整间距。

### Fixed

- **弹幕开关状态**：关闭弹幕时禁用弹幕相关设置项，修正切换图标，重新识别失败时隐藏弹幕。
- **智能跳过开关回退**：回退智能跳过切换逻辑。
- **直播弹框同步关闭**：快速移动鼠标时同步关闭线路选择/音量弹框。
- **连接测试错误信息**：连接测试失败时展示服务端返回的具体错误信息。
- **服务器不可达提示**：服务器不可达时显示更友好的提示。
- **转码播放鉴权**：转码 HLS 播放 URL 附带 NAS 鉴权头。
- **优化更新弹窗**：更新弹窗包裹 ExcludeSemantics，消除 Windows AXTree 错误日志。
- **异步关闭安全**：AppDialog 在异步操作后安全自动关闭。

## [2.2.0-beta] - 2026-08-21

> 💡 **如遇自动更新失败，请访问 [https://github.com/FNOSP/FlyNarwhal/releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载最新安装包后手动更新。**

### Added

- **网盘视频播放**：新增网盘（夸克、115、123、阿里云盘、百度网盘）视频播放能力，对齐飞牛影视 Web 端播放流程，支持 NAS 代理启动失败时自动回退直连播放。
- **文件夹浏览**：新增文件夹视图。
- **选集视图切换**：剧集详情页选集区块的新增卡片视图 / 序号视图切换开关，支持切换状态全局持久化。
- **播放结束界面优化**：播放结束页样式优化。
- **更新日志弹窗**：设置中新增更新日志弹窗，渲染内置 CHANGELOG.md。
- **登录密码错误提示**：登录失败（密码错误）时显示「用户名或密码错误」提示。

### Changed

- **依赖升级**：升级 go_router、window_manager、liquid_glass_widgets、flutter_lints 等依赖。
- **演员简介交互**：人物详情页简介对齐飞牛影视 Web 端，超出时行内截断并显示「更多」链接，点击以弹窗查看完整内容。

### Fixed

- **Windows 更新安装流程**：修复 Windows 端退出并安装流程。
- **播放器兼容 Flutter 3.38+**：升级 media_kit_video 至 2.0.1，修复 Flutter 3.38+ 硬件渲染播放问题。
- **Linux Wayland 标题栏**：修复 KDE Wayland 下 KWin 重复绘制系统标题栏的问题。
- **侧边栏 LeftMinimal 顶部留白**：移除 LeftMinimal 模式下导航栏顶部 38px 空白条。
- **直播频道封面显示**：修复最近观看中直播频道封面裁切与占位图尺寸问题。
- **直播播放器返回路径**：退出直播播放器后正确返回进入前的页面。
- **影片文件位置用户名**：正确解析文件位置展示的用户名。
- **播放器控制浮层重叠**：快速移动鼠标时同步关闭被替代的控制弹框，避免多个弹框重叠。
- **剧集季/集数标签**：对齐飞牛影视 Web 端「共 x 集 / 共 x 季」标签展示逻辑。

## [2.1.2-beta] - 2026-08-16

> 💡 **如遇自动更新失败，请访问 [https://github.com/FNOSP/FlyNarwhal/releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载最新安装包后手动更新。**

### Added

- **AppButton 包装器**：新增 `AppButton` 包装器，统一所有按钮的手型光标。

### Changed

- **macOS 播放器音量增益**：将 macOS 端 mpv 音量增益提升至 1.7 倍。

### Fixed

- **登录页忘记密码弹窗**：修复登录页点击「忘记密码」无弹窗的问题，使用统一 AppDialog 样式并显示与 Web 端一致的提示内容。
- **fnOS 登录 WebView 异常提示**：抑制 NAS 登录 WebView 中由代理 NE 拦截 QUIC 触发的「系统异常」 alert。
- **更新弹窗当前版本展示**：在更新弹窗中显示当前已安装的版本号。

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