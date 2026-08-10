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

## 使用说明

### 使用安装包安装

前往 [Releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载对应平台的安装包或发行产物。

#### macOS 安装被系统阻止的处理

从网上下载的安装包首次启动时，macOS 可能会弹出“已阻止打开”的提示。这是因为系统给下载的文件打上了隔离标记，属于正常的系统安全机制。

如果你已经开启了“系统设置 → 隐私与安全性”中的“任何来源”仍无法解决，可以通过手动移除隔离标记来处理。将 FlyNarwhal.app 拖入“应用程序”后，在终端执行：

```bash
xattr -dr com.apple.quarantine /Applications/FlyNarwhal.app
```

注意事项：

- 请在 app 已放入 `/Applications` **之后**再执行。
- 每次重新下载安装包并重装后，都需要重新执行一次（新拷贝的 app 会带上新的隔离标记）。
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
