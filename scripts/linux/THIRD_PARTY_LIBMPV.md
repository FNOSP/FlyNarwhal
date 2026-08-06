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

## 本地开发无 libmpv-dev 时的下载路径

Debug / Profile / `flutter run` 等场景下,`linux/CMakeLists.txt` 的 POST_BUILD 钩子
会调用 `linux/cmake/ensure_full_libmpv.cmake`,后者运行
`scripts/linux/fetch_full_libmpv.dart` 从 Ubuntu 24.04 apt pool 拉取与 CI runner
相同的包集合(含 `libmpv2 0.37.0-1ubuntu4` + FFmpeg 6.1 + libass + libplacebo 等共
20 个 .deb),抽取到 `build/linux/libmpv_cache/<arch>/root/`,再由
`bundle_full_libmpv.dart` 通过 `LIBMPV_EXTRA_SEARCH_ROOTS` 环境变量把它当作
额外的依赖查找根。

- amd64 文件来自 `http://archive.ubuntu.com/ubuntu/pool/...`
- arm64 文件来自 `http://ports.ubuntu.com/ubuntu-ports/pool/...`
- 镜像 fallback: `https://launchpad.net/ubuntu/+archive/primary/...`
- 每个 .deb 在 `scripts/linux/fetch_full_libmpv.dart` 的 `_kPackages` /
  `_kArm64Packages` 表里硬编码 SHA256,下载后逐个校验。
- 缓存目录 `build/linux/libmpv_cache/<arch>/` 在 `flutter clean` 时会随
  `build/` 一起被清,首次运行需重新下载约 30 MB。

升级步骤 (Ubuntu SRU / Noble minor bump 时):
1. 在 Ubuntu Noble pool (或 noble-updates) 的 Packages 索引里重新查询
   `libmpv2` 及所有闭包包名对应的 `Filename:` + `SHA256:`。
2. 把新值填到 `scripts/linux/fetch_full_libmpv.dart` 的两个表 (amd64 / arm64)
   里,顺序保持不变。
3. 跑一次 `flutter build linux --debug`,确认 `build/linux/x64/debug/bundle/lib/`
   下的 `libmpv.so.2` 仍能 `ldd` 且无 `not found`。
4. 若有 `ldd not found`,说明闭包缺包,补一行到表里再重试。

关闭下载 (使用系统 libmpv 即满足需求时):
- 临时: `flutter config --build-args=--FLY_NARWHAL_FETCH_FULL_LIBMPV=OFF` (然后
  触发一次 `flutter clean` 重新生成 CMake 缓存,让 option 生效)。
- 一次性: `cd build/linux/x64 && cmake -DFLY_NARWHAL_FETCH_FULL_LIBMPV=OFF .`
  然后再 `cmake --build .`。

如需随包附带原始许可证文本,可任选其一:
- 让 `bundle_full_libmpv.dart` 从 `/usr/share/doc/<pkg>/copyright` 收集并放入
  bundle 的 `licenses/` 目录;或
- 在发布仓库中维护上述组件的许可证全文副本。
默认实现未自动收集,若需分发合规的完整许可证文本,请启用上述收集逻辑。