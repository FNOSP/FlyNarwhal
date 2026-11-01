---
name: release-publishing
description: Use when publishing a new release of FlyNarwhal desktop. Covers version bump, CHANGELOG editing, user confirmation, commit, tag, and push to trigger the release workflow.
license: MIT
metadata:
  version: "1.0.0"
  domain: release
  triggers: release, publish, version bump, CHANGELOG, tag, pubspec, alpha, beta, stable
  role: specialist
  scope: workflow
  output-format: steps
  related-skills: github-workflow-automation
---

# FlyNarwhal 桌面端发布流程

本 skill 定义 FlyNarwhal Flutter 桌面端从准备到推送 tag 的完整发布流程。需要发布新版本时必须遵循。

## When to Use This Skill

- 用户要求发布新版本（如“发布 2.1.1-beta”）
- 需要整理 `Unreleased` 变更到正式版本节
- 需要打 tag 触发 GitHub release workflow

## 发布前准备

1. **确认发布渠道与版本号**
   - 语义化版本：`MAJOR.MINOR.PATCH[-prerelease]`
   - 常见后缀：`alpha`、`beta`（首字母可大写，如 `Alpha`、`Beta`，但仓库惯例为 `-alpha` / `-beta` 小写)
   - 当前 `pubspec.yaml` 版本必须与目标版本一致

2. **检查自上次发布以来的提交**
   - 使用 `git log --oneline v<last-version>..HEAD` 列出待发布提交
   - **先按功能分组**：把围绕同一功能/页面的多个 commit（新增 + 后续修复/优化）视为一件事，再按 `Added / Changed / Fixed` 分类到 `CHANGELOG.md`
   - 撰写时遵循下文「面向用户的写作规范」，禁止照搬 commit message

## 发布步骤

### 1. 更新 `pubspec.yaml`

```yaml
version: 2.1.1-beta
```

- 版本号必须与 tag 去掉前导 `v` 后完全一致
- 发布构建脚本 `scripts/release/build_desktop.dart` 会从 `pubspec.yaml` 读取 `_packageVersion()`，并注入 `--dart-define=APP_FULL_VERSION=${_packageVersion()}`
- GitHub Actions workflow 也会在 tag push 后读取 `pubspec.yaml` 生成安装包文件名

### 2. 更新 `CHANGELOG.md`

将 `## [Unreleased]` 下的内容整理为新的版本节，并清空 `Unreleased` 的 `Added / Changed / Fixed`：

```markdown
## [Unreleased]

### Added

### Changed

### Fixed

## [2.1.1-beta] - 2026-08-16

> 💡 **如遇自动更新失败，请访问 [https://github.com/FNOSP/FlyNarwhal/releases](https://github.com/FNOSP/FlyNarwhal/releases) 下载最新安装包后手动更新。**

### Added

- ...

### Changed

- ...

### Fixed

- ...
```

#### 面向用户的写作规范（必须遵循）

更新日志的读者是普通用户，不是开发者。整理 `git log` 提交时**不得**照搬 commit message，必须按下述规则重写：

1. **以结果为导向，禁止技术名词堆砌**
   - 描述用户能感知到的变化，而不是实现手段或解决过程
   - 句式模板：
     - 新增：`新增xxx功能`
     - 修复：`解决了xxx问题` / `修复了xxx时xxx的问题`
     - 优化：`优化了xxx的体验`
     - 平台：`新增支持xxx平台/架构安装包`
   - ✅ `新增支持跳过片头片尾设置，可自定义跳过时长`
   - ❌ `调整 skip config 的存储 key 为 parent_guid 并修复 setConfigByItem 传参错误`
   - ❌ `重构 DetailTags 组件，type=='Episode' 时隐藏演职人员`
   - 常见需要转写的技术词：组件名、路由路径、字段名、缓存策略、协议名（HTTP/WebSocket/QUIC）、构建/打包细节、第三方库名。这些一律翻译成用户视角的功能描述；若无法翻译（用户完全无感知，如纯内部重构、CI 脚本修复），则**不写入** CHANGELOG。

2. **同一版本内相同功能只总结为一件事**
   - 一个版本中若干 commit 围绕同一功能（如先新增功能，后续 commit 修复其 bug、优化其体验），**合并为一条**，通常写成"新增xxx功能"即可
   - ❌ 既写 `新增弹幕显示功能` 又写 `修复了弹幕在视频未播放时提前显示的问题`
   - ❌ 既写 `优化了选集卡片交互` 又写 `修复了点击选集卡片空白区域无响应的问题`
   - ✅ 只写 `新增xxx功能`（其间的修复/优化已被该条覆盖）
   - 判断标准：两条描述是否指向用户眼中的同一个功能点？是则合并。分组时以**功能/页面/用户场景**为单位，而不是以 commit 为单位。
   - 只有当修复的问题与该功能的新增无关、且用户会独立感知到时（如修复了上个版本遗留的老问题），才单独成条。

3. **合并后的条目归类**
   - 同一功能"新增 + 后续修复/优化"合并后归入 `Added`
   - `Fixed` 只放针对**已有功能**的独立问题修复
   - 新增类一律进 `Added`（包括新设置项、新开关），不要因为"改成了别的控件样式"就放进 `Changed`；只有对既有功能/既有行为的调整才进 `Changed`
   - `Added` 中的新增功能即使带修饰说明（如"来自系统语言""需要服务端 x.y.z"），也用"新增…"起句

4. **条目格式**
   - 统一格式：`- **简短名词短语**：一句话说明。`
     - 加粗标签是**功能/对象名**（`界面字号调节`、`清空图片缓存`、`Windows 播放器`、`起播`），不是动词短语
     - 正文以句式模板开头：新增→`新增…`，修复→`修复了…`。避免"支持xxx"作正文开头、避免"**支持xxx输出设备**：新增…"这种标签与正文重复
     - ❌ `- **支持切换音频输出设备**：新增音频直通、音频输出设备切换和播放信息面板样式切换。`
     - ✅ `- **界面字号调节**：新增界面字号调节。`
   - **一条只说一件事**。标题已点名的对象（如"播放器""跳片头片尾"）能被多类改动共享时，标题取改动本身的主体（`起播`、`提示`），而不是把"起播与提示"这类多个不相干场景拼进同一个加粗标签
   - 同一功能的多个细节可留在一个加粗标签的正文里（如"多语言界面"里写切换入口与跟随系统语言）；但**用户能感知到的不同功能点各自成条**——例如"界面字号调节"与"清空图片缓存"都是设置项，仍需拆成两条

5. **只写用户可感知的结果，且要写准**
   - 内部副作用（日志刷警告、请求被重复取消、缓存策略）默认**不写入**；只有用户自己能看到的日志窗口异常才写，并写明"控制台反复输出…警告"这类具体现象，不要写成"重复弹出取消提示"这种会被误读成 UI 弹窗的说法
   - 描述现象要具体到用户看到的画面，例如"从上次播放位置继续观看时画面会先闪回片头一小段"，而不是泛泛的"画面先闪一下"
   - 写之前先 `git show <commit>` 核对真实行为，推断不出来就别写

#### 各渠道 CHANGELOG 规范

| 渠道 | 警告块 | 手动下载提示 | 说明 |
|------|--------|--------------|------|
| `alpha` | 必须包含“⚠️ 此版本为测试版本（Alpha），仅供内部验证，禁止下载安装使用。” | 保留 | Alpha 仅内部验证 |
| `beta` | **不要**加内部验证警告 | 保留 | Beta 面向外部用户，但仍可提示手动下载 |
| `stable` | 不要加 | 可选 | 正式版 |

> ⚠️ 重要：只有 **Alpha** 版本添加“仅供内部验证”警告块。**Beta / Stable** 不要添加该警告。

### 3. 用户确认（必须）

在改完版本号和 CHANGELOG 后、提交推送前，**必须**向用户展示变更摘要并询问：

- 是否确认推送当前分支？
- 是否确认创建 tag `v<version>`？
- 是否还需要修改版本号或 CHANGELOG？

**不得**在未确认的情况下直接 `git push` 或 `git push origin --tags`。

### 4. 提交、推送、打 tag

用户确认后执行：

```bash
# 1. 提交版本与 changelog
git add pubspec.yaml CHANGELOG.md
git commit -m "release: bump version to <version>"

# 2. 推送当前分支
git push origin <current-branch>

# 3. 创建并推送 tag
git tag v<version>
git push origin v<version>
```

注意：

- tag 必须以 `v` 开头，例如 `v2.1.1-beta`
- tag 去掉 `v` 后必须严格等于 `pubspec.yaml` 版本号
- 提交信息末尾需追加：
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  ```

## 触发后的行为

- GitHub Actions `.github/workflows/build-desktop.yml` 在 `push tags: 'v*'` 时触发
- workflow 会构建 Windows / macOS / Linux 的 x64 与 arm64 安装包
- `release` job 会读取 `CHANGELOG.md` 中对应 tag 的节作为 release body，并自动上传到 GitHub Release
- 如果 `pubspec.yaml` 版本与 tag 不一致，`build_desktop.dart` 中的 `_validateGitHubTagVersion` 会导致构建失败

## 常见注意事项

1. **预发布资产文件名后缀**
   - 安装包名必须带完整版本后缀（如 `-beta`），以便应用内更新器匹配
   - 该逻辑由 `build_desktop.dart` 的 `_packageVersion()` 保证

2. **RPM 包版本处理**
   - RPM 版本字段不支持 `-`，预发布后缀会被拆入 `Release/iteration` 字段
   - 但发布文件名仍保留完整版本

3. **不要手动编辑 `.github/workflows/build-desktop.yml` 中的矩阵**
   - 除非明确需要新增/删除构建目标

4. **CHANGELOG 节标题日期**
   - 使用发布当天日期，格式 `YYYY-MM-DD`

## 反模式（禁止）

- ❌ 未询问用户直接推送 tag
- ❌ 版本号与 tag 不一致
- ❌ Beta / Stable 版本复制 Alpha 警告块
- ❌ 遗漏 `pubspec.yaml` 或 `CHANGELOG.md` 的同步更新
- ❌ 使用 `git push --tags` 一次性推送所有本地 tag（可能误推旧 tag）
- ❌ CHANGELOG 照搬 commit message 或堆砌技术名词（组件名、字段名、路由、库名等）
- ❌ 同一功能的"新增 + 修复 + 优化"拆成多条重复描述（应合并为一条"新增xxx功能"）
- ❌ 加粗标签写成动词短语（`**支持xxx**`），或标签与正文重复，导致句子读起来像"支持…：新增…"
- ❌ 把多个不相干场景拼成一个标签（`**起播与提示**`），或用"一条"塞进两个独立功能点
- ❌ 写"重复弹出取消提示""画面先闪一下"这类未经核实的模糊描述——先 `git show` 看真实行为，写不准就别写
- ❌ 把新增的设置项/开关放进 `Changed`

## 快速检查清单

- [ ] 已确认目标版本号与渠道
- [ ] `pubspec.yaml` 已更新
- [ ] `CHANGELOG.md` 已新增对应版本节，`Unreleased` 已清空
- [ ] CHANGELOG 条目面向普通用户：加粗标签为名词短语、正文统一"新增…/修复了…"句式
- [ ] 新增的设置项/开关已归入 `Added`；独立的功能点已各自成条，未拼进一个标签
- [ ] 每条均经 `git show` 核实，未写未经证实的现象或内部副作用
- [ ] 渠道警告块符合规范（Alpha 有，Beta/Stable 无）
- [ ] 已展示变更摘要并获得用户确认
- [ ] 已提交、推送分支
- [ ] 已创建并推送 tag `v<version>`
