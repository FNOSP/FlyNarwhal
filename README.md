<h1 align="center">Fly Narwhal</h1>

<p align="center">
  <img src="img/fly_narwhal_banner.svg" alt="fnarwhal_home" width="800" />
</p>

<div align="center">

[![GitHub stars](https://img.shields.io/github/stars/FNOSP/FlyNarwhal)](https://github.com/FNOSP/FlyNarwhal/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/FNOSP/FlyNarwhal)](https://github.com/FNOSP/FlyNarwhal/network)
[![GitHub issues](https://img.shields.io/github/issues/FNOSP/FlyNarwhal)](https://github.com/FNOSP/FlyNarwhal/issues)
[![GitHub license](https://img.shields.io/github/license/FNOSP/FlyNarwhal)](https://github.com/FNOSP/FlyNarwhal/blob/master/LICENSE)
[![Dart](https://img.shields.io/badge/Dart-3.2%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-Desktop-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)

面向飞牛影视服务的第三方 Flutter 桌面客户端，当前聚焦 Windows、macOS、Linux 三端体验。

服务端项目：https://github.com/FNOSP/fly-narwhal-server

</div>

---

## 声明

**本项目为飞牛 OS 爱好者开发的第三方影视客户端，与飞牛影视官方无关。使用前请确保遵守相关服务条款。**

## 项目结构

```text
.
├─ lib/                  Flutter 主应用代码
├─ assets/               字体、图片、动画资源
├─ updater/              Windows 自更新器（Go）
├─ scripts/release/      正式发布构建脚本
├─ .github/workflows/    GitHub Actions 发布流程
├─ windows/              Windows Runner / CMake 构建配置
├─ macos/                macOS Runner
└─ linux/                Linux Runner
```

## 界面预览

> 最终效果以实际发布版本为准

![image-20251230020234381](http://oss.jankinwu.com/img/image-20251230020234381.png)

![image-20251230020717917](http://oss.jankinwu.com/img/image-20251230020717917.png)

![image-20251230021217242](http://oss.jankinwu.com/img/image-20251230021217242.png)

## 核心特性

2.0.x 系列使用 Flutter 对桌面端进行了全面重写，不再依赖 JVM 运行时，UI 与窗口交互更贴近原生系统体验。相比 1.x（Kotlin Multiplatform / Compose Desktop）版本，本版本在启动速度、播放性能、平台覆盖和功能完整性上均有质的飞跃。

- **Flutter 原生重写**：2.0.x 基于 Flutter 框架重新构建桌面端，渲染与窗口调度更贴近原生系统，告别 JVM 运行时的额外开销，安装包更轻量、运行更高效。
- **启动与起播更快**：启动链路、播放器初始化与首帧渲染均经过优化，应用打开与视频起播速度较 1.x 显著提升。
- **内置 mpv 播放器，本地解码能力大幅增强**：采用 media_kit + 全量 libmpv 作为播放内核，支持 GPU 硬解与本地解码；macOS / Linux 打包完整 libmpv，支持 PGS/SUP 字幕（HDMV PGS 字幕解码），可直接处理 HDR / HLG / Dolby Vision 等动态范围视频。相比 1.x 受限于 Compose Desktop 渲染机制、硬解画面需经 RGBA 回读 CPU 再渲染导致的高 CPU 占用与被迫服务端转 SDR，2.x 显著降低 CPU 占用并保留原片动态范围。
- **过渡动画更流畅**：重构并精简动画链路，移除冗余过渡控制器，页面切换与播放相关交互动画更加顺滑。
- **Windows 全屏体验提升**：Windows 端改用伪全屏模式，解决 1.x 使用系统全屏时无法在播放器窗口上同时显示其他应用的问题。
- **Liquid Glass 视觉设计**：登录页引入 Liquid Glass 设计语言，配合 Acrylic 毛玻璃质感与更现代的布局，整体视觉更通透、更贴近原生系统美学。
- **登录密码加密存储**：登录历史中的密码不再明文落盘：基于 AES-256-GCM 认证加密 + HKDF 派生密钥，配合随机 salt/nonce、认证标签与密文完整性校验；加密完成后对敏感内存进行零化，密钥异常或密文被篡改时自动清除旧密码，避免本地持久化泄露风险。
- **支持更多平台与 CPU 架构**：1.x 仅覆盖 Windows 与 macOS；2.0.0-alpha 新增 Linux，完整覆盖 Windows x64、macOS x64 / arm64（Intel / Apple Silicon）、Linux x64 / arm64，安装包格式包括 .exe、.dmg、.deb、.rpm 与 .AppImage。
- **功能更完整**：新增 Live TV、媒体信息面板、播放详细信息面板，以及强制 H.264 / SDR 色调映射等进阶播放选项。

## 使用说明

### 使用安装包安装

前往 [Releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载对应平台的安装包或发行产物。

#### macOS 安装被系统阻止的处理

从网上下载的安装包首次启动时，macOS 可能会提示“无法验证开发者”或“已损坏”。这是因为安装包没有经过 Apple 的付费公证，并且被系统打上了隔离标记，属于正常的系统安全机制。

发布版本会对 `FlyNarwhal.app` 进行临时签名，因此多数情况下只会出现“无法验证开发者”的提示。如果你仍然看到“已损坏”或无法正常打开，可以通过手动移除隔离标记来解决。将 `FlyNarwhal.app` 拖入“应用程序”后，在终端执行：

```bash
xattr -dr com.apple.quarantine /Applications/FlyNarwhal.app
```

执行完成后即可正常启动。

注意事项：

- 请在 app 已放入 `/Applications` **之后**再执行。
- 每次从浏览器重新下载安装包并重装后，都需要重新执行一次（新拷贝的 app 会带上新的隔离标记）。
- 通过应用内自动更新安装的版本不会带有隔离标记，因此通常不需要重复执行。
- 该命令只影响当前这台电脑。

### 从源码运行

#### 准备环境

- 安装 [Flutter Stable SDK](https://docs.flutter.dev/get-started/install)，并确保 `flutter --version` 可用

- 启用桌面平台支持
  
  ```bash
  flutter config --enable-windows-desktop
  flutter config --enable-macos-desktop
  flutter config --enable-linux-desktop
  ```

- Windows 开发建议安装 Visual Studio 2022 的“Desktop development with C++”

- Windows 本地运行与构建还需要 [Go](https://go.dev/dl/) 1.23 或以上版本
  
  - 当前 `windows/CMakeLists.txt` 会在构建时同步编译 `updater.exe`
  - 请确保 `go version` 可在 PATH 中正常执行

- macOS 需要安装 Xcode 与 Command Line Tools

- Linux 需要准备常见 Flutter 桌面依赖，例如 `clang`、`cmake`、`ninja-build`、`pkg-config`、`libgtk-3-dev`

#### 拉取依赖

```bash
git clone https://github.com/FNOSP/FlyNarwhal.git
cd FlyNarwhal
flutter pub get
```

#### 运行桌面端

Windows：

```powershell
flutter run -d windows
```

macOS：

```bash
flutter run -d macos
```

Linux：

```bash
flutter run -d linux
```

#### 生成代码

项目中使用了 Riverpod 与 `json_serializable`。如果你修改了带注解的模型或 Provider，请重新生成代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 打包为可执行文件

#### 本地构建

Windows：

```powershell
flutter build windows --release
```

macOS：

```bash
flutter build macos --release
```

Linux：

```bash
flutter build linux --release
```

常见产物位置：

- Windows：`build/windows/<arch>/runner/Release/`
- macOS：`build/macos/Build/Products/Release/FlyNarwhal.app`
- Linux：`build/linux/<arch>/release/bundle/`
  
  

## 常见问题

#### 1. 此客户端播放视频是否支持硬解？

播放器基于 `media_kit` / libmpv，支持 GPU 加速能力，但最终效果取决于平台、驱动、视频格式以及系统环境。HDR、字幕、音轨切换等体验仍在持续优化，具体请以实际版本表现为准。

#### 2. 此客户端是否支持使用 FN ID 或者通过 NAS 登录？

支持，当前登录流程同时覆盖 FN ID 与 NAS 登录场景。

#### 3. 此客户端是否支持使用飞牛 OS 中的自签证书进行 HTTPS 连接？

目前不支持自签证书直连。如启用了 HTTPS，请使用受系统信任的证书。

#### 4. 此客户端是否支持直链播放？

除 `DolbyVision Profile 5` 之外格式的视频原画质下，默认使用直链播放，并支持在部分播放失败场景下回退到 HLS 。

## 🙏 特别感谢

本项目使用或参考以下开源项目：

- [Fluent UI](https://pub.dev/packages/fluent_ui) - 适用于 Flutter 的 Windows 风格 UI 组件库
- [media_kit](https://github.com/media-kit/media-kit) - Flutter 音视频播放方案
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) - 状态管理方案
- [go_router](https://pub.dev/packages/go_router) - Flutter 声明式路由
- [Dio](https://pub.dev/packages/dio) - 网络请求与拦截器能力
- [fntv-electron](https://github.com/QiaoKes/fntv-electron) - 飞牛影视 PC 版 Electron 封装
- [fnos-tv](https://github.com/thshu/fnos-tv) - 基于飞牛影视接口开发的网页端

感谢以下飞牛共建团队成员在内测期间提供了宝贵的技术支持和建议：

@[玉尺书生](https://club.fnnas.com/home.php?mod=space&uid=6482) @[MR_XIAOBO](https://github.com/xiaobonet) @[汪仔饭](https://club.fnnas.com/home.php?mod=space&uid=5021) @*观如

感谢 [anmoliyang](https://anmoli.cn) 为此项目 UI 设计做出的贡献

## 🌟 Star History

<a href="https://www.star-history.com/?repos=FNOSP%2FFlyNarwhal&type=date&legend=top-left" target="_blank" style="display: block" align="center">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=FNOSP/FlyNarwhal&type=date&theme=dark&legend=top-left&sealed_token=9G01Yt_j5R983IXSGvq4W9bbVH931sHfjzBZiMOVUS1dhtJ-Cmh3uxXe2CB2rpWFetma17Upq0-SxGbqlPcmrH2z5udzZnNbJ3P0M8FyHwk-7LGjEi6DPQ" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=FNOSP/FlyNarwhal&type=date&legend=top-left&sealed_token=9G01Yt_j5R983IXSGvq4W9bbVH931sHfjzBZiMOVUS1dhtJ-Cmh3uxXe2CB2rpWFetma17Upq0-SxGbqlPcmrH2z5udzZnNbJ3P0M8FyHwk-7LGjEi6DPQ" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=FNOSP/FlyNarwhal&type=date&legend=top-left&sealed_token=9G01Yt_j5R983IXSGvq4W9bbVH931sHfjzBZiMOVUS1dhtJ-Cmh3uxXe2CB2rpWFetma17Upq0-SxGbqlPcmrH2z5udzZnNbJ3P0M8FyHwk-7LGjEi6DPQ" />
 </picture>
</a>


<a href="#readme">
    <img src="https://img.shields.io/badge/-返回顶部-7d09f1.svg" alt="#" align="right">
</a>
