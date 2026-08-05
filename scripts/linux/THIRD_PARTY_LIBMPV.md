# 随 Linux 应用分发的第三方媒体运行库 — 许可证声明

Linux 发布包通过 `scripts/linux/bundle_full_libmpv.dart` 把系统安装的完整 libmpv
及其依赖闭包(FFmpeg、libass 等)拷入应用 bundle 的 `lib/` 目录,使最终用户无需
另行安装 mpv 即可获得 PGS/HDMV SUP 位图字幕解码能力。

这些库来自 Ubuntu 24.04 (Noble) 的发行版包,并非随源码重新编译,因此沿用发行版
提供的二进制与许可证。各组件名称、提供方与许可证如下:

| 组件 | 系统包 | 许可证 |
| --- | --- | --- |
| libmpv (libmpv.so.2) | `libmpv2` | LGPL-2.1-or-later (mpv 按 lgpl 构建) |
| FFmpeg (libavcodec/libavformat/libavfilter/libavutil/libswscale/libswresample) | `libavcodec*` / `libavformat*` 等 | LGPL-2.1-or-later |
| libass (Ass) | `libass9` | ISC |
| FreeType | `libfreetype6` | FreeType License (BSD-style) |
| Fribidi | `libfribidi0` | LGPL-2.1-or-later |
| HarfBuzz | `libharfbuzz0b` | MIT (Old HarfBuzz License) |
| libxml2 | `libxml2` | MIT |
| libpng | `libpng16-16` | libpng License (BSD-style) |
| Mbed TLS | `libmbedtls14` / `libmbedcrypto7` / `libmbedx509-1` | Apache-2.0 |
| Uchardet | `libuchardet0` | MPL-1.1 / LGPL-2.1-or-later (双许可) |

发布流程说明:
- 每个架构 runner (x86_64 / arm64) 从各自的 Ubuntu 仓库安装 `mpv libmpv-dev`,
  构建时由 `scripts/linux/bundle_full_libmpv.dart` 解析依赖闭包并拷入 bundle。
- 构建步骤会断言目标 mpv/FFmpeg 暴露 `hdmv_pgs_subtitle` 解码器
  (见 `.github/workflows/build-desktop.yml` 的 "Set up C toolchain (Linux)")。
- 二进制不提交到 Git,由各架构 CI runner 从固定发行版源组装,因此各架构产物
  的库版本以该 runner 当时的 Ubuntu 仓库为准。

如需随包附带原始许可证文本,可任选其一:
- 让 `bundle_full_libmpv.dart` 从 `/usr/share/doc/<pkg>/copyright` 收集并放入
  bundle 的 `licenses/` 目录;或
- 在发布仓库中维护上述组件的许可证全文副本。
默认实现未自动收集,若需分发合规的完整许可证文本,请启用上述收集逻辑。