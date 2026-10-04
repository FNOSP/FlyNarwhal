// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '飞鲸影视';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionAccount => '账号';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsLanguageCaption => '选择应用界面的显示语言';

  @override
  String get settingsSectionServer => '服务器';

  @override
  String get settingsSectionPrivacy => '隐私与安全';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsAccountUnloaded => '未加载用户信息';

  @override
  String get settingsAccountUnloadedCaption => '登录后将在首页自动完成用户信息校验';

  @override
  String get settingsAccountAdminBadge => '管理员';

  @override
  String get settingsAccountSignOut => '退出登录';

  @override
  String get settingsAccountSignOutCaption => '退出当前账号';

  @override
  String get settingsAccountSignOutConfirm => '确认退出当前帐号？';

  @override
  String get settingsAppearanceThemeMode => '主题模式';

  @override
  String get settingsAppearanceThemeModeCaption => '是否跟随系统主题';

  @override
  String get settingsAppearanceFollowSystem => '跟随系统';

  @override
  String get settingsAppearanceManual => '手动设置';

  @override
  String get settingsAppearanceColor => '颜色';

  @override
  String get settingsAppearanceColorCaption => '请选择主题颜色';

  @override
  String get settingsAppearanceDark => '深色';

  @override
  String get settingsAppearanceLight => '浅色';

  @override
  String get settingsAppearanceNavStyle => '导航栏样式';

  @override
  String get settingsAppearanceNavStyleCaption => '请选择导航视图布局';

  @override
  String get settingsAppearanceDetailsLiquidGlass => '播放详细信息面板启用液态玻璃效果';

  @override
  String get settingsAppearanceDetailsLiquidGlassCaption =>
      '开启后播放详细信息面板使用带动画的液态玻璃样式，关闭则使用静态毛玻璃样式';

  @override
  String get settingsGeneralFontSize => '字体大小';

  @override
  String get settingsGeneralFontSizeCaption => '调整应用整体文字大小';

  @override
  String get settingsGeneralShortcuts => '快捷键设置';

  @override
  String get settingsGeneralShortcutsCaption => '自定义快捷键';

  @override
  String get settingsGeneralCustomize => '自定义';

  @override
  String get settingsServerEnable => '启用飞鲸服务端';

  @override
  String get settingsServerEnableCaption => '启用后可连接飞鲸服务端实现智能识别片头/片尾、弹幕等功能支持';

  @override
  String get settingsServerAddress => '飞鲸服务端地址';

  @override
  String get settingsServerAddressHttpsRequired => '必须使用 HTTPS 地址';

  @override
  String get settingsServerAddressIncomplete => '请填写完整的服务端 URL';

  @override
  String get settingsServerAuthCode => '授权码';

  @override
  String get settingsServerAuthCodePlaceholder => '填写授权码';

  @override
  String get settingsServerAuthCodeFilled => '已填写飞鲸服务端授权码';

  @override
  String get settingsServerAuthCodePrompt => '填写飞鲸服务端授权码';

  @override
  String get settingsServerAuthCodeLabel => '请输入飞鲸服务端授权码：';

  @override
  String get settingsServerAuthCodeHint => '请在飞鲸服务端页面点击“获取授权码”后粘贴到此处。';

  @override
  String get settingsServerAuthCodeHelp =>
      '请在浏览器中访问部署在 NAS 中的飞鲸服务端地址（应用中心版请点击飞牛 OS 桌面中的「飞鲸影视」），点击右上角的「获取授权码」按钮，复制授权码后粘贴到填写授权码的文本框中。\\n需要服务端版本 >= 0.6.0，低于 0.6.0 版的服务端不支持自动更新到 0.6.0 或以上版本，请手动更新到 0.6.0 或以上版本';

  @override
  String get settingsServerTest => '测试';

  @override
  String get settingsServerTesting => '测试中';

  @override
  String settingsServerTestSuccess(String version) {
    return '飞鲸服务端连接成功，当前服务端版本号：$version';
  }

  @override
  String settingsServerTestConnectFailed(String error) {
    return '飞鲸服务端连接失败：$error';
  }

  @override
  String get settingsServerUnreachable => '飞鲸服务端无法访问';

  @override
  String get settingsPrivacySslTitle => 'SSL 证书信任列表';

  @override
  String get settingsPrivacySslCaption => '服务器证书校验失败时可加入信任，在此管理';

  @override
  String settingsPrivacySslTrustedCount(String count) {
    return '已信任 $count 张证书';
  }

  @override
  String get settingsPrivacyManage => '管理';

  @override
  String get settingsPrivacyStatement => '隐私声明';

  @override
  String get settingsPrivacyStatementBody =>
      '为了改进软件性能，我们会收集部分硬件信息（如 CPU、GPU 型号等）作为参考依据。这些信息将仅用于优化软件，不会涉及个人隐私。';

  @override
  String get settingsPrivacyGitHubProxy => 'GitHub 资源代理';

  @override
  String get settingsPrivacyGitHubProxyCaption => '仅用于安装包下载';

  @override
  String get settingsPrivacyProxyAddress => '代理地址';

  @override
  String get settingsAboutVersion => '当前版本';

  @override
  String get settingsAboutCheckUpdate => '检查更新';

  @override
  String get settingsAboutChangelog => '更新日志';

  @override
  String get settingsAboutChangelogCaption => '查看各版本的更新内容';

  @override
  String get settingsAboutPrerelease => '接收预发布版本更新';

  @override
  String get settingsAboutPrereleaseEarly => '抢先体验';

  @override
  String get settingsAboutAutoDownload => '自动下载更新';

  @override
  String get settingsAboutAutoDownloadCaption => '发现更新后在后台下载并校验安装包';

  @override
  String get settingsAboutOpen => '开启';

  @override
  String get settingsAboutClose => '关闭';

  @override
  String get settingsAboutExportLogs => '导出报错日志';

  @override
  String get settingsAboutExportLogsCaption => '支持导出近三天的报错日志，方便开发者排查问题';

  @override
  String get settingsAboutExport => '导出';

  @override
  String get settingsAboutExportError => '导出错误';

  @override
  String get settingsAboutVersionLoading => '正在读取版本信息…';

  @override
  String get settingsAboutVersionUnavailable => '无法读取版本信息';

  @override
  String get commonLoading => '加载中';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonCancel => '取消';

  @override
  String get commonGotIt => '我知道了';

  @override
  String get commonUserInfoLoadFailed => '加载用户信息失败';

  @override
  String get commonUserInfoLoading => '正在加载用户信息…';

  @override
  String get shortcutsTitle => '快捷键设置';

  @override
  String get shortcutsTabKeyboard => '快捷键';

  @override
  String get shortcutsTabPlayback => '播放';

  @override
  String get shortcutsTabHelp => '说明';

  @override
  String get shortcutsRestoreDefaults => '恢复默认';

  @override
  String get shortcutsSearch => '搜索';

  @override
  String get shortcutsPrompt => '请在键盘按下快捷键或组合';

  @override
  String get sslTrustedTitle => 'SSL 证书信任列表';

  @override
  String get sslTrustedEmpty => '暂无信任的证书。当服务器证书校验失败时，可以在提示中选择「信任此证书」。';

  @override
  String sslTrustedAddedAt(String time) {
    return '添加时间：$time';
  }

  @override
  String get sslTrustedRemove => '移除';

  @override
  String get sslTrustedRemoveAll => '全部清除';

  @override
  String get sslTrustedRemoveTitle => '移除信任的证书';

  @override
  String sslTrustedRemoveBody(String host) {
    return '移除后，再次访问「$host」时该证书会重新校验。';
  }

  @override
  String get sslTrustedClearTitle => '清除全部信任的证书';

  @override
  String get sslTrustedClearBody => '清除后，所有服务器的证书都会重新校验。';

  @override
  String get supportAuthorTitle => '支持作者';

  @override
  String get supportAuthorBody =>
      '您的支持就是我持续更新的动力，如果觉得好用的话，请给项目点一个 Star ⭐，谢谢！(^_−)☆';

  @override
  String get supportAuthorIssues =>
      '项目诚然还有很多地方需要完善，如果遇到软件问题或者 Bug 欢迎提交 Issue 或者 PR。';

  @override
  String get supportAuthorOpenRepo => '打开 Github 仓库';

  @override
  String get supportAuthorLater => '稍后再说';

  @override
  String get fontScaleSmall => '小';

  @override
  String get fontScaleMedium => '中';

  @override
  String get fontScaleLarge => '大';

  @override
  String get filterTitle => '筛选';

  @override
  String get filterReset => '重置';

  @override
  String get filterCollapse => '收起';

  @override
  String get filterOptionAll => '全部';

  @override
  String get filterOptionMovie => '电影';

  @override
  String get filterOptionTv => '电视剧';

  @override
  String get filterOptionWatched => '已观看';

  @override
  String get filterOptionUnwatched => '未观看';

  @override
  String get filterOptionMatched => '已匹配';

  @override
  String get filterOptionUnmatched => '未匹配';

  @override
  String get filterOptionNfoMatched => 'NFO匹配';

  @override
  String get filterOptionOthers => '其他';

  @override
  String get filterOptionThisYear => '今年';

  @override
  String filterOptionDecade(String decade) {
    return '$decade年代';
  }

  @override
  String get filterOptionDolbyVision => '杜比视界';

  @override
  String get filterOptionDolbySurround => '杜比环绕';

  @override
  String get filterOptionDolbyAtmos => '杜比全景声';

  @override
  String get filterOptionStereo => '立体声';

  @override
  String get filterRowMediaType => '影视类型';

  @override
  String get filterRowGenre => '类型';

  @override
  String get filterRowResolution => '分辨率';

  @override
  String get filterRowColorRange => '视频动态范围';

  @override
  String get filterRowAudioType => '音频规格';

  @override
  String get filterRowLocation => '国家和地区';

  @override
  String get filterRowDecade => '发行年份';

  @override
  String get filterRowRecognitionStatus => '匹配状态';

  @override
  String get filterRowWatched => '是否已观看';

  @override
  String get mediaInfoTitle => '文件媒体信息';

  @override
  String get mediaInfoEmpty => '暂无数据';

  @override
  String get mediaInfoSectionVideo => '视频';

  @override
  String get mediaInfoSectionAudio => '音频';

  @override
  String get mediaInfoSectionSubtitle => '字幕';

  @override
  String get mediaInfoFieldResolution => '分辨率';

  @override
  String get mediaInfoFieldDynamicRange => '视频动态范围';

  @override
  String get mediaInfoFieldCodec => '编码器';

  @override
  String get mediaInfoFieldProfile => '配置';

  @override
  String get mediaInfoFieldLevel => '等级';

  @override
  String get mediaInfoFieldFrameRate => '帧率';

  @override
  String get mediaInfoFieldBitRate => '码率';

  @override
  String get mediaInfoFieldAspectRatio => '宽高比';

  @override
  String get mediaInfoFieldPixelFormat => '像素格式';

  @override
  String get mediaInfoFieldBitDepth => '位深度';

  @override
  String get mediaInfoFieldColorSpace => '色彩空间';

  @override
  String get mediaInfoFieldColorPrimaries => '色彩原色';

  @override
  String get mediaInfoFieldColorTransfer => '色彩转换';

  @override
  String get mediaInfoFieldReferenceFrames => '参考帧';

  @override
  String get mediaInfoFieldInterlaced => '隔行扫描';

  @override
  String get mediaInfoFieldLayout => '布局';

  @override
  String get mediaInfoFieldChannels => '声道';

  @override
  String get mediaInfoFieldSampleRate => '采样率';

  @override
  String get mediaInfoFieldLanguage => '语言';

  @override
  String get mediaInfoFieldDefault => '默认';

  @override
  String get mediaInfoFieldForced => '强制';

  @override
  String get mediaInfoFieldExternal => '外部';

  @override
  String get mediaInfoYes => '是';

  @override
  String get mediaInfoNo => '否';

  @override
  String get subtitleUploadFileTypeName => '字幕文件';

  @override
  String get subtitleUploadSelect => '选择';

  @override
  String get subtitleUploadAdded => '添加字幕成功';

  @override
  String get subtitleUploadFailed => '添加字幕失败，请重试';

  @override
  String subtitleUploadPartial(String count) {
    return '部分字幕添加成功，其中 $count 个失败';
  }

  @override
  String subtitleUploadTooMany(String count) {
    return '最多选择 $count 个文件';
  }

  @override
  String get subtitleUploadMissingUser => '当前用户信息缺失，无法恢复文件选择器状态';

  @override
  String subtitleUploadPickerFailed(String error) {
    return '选择字幕文件失败: $error';
  }

  @override
  String subtitleUploadFormatSuffix(String formats) {
    return '$formats 格式的文件';
  }

  @override
  String get captionBack => '返回';

  @override
  String get captionRefresh => '刷新';

  @override
  String get captionToggleNav => '切换导航栏';

  @override
  String get captionAlwaysOnTop => '窗口置顶';

  @override
  String get captionUnpin => '取消置顶';

  @override
  String get toastInfo => '信息';

  @override
  String get toastSuccess => '成功';

  @override
  String get toastWarning => '警告';

  @override
  String get toastError => '错误';

  @override
  String get toastServerUrlRequired => '请填写飞鲸服务端 URL';

  @override
  String get toastServerAuthCodeRequired => '请填写飞鲸服务端授权码';

  @override
  String get toastServerCredentialsRequired => '请填写飞鲸服务端 URL 和授权码';

  @override
  String get sslPromptTitle => '证书校验失败';

  @override
  String sslPromptBody(String host) {
    return '「$host」的证书校验不通过，可能是证书过期、域名不匹配或自签名证书。';
  }

  @override
  String sslPromptFingerprint(String fingerprint) {
    return '证书指纹 SHA-256：$fingerprint';
  }

  @override
  String get sslPromptQuestion => '继续访问将绕过安全保护，是否继续访问？';

  @override
  String get sslPromptTrustPersistent => '信任此证书';

  @override
  String get sslPromptTrustOnce => '仅本次信任';

  @override
  String get sslPromptCancel => '取消访问';

  @override
  String get layoutTitle => '布局';

  @override
  String get layoutPosterWall => '海报墙';

  @override
  String get layoutVerticalPoster => '竖幅海报';

  @override
  String get layoutBannerPoster => '横幅海报';

  @override
  String get layoutList => '列表';

  @override
  String get castTitle => '演职人员';

  @override
  String get castRoleDirector => '导演';

  @override
  String get castRoleActor => '演员';

  @override
  String get castRoleWriter => '编剧';

  @override
  String get castRoleProducer => '制片人';

  @override
  String castCharacter(String role) {
    return '饰 $role';
  }

  @override
  String get sortTitle => '标题';

  @override
  String get sortAddedDate => '添加日期';

  @override
  String get sortReleaseYear => '发行年份';

  @override
  String get sortScore => '评分';

  @override
  String get sortAscending => '升序';

  @override
  String get sortDescending => '降序';

  @override
  String get nasSubtitleStorageLocation => '视频所在位置';

  @override
  String get nasSubtitleSelectStorage => '请选择存储空间';

  @override
  String nasSubtitleTooMany(String count) {
    return '最多选择 $count 个文件';
  }

  @override
  String get loadFailedTitle => '加载失败';

  @override
  String get loadFailedUnknown => '未知错误';

  @override
  String get loadFailedRetry => '重试';

  @override
  String get episodeViewCard => '切换为卡片视图';

  @override
  String get episodeViewButton => '切换为序号视图';

  @override
  String get nasBrowserEmpty => '空空如也';

  @override
  String get actionPlay => '播放';

  @override
  String get actionContinuePlay => '继续播放';

  @override
  String get actionFavoriteAdd => '加入收藏';

  @override
  String get actionFavoriteRemove => '取消收藏';

  @override
  String get actionMarkWatched => '标记为已看';

  @override
  String get actionMarkUnwatched => '标记为未看';

  @override
  String get actionMore => '更多操作';

  @override
  String get actionMore2 => '更多';

  @override
  String get toastFavoriteAdded => '已收藏';

  @override
  String get toastFavoriteRemoved => '已取消收藏';

  @override
  String get toastMarkedUnwatched => '标记为未观看';

  @override
  String get toastMarkedWatched => '标记为已观看';

  @override
  String get toastOperationFailed => '操作失败';

  @override
  String toastOperationFailedReason(String message) {
    return '操作失败，$message';
  }

  @override
  String get mediaInfoNoOverview => '暂无介绍';

  @override
  String get mediaInfoNoInfo => '暂无信息';

  @override
  String get mediaInfoNoContent => '无内容';

  @override
  String get mediaInfoFileInfo => '文件信息';

  @override
  String get mediaInfoFileLocation => '文件位置';

  @override
  String get mediaInfoFileSize => '文件大小';

  @override
  String get mediaInfoCreatedDate => '创建日期';

  @override
  String get mediaInfoAddedDate => '添加日期';

  @override
  String get mediaInfoStreamSection => '视频/音频信息';

  @override
  String get linkLabel => '链接:  ';

  @override
  String get imdbLinkLabel => 'IMDB链接';

  @override
  String defaultSuffix(String title) {
    return '$title - 默认';
  }

  @override
  String get actionViewAll => '查看全部';

  @override
  String get movieDetailNotFound => '未找到电影信息';

  @override
  String get movieDetailDescriptionTitle => '电影简介';

  @override
  String get movieDetailEpisodeDescriptionTitle => '剧集简介';

  @override
  String get movieDetailSubtitleAddTitle => '添加字幕';

  @override
  String get movieDetailSubtitleAlreadyAdded => '该文件已被添加为字幕';

  @override
  String get movieDetailSubtitleAddFailed => '添加字幕失败';

  @override
  String movieDetailSubtitleRetry(String error) {
    return '请稍后重试：$error';
  }

  @override
  String get movieDetailSubtitleSearchMissingFile => '当前文件信息缺失，无法搜索字幕';

  @override
  String get movieDetailSubtitleUploadMissingFile => '当前文件信息缺失，无法上传字幕';

  @override
  String get movieDetailSubtitleDownloadSuccess => '下载成功';

  @override
  String movieDetailSubtitleDownloadFailed(String error) {
    return '下载字幕失败: $error';
  }

  @override
  String get movieDetailSubtitleTaskCreated => '已创建字幕下载任务';

  @override
  String get movieDetailSubtitleTaskFailed => '创建字幕下载任务失败，请重试';

  @override
  String get movieDetailSubtitleExternalSuffix => ' - 外挂';

  @override
  String get movieDetailSubtitleDeleteTitle => '删除外挂字幕';

  @override
  String movieDetailSubtitleDeleteConfirm(String name) {
    return '确定要删除 $name 外挂字幕吗？';
  }

  @override
  String get movieDetailSubtitleDeleteSuccess => '删除字幕成功';

  @override
  String movieDetailSubtitleDeleteFailed(String error) {
    return '删除字幕失败: $error';
  }

  @override
  String get movieDetailSubtitleNone => '无字幕';

  @override
  String movieDetailSubtitleLanguageLabel(String language) {
    return '$language字幕';
  }

  @override
  String get movieDetailAudioLabel => '音频';

  @override
  String movieDetailAudioLanguageLabel(String language) {
    return '$language音频';
  }

  @override
  String get movieDetailAudioStereo => '立体声';

  @override
  String movieDetailRemaining(String time) {
    return '剩余 $time';
  }

  @override
  String movieDetailSmartAnalysisStatus(String status) {
    return '智能片头/片尾检测状态：$status';
  }

  @override
  String get movieDetailDolbyVision => '杜比视界';

  @override
  String get movieDetailSubtitleLabel => '字幕';

  @override
  String get tvDetailNotFound => '未找到剧集信息';

  @override
  String get tvDetailSeasonNotFound => '未找到分季信息';

  @override
  String get tvDetailDescriptionTitle => '剧集简介';

  @override
  String get tvDetailSmartAnalysis => '智能分析片头/片尾';

  @override
  String get tvDetailSeasonListTitle => '剧季列表';

  @override
  String tvDetailEpisodeNumber(String number) {
    return '第 $number 集';
  }

  @override
  String tvDetailSeasonNumber(String number) {
    return '第 $number 季';
  }

  @override
  String tvDetailSeasonEpisodeNumbers(String season, String episode) {
    return '第 $season 季 第 $episode 集';
  }

  @override
  String tvDetailEpisodeCount(String count) {
    return '共 $count 集';
  }

  @override
  String get tvDetailEpisodeSectionTitle => '选集';

  @override
  String get tvDetailUnknownSeason => '未知季';

  @override
  String tvDetailSeasonTitleSummary(String title, String count) {
    return '《$title》共 $count 季';
  }

  @override
  String get tvDetailEpisodeNoneOverview => '暂无剧集简介';

  @override
  String tvDetailEpisodeRuntime(String minutes) {
    return '$minutes 分钟';
  }

  @override
  String get tvDetailRuntimeUnknown => '时长未知';

  @override
  String tvDetailScore(String score) {
    return '$score 分';
  }

  @override
  String get tvDetailPlayEpisode => '播放本集';

  @override
  String tvDetailSmartAnalysisStatus(String status) {
    return '智能分析：$status';
  }

  @override
  String get tvDetailAnalysisFetching => '获取中';

  @override
  String get tvDetailAnalysisNotDetected => '未检测';

  @override
  String get tvDetailAnalysisFailed => '获取失败';

  @override
  String get tvDetailAnalysisPreparing => '准备中';

  @override
  String get tvDetailAnalysisPending => '等待中';

  @override
  String get tvDetailAnalysisInProgress => '分析中';

  @override
  String get tvDetailAnalysisPartialSuccess => '部分成功';

  @override
  String get tvDetailAnalysisCompleted => '已完成';

  @override
  String get tvDetailAnalysisStatusFailed => '失败';

  @override
  String get mediaTypeMovie => '电影';

  @override
  String get mediaTypeTv => '电视节目';

  @override
  String get mediaTypeDirectory => '目录';

  @override
  String get mediaTypeOther => '其他';

  @override
  String get mediaTypeLive => '电视直播';

  @override
  String get mediaTypeEpisode => '剧集';

  @override
  String get mediaTypeSeason => '季';

  @override
  String mediaSeasonCount(String count) {
    return '共 $count 季';
  }

  @override
  String mediaSeasonNumber(String number) {
    return '第 $number 季';
  }

  @override
  String mediaEpisodeCount(String count) {
    return '共 $count 集';
  }

  @override
  String mediaEpisodeDetail(String season, String episode) {
    return '第 $season 季 · 第 $episode 集';
  }

  @override
  String get cloudStorageBaiduPan => '百度网盘';

  @override
  String get cloudStorageAliyunDrive => '阿里云盘';

  @override
  String get cloudStorage115 => '115 生活';

  @override
  String get cloudStorageQuark => '夸克网盘';

  @override
  String get cloudStorage123 => '123 云盘';

  @override
  String get loginRememberPassword => '记住密码';

  @override
  String get loginWebViewInjectedPlaceholder => '登录页面';

  @override
  String get updateCurrentVersionLabel => '当前安装版本';

  @override
  String get updateManualDownloadOpenFailed => '无法打开手动下载页面，请稍后重试。';

  @override
  String get updateOpenLinkFailed => '无法打开链接，请稍后重试。';

  @override
  String updateBadgeSemanticLabel(String version) {
    return '发现新版本 $version，打开更新详情';
  }

  @override
  String get updateDialogTitleChecking => '检查更新';

  @override
  String get updateDialogTitleAvailable => '发现新版本';

  @override
  String get updateDialogTitleDownloading => '正在下载更新';

  @override
  String get updateDialogTitleDownloaded => '下载完成';

  @override
  String get updateDialogTitleVerifying => '正在校验更新';

  @override
  String get updateDialogTitleReadyToInstall => '更新已准备就绪';

  @override
  String get updateDialogTitleInstalling => '正在启动安装';

  @override
  String get updateDialogTitleCheckFailed => '检查更新失败';

  @override
  String get updateDialogTitleDownloadFailed => '下载更新失败';

  @override
  String get updateDialogTitleVerificationFailed => '更新包校验失败';

  @override
  String get updateDialogTitleInstallFailed => '启动安装失败';

  @override
  String get updateDialogTitleAutomaticDownloadExhausted => '自动下载未完成';

  @override
  String get updateDialogTitleNone => '应用更新';

  @override
  String get updateActionCheckInBackground => '后台检查';

  @override
  String get updateActionSkipVersion => '跳过此版本';

  @override
  String get updateActionLater => '稍后再说';

  @override
  String get updateActionDownload => '下载更新';

  @override
  String get updateActionDownloadInBackground => '后台下载';

  @override
  String get updateActionCancelDownload => '取消下载';

  @override
  String get updateActionInstallLater => '稍后安装';

  @override
  String get updateActionQuitAndInstall => '退出并安装';

  @override
  String get updateActionRunInBackground => '后台运行';

  @override
  String get updateActionRetryDownload => '重新下载';

  @override
  String get updateActionRetryInstall => '重试安装';

  @override
  String get updateActionManualDownload => '手动下载';

  @override
  String get updateActionClose => '关闭';

  @override
  String get updateStatusCheckingMessage => '正在从 GitHub Releases 获取更新信息…';

  @override
  String get updateStatusUpToDate => '当前已是最新版本。';

  @override
  String get updateStatusDownloadedMessage => '更新包已下载完成，可以稍后安装或立即退出并安装。';

  @override
  String get updateStatusReadyMessage => '已找到可用的已下载更新包。';

  @override
  String get updateStatusVerifyingMessage => '正在安全校验更新包，请稍候…';

  @override
  String get updateStatusInstallingMessage => '正在启动系统安装程序，请勿重复操作。';

  @override
  String get updateStatusIdleMessage => '尚未执行更新检查。';

  @override
  String updateVersionLine(String version, String current) {
    return '版本 $version（当前 $current）';
  }

  @override
  String updatePackageSize(String size) {
    return '安装包大小 $size';
  }

  @override
  String get updateReleaseNotesHeader => '更新内容';

  @override
  String get updateDownloadingPackage => '正在下载更新包';

  @override
  String updateDownloadedSize(String size) {
    return '已下载 $size';
  }

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateErrorRateLimited => 'GitHub 接口访问频率超限，通常稍后会自动恢复，请稍后再试。';

  @override
  String get updateErrorVerificationFailed => '更新包未通过安全校验，请重新下载。';

  @override
  String get updateErrorCheckFailed => '暂时无法获取更新信息，请检查网络后重试。';

  @override
  String get updateErrorDownloadFailed => '更新包下载未完成，请稍后重试。';

  @override
  String get updateErrorInstallFailed => '无法启动系统安装程序，请稍后重试。';

  @override
  String get updateErrorAutomaticDownloadExhausted =>
      '自动下载多次未完成，你可以稍后重试或前往发布页手动下载。';

  @override
  String get updateErrorGeneric => '更新操作未完成，请稍后重试。';

  @override
  String get updateMarkdownEmpty => '本次更新未提供更新说明';

  @override
  String get updateMarkdownRemoteImageAlt => '远程图片';

  @override
  String updateMarkdownRemoteImageBlocked(String alt) {
    return '远程图片已阻止：$alt';
  }

  @override
  String get updateMarkdownTruncatedSuffix => '\n\n更新说明过长，已截断显示。';

  @override
  String get loginHostOrFnIdPlaceholder => '请输入 IP:Port、域名或 FN ID';

  @override
  String get loginHostValidationMessage => '请输入正确的 IP、域名或 FN ID';

  @override
  String get loginHostRequiredMessage => '请输入 IP、域名或 FN ID';

  @override
  String get loginUsernameRequiredMessage => '请输入用户名';

  @override
  String get loginPasswordRequiredMessage => '请输入密码';

  @override
  String get loginWebViewInitFailed => '浏览器组件初始化失败，请稍后重试。';

  @override
  String get loginHostPlaceholder => '请输入 IP、域名或 FN ID';

  @override
  String get loginPortPlaceholder => '端口';

  @override
  String get loginUsernameLabel => '用户名';

  @override
  String get loginPasswordLabel => '密码';

  @override
  String get loginUseNasLogin => '使用 NAS 登录';

  @override
  String get loginHttpsSecureAccess => 'HTTPS 安全访问';

  @override
  String get loginNext => '下一步';

  @override
  String get loginSignIn => '登录';

  @override
  String get loginVerifyingServer => '正在验证服务器...';

  @override
  String get loginInvalidCredentials => '用户名或密码错误';

  @override
  String loginServerHttpError(String status) {
    return '服务器返回错误（HTTP $status），请检查服务状态。';
  }

  @override
  String get loginSslCertificateFailed => 'SSL 证书验证失败，请检查 HTTPS 设置或服务器证书。';

  @override
  String get loginConnectionTimeout => '连接服务器超时，请确认服务器地址或网络状态。';

  @override
  String get loginConnectionFailed => '无法连接到服务器，请检查地址、端口或网络。';

  @override
  String get loginRequestCancelled => '登录请求已取消。';

  @override
  String get loginFailedCheckServer => '登录失败，请检查服务器地址或稍后再试。';

  @override
  String get loginFailedCheckNetwork => '登录失败，请检查网络或服务器设置。';

  @override
  String get loginFailedTokenEmpty => '登录失败: Token 为空';

  @override
  String loginFailedWithError(String error) {
    return '登录失败: $error';
  }

  @override
  String get loginAuthFailed => '认证失败';

  @override
  String get loginAccessCodeInvalid => '访问码错误';

  @override
  String get loginAccessCodeTitle => '请输入访问码';

  @override
  String get loginAccessCodeHint => '该服务器启用了访问码，请输入后继续。';

  @override
  String get loginFnIdEmpty => 'FN ID 不能为空';

  @override
  String get loginHistoryTitle => '登录历史';

  @override
  String get loginHistoryEmpty => '暂无历史记录';

  @override
  String get homeRetryLoad => '加载失败，点击重试';

  @override
  String get homeTitle => '首页';

  @override
  String get homeContinueWatching => '继续观看';

  @override
  String get homeMediaLibrary => '媒体库';

  @override
  String get homeContinueRemoved => '已从“继续观看”中移除';

  @override
  String get homeContinueRemoveFailed => '移除失败';

  @override
  String homeContinueRemoveError(String error) {
    return '移除失败：$error';
  }

  @override
  String homeDeleteDialogTitle(String title) {
    return '删除 《$title》';
  }

  @override
  String get homeDeleteDialogBody =>
      '从媒体库移除后，所选视频文件将不再被扫描添加到当前媒体库中。请确认是否同时删除关联的视频文件。';

  @override
  String get homeDeleteRemoveAndDeleteFile => '移除并删除文件';

  @override
  String get homeDeleteRemoveOnly => '仅移除';

  @override
  String get homeDeleted => '已删除';

  @override
  String get homeDeleteFailed => '删除失败';

  @override
  String homeDeleteFailedWithError(String error) {
    return '删除失败：$error';
  }

  @override
  String get homeFavoriteRemoved => '已取消收藏';

  @override
  String get homeFavorited => '已收藏';

  @override
  String get homeMarkedUnwatched => '标记为未观看';

  @override
  String get homeMarkedWatched => '标记为已观看';

  @override
  String get homeActionFailed => '操作失败';

  @override
  String homeActionFailedWithError(String error) {
    return '操作失败，$error';
  }

  @override
  String get homeMenuRemoveFromContinue => '从“继续观看”中移除';

  @override
  String get homeMenuResume => '继续播放';

  @override
  String get homeMenuRestart => '从头开始播放';

  @override
  String get homeMenuDeleteVideo => '删除视频';

  @override
  String get searchPlaceholder => '搜索片名、演员';

  @override
  String get searchTabAll => '全部';

  @override
  String get searchTabMovie => '电影';

  @override
  String get searchTabTv => '电视剧';

  @override
  String get searchTabLiveChannel => '电视直播';

  @override
  String get searchTabPerson => '人物';

  @override
  String get searchTabOther => '其他';

  @override
  String get searchNoResults => '搜索无结果';

  @override
  String get searchEnterKeyword => '输入关键词搜索';

  @override
  String searchWorkCount(String count) {
    return '$count 个作品';
  }

  @override
  String get searchScoreSuffix => '分';

  @override
  String searchEpisodeCount(String count) {
    return '共 $count 集';
  }

  @override
  String get personNoData => '无数据';

  @override
  String get personSectionActor => '作为演员';

  @override
  String get personSectionDirector => '作为导演';

  @override
  String get personSectionWriter => '作为编剧';

  @override
  String get personMore => '更多';

  @override
  String get personBiographyTitle => '演员简介';

  @override
  String get commonDelete => '删除';

  @override
  String get forgotPasswordTitle => '忘记密码？';

  @override
  String get storageExternal => '外接存储';

  @override
  String get storageRemoteMount => '远程挂载';

  @override
  String storageVolumeName(String number) {
    return '存储空间 $number';
  }

  @override
  String durationHoursMinutes(String hours, String minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String durationHours(String hours) {
    return '$hours 小时';
  }

  @override
  String durationMinutesSeconds(String minutes, String seconds) {
    return '$minutes 分钟 $seconds 秒';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes 分钟';
  }

  @override
  String get durationZeroMinutes => '0 分钟';

  @override
  String authDirUserFiles(String username) {
    return '$username 的文件';
  }

  @override
  String authDirUnknownUser(String uid) {
    return '用户 $uid';
  }

  @override
  String get authDirNone => '无';

  @override
  String get authDirUnknown => '未知';

  @override
  String get mediaStreamAudio => '音频';

  @override
  String get mediaStreamVideo => '视频';

  @override
  String get mediaStreamSubtitle => '字幕';

  @override
  String get forgotPasswordBody =>
      '1. 如果您是 NAS 用户，请尝试 NAS 帐号登录；\n2. 请联系管理员修改密码。';

  @override
  String tvDetailEpisodeNumberTitle(String number, String title) {
    return '第 $number 集 $title';
  }

  @override
  String get movieDetailSubtitleDefaultSuffix => ' - 默认';

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(String count) {
    return '$count 分钟前';
  }

  @override
  String timeHoursAgo(String count) {
    return '$count 小时前';
  }

  @override
  String timeDaysAgo(String count) {
    return '$count 天前';
  }

  @override
  String timeWeeksAgo(String count) {
    return '$count 周前';
  }

  @override
  String timeMonthsAgo(String count) {
    return '$count 个月前';
  }

  @override
  String timeYearsAgo(String count) {
    return '$count 年前';
  }

  @override
  String get updateNotesEmpty => '暂无更新说明。';

  @override
  String updateNotesTruncated(String url) {
    return '\n\n> 更新说明已截断。请前往 [Release 页面]($url) 查看完整内容。';
  }

  @override
  String get navCategories => '分类';

  @override
  String get navFavorites => '收藏';

  @override
  String get navNoMediaLibrary => '暂无媒体库';

  @override
  String get folderFallbackName => '文件夹';

  @override
  String get folderRescrap => '重新识别';

  @override
  String get folderRescrapStarted => '已发起重新识别';

  @override
  String get folderRescrapFailed => '重新识别失败';

  @override
  String folderRescrapFailedWithError(String error) {
    return '重新识别失败：$error';
  }

  @override
  String get folderRefreshMetadata => '刷新元数据';

  @override
  String get folderRefreshMetadataStarted => '已发起刷新元数据';

  @override
  String get folderRefreshMetadataFailed => '刷新元数据失败';

  @override
  String folderRefreshMetadataFailedWithError(String error) {
    return '刷新元数据失败：$error';
  }

  @override
  String get folderThisFolder => '该文件夹';

  @override
  String get folderDeleteConfirmTitle => '删除';

  @override
  String folderDeleteConfirmBody(String title) {
    return '确定要从媒体库删除「$title」吗？\n仅移除媒体库条目，不会删除磁盘上的文件。';
  }

  @override
  String folderDeleteFailedWithError(String error) {
    return '删除失败：$error';
  }

  @override
  String folderItemCount(String count) {
    return '共 $count 项';
  }

  @override
  String get favoritesTabSingleEpisode => '单集';

  @override
  String get serverUpdateGetVersionFailed => '获取服务端版本失败';

  @override
  String get serverUpdateCheckFailed => '检查服务端更新异常';

  @override
  String serverUpdateCheckFailedWithError(String error) {
    return '检查服务端更新异常: $error';
  }

  @override
  String get serverUpdatePackageNotFound => '服务端更新包未找到';

  @override
  String get serverUpdateAssetMissing => '服务端更新包资产缺失';

  @override
  String get serverUpdateStarting => '开始服务端更新...';

  @override
  String get serverUpdateFailed => '服务端更新失败';

  @override
  String serverUpdateFailedWithError(String error) {
    return '服务端更新失败: $error';
  }

  @override
  String get serverUpdateWaitingRestart => '等待服务端重启...';

  @override
  String serverUpdateSucceeded(String version) {
    return '服务端已更新到 $version';
  }

  @override
  String get serverUpdateTimeout => '服务端更新超时，请检查服务端日志';

  @override
  String get connectionTestInvalidUrl => 'FlyNarwhal 服务端地址无效';

  @override
  String get connectionTestNoVersion => 'FlyNarwhal 服务端未返回版本号';

  @override
  String get smartAnalysisQueued => '已加入分析队列';

  @override
  String get smartAnalysisSubmitted => '分析请求已提交';

  @override
  String smartAnalysisFailedSeasons(String seasons) {
    return '失败剧季：$seasons';
  }

  @override
  String get smartAnalysisSubmitFailed => '分析请求提交失败';

  @override
  String get shortcutFocusSearch => '聚焦搜索输入框';

  @override
  String get shortcutTogglePlayPause => '播放/暂停';

  @override
  String get shortcutMute => '静音/取消静音';

  @override
  String get shortcutSeekBackward => '快退 10 秒';

  @override
  String get shortcutSeekForward => '快进 10 秒';

  @override
  String get shortcutVolumeUp => '音量增加';

  @override
  String get shortcutVolumeDown => '音量减少';

  @override
  String get shortcutToggleFullscreen => '切换全屏';

  @override
  String get shortcutExitFullscreen => '退出全屏';

  @override
  String get shortcutSearchNext => '下一个搜索项';

  @override
  String get shortcutSearchPrev => '上一个搜索项';

  @override
  String get shortcutSearchSelect => '选中搜索项';

  @override
  String get shortcutSearchSwitchTab => '切换搜索分类';

  @override
  String get shortcutSearchExit => '退出搜索';

  @override
  String get playerSubtitleExternalSuffix => ' - 外挂';

  @override
  String get playerSubtitleDefaultSuffix => ' - 默认';

  @override
  String playerVolumeLabel(String value) {
    return '当前音量：$value%';
  }

  @override
  String playerVolumeUnmuteLabel(String value) {
    return '解除静音：$value%';
  }

  @override
  String get playerVolumeMute => '静音';

  @override
  String get playerSeekRewindTo => '快退至';

  @override
  String get playerSeekForwardTo => '快进至';

  @override
  String playerSeekTimeToast(String label, String time) {
    return '$label：$time';
  }

  @override
  String get playerForceH264Disabled => '当前视频为 H.264';

  @override
  String get playerForceSdrDisabled => '当前视频为 SDR';

  @override
  String get playerCloudModeDirect => '网盘直连播放';

  @override
  String get playerCloudModeNasProxy => 'NAS 代理播放';

  @override
  String playerCloudModeSwitchedToast(String label) {
    return '播放方式切换至 $label';
  }

  @override
  String get playerCloudProxyFailedFallbackDirect => 'NAS 代理播放失败，正在切换为网盘直连播放';

  @override
  String get playerInfoMissingSearchSubtitle => '当前文件信息缺失，无法搜索字幕';

  @override
  String get playerInfoMissingAddNasSubtitle => '当前文件信息缺失，无法添加 NAS 字幕';

  @override
  String get playerInfoMissingUploadSubtitle => '当前文件信息缺失，无法上传字幕';

  @override
  String get playerSubtitleDeleteTitle => '删除外挂字幕';

  @override
  String playerSubtitleDeleteConfirm(String displayName) {
    return '确定要删除 $displayName 外挂字幕吗？';
  }

  @override
  String get playerSubtitleDeleteSuccess => '删除字幕成功';

  @override
  String playerSubtitleDeleteFailed(String error) {
    return '删除字幕失败: $error';
  }

  @override
  String get playerSubtitleAddNasTitle => '添加 NAS 字幕文件';

  @override
  String get playerSubtitleAddNasSuccess => 'NAS 字幕添加成功';

  @override
  String get playerSubtitleAlreadyMarked => '该文件已被添加为字幕';

  @override
  String playerSubtitleAddNasFailed(String error) {
    return '添加 NAS 字幕失败: $error';
  }

  @override
  String get playerSubtitleDownloadSuccess => '下载成功';

  @override
  String playerSubtitleDownloadFailed(String error) {
    return '下载字幕失败: $error';
  }

  @override
  String get playerSubtitleTaskCreated => '已创建字幕下载任务';

  @override
  String get playerSubtitleTaskFailed => '创建字幕下载任务失败，请重试';

  @override
  String playerSubtitleSwitchFailed(String error) {
    return '切换字幕失败: $error';
  }

  @override
  String playerSwitchOriginalQualityFailed(String error) {
    return '切换原画失败: $error';
  }

  @override
  String playerLoadFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String playerToggleFullscreenFailed(String error) {
    return '切换全屏失败: $error';
  }

  @override
  String playerSwitchPlaybackSettingsFailed(String error) {
    return '切换播放设置失败: $error';
  }

  @override
  String get playerNotReady => '播放器尚未准备完成';

  @override
  String playerEnterPipFailed(String error) {
    return '进入画中画失败: $error';
  }

  @override
  String playerExitPipFailed(String error) {
    return '退出画中画失败: $error';
  }

  @override
  String playerSwitchQualityFailed(String error) {
    return '切换画质失败: $error';
  }

  @override
  String playerSwitchPlayModeFailed(String error) {
    return '切换播放方式失败: $error';
  }

  @override
  String playerSwitchAudioFailed(String error) {
    return '切换音频失败: $error';
  }

  @override
  String playerSubtitleSwitchingTo(String language) {
    return '字幕正在切换至：$language';
  }

  @override
  String playerSubtitleSwitchingToFormat(String language, String format) {
    return '字幕正在切换至：$language $format';
  }

  @override
  String get playerClose => '关闭';

  @override
  String get playerBack => '返回';

  @override
  String get playerRewindTenSeconds => '快退 10 秒';

  @override
  String get playerForwardTenSeconds => '快进 10 秒';

  @override
  String get playerPlayPause => '播放/暂停';

  @override
  String get playerPip => '画中画';

  @override
  String get playerExitPip => '退出画中画';

  @override
  String get playerDanmakuClose => '关闭弹幕';

  @override
  String get playerDanmakuOpen => '开启弹幕';

  @override
  String get playerPlaybackDetailsTooltip => '播放详细信息';

  @override
  String get playerSkipConfigSaved => '设置成功';

  @override
  String playerSkipConfigSaveFailed(String error) {
    return '设置失败: $error';
  }

  @override
  String get playerDanmakuRequestFailed => '请求弹幕接口失败，请检查飞鲸服务端配置';

  @override
  String get playerSmartSkipRequestFailed => '请求智能片头片尾接口失败，请检查飞鲸服务端配置';

  @override
  String playerFeatureComingSoon(String feature) {
    return '$feature 暂未接入';
  }

  @override
  String get playerPlayErrorRetrySwitch => '播放出错,请尝试切换线路';

  @override
  String get playerNoPlayableLine => '该频道没有可用的播放线路';

  @override
  String get playerLoadFailedBackRetry => '加载失败,请返回重试';

  @override
  String get playerPlayFailedSwitchLine => '播放失败,请尝试切换线路';

  @override
  String get playerLive => '直播中';

  @override
  String get playerPause => '暂停';

  @override
  String get playerPlay => '播放';

  @override
  String get playerDanmakuSettingsTooltip => '弹幕设置';

  @override
  String get playerDanmakuSettingsTitle => '弹幕设置';

  @override
  String get playerDanmakuAdvancedSettings => '高级设置';

  @override
  String playerDanmakuDisplayArea(String value) {
    return '显示区域 $value%';
  }

  @override
  String playerDanmakuOpacity(String value) {
    return '不透明度 $value%';
  }

  @override
  String playerDanmakuFontSize(String value) {
    return '字号 $value%';
  }

  @override
  String playerDanmakuSpeed(String value) {
    return '速度 $value';
  }

  @override
  String get playerDanmakuSpeedVerySlow => '极慢';

  @override
  String get playerDanmakuSpeedSlow => '较慢';

  @override
  String get playerDanmakuSpeedNormal => '适中';

  @override
  String get playerDanmakuSpeedFast => '较快';

  @override
  String get playerDanmakuSpeedVeryFast => '极快';

  @override
  String get playerDanmakuSyncPlaybackSpeed => '弹幕速度同步播放倍速';

  @override
  String get playerDanmakuShowDebugInfo => '显示弹幕调试信息';

  @override
  String get playerStrmDirectPlaying => '正在直连播放 STRM 文件';

  @override
  String get playerCloudModeDirectDescription => '速度较快、省流';

  @override
  String get playerCloudModeNasProxyDescription => '色调或音频异常时可尝试切换';

  @override
  String get playerCloudPlayRecommend => '推荐';

  @override
  String get playerCloudPlayingNotice => '正在播放网盘上的文件，播放速度和画质取决于网盘方规则。';

  @override
  String get playerCloudSwitchNotice => '如遇播放异常，可尝试切换播放方式。';

  @override
  String get playerPlayModeLabel => '播放方式';

  @override
  String get playerCloudFallbackName => '网盘';

  @override
  String get playerCloudPlayErrorTitle => '抱歉，播放出错了';

  @override
  String get playerCloudSwitchQuality => '播放其他画质';

  @override
  String get playerCloudSwitchToProxy => '切换 NAS 代理播放';

  @override
  String get playerStrmPlaybackErrorHint =>
      'STRM 直连播放异常，可能原因：网盘挂载连接断开、触发网盘风控、网盘限制非会员操作、浏览器不支持该文件类型。';

  @override
  String get playerChannelLineFallback => '线路';

  @override
  String get playerSubtitleAddDialogTitle => '添加字幕';

  @override
  String get playerSubtitleSearchSortHint => '按相关度排序：';

  @override
  String get playerSubtitleSearchNoResults => '未搜索到相关字幕';

  @override
  String playerSubtitleSearchDownloadCount(String count) {
    return '下载量 $count';
  }

  @override
  String get playerSubtitleSearchDownloading => '下载中';

  @override
  String get playerSubtitleSearchDownloadDone => '下载完成';

  @override
  String get playerSubtitleSearchDownload => '下载字幕';

  @override
  String get playerSubtitleDownloadSimilarForEpisodes => '为其他集下载相似字幕';

  @override
  String get playerSubtitleLanguageSimplifiedChinese => '简体中文';

  @override
  String get playerSubtitleLanguageEnglish => '英文';

  @override
  String get playerSubtitleAdjust => '调整字幕';

  @override
  String get playerSubtitleReset => '重置';

  @override
  String get playerSubtitleOffset => '偏移';

  @override
  String get playerSubtitleOffsetMin => '-5秒';

  @override
  String get playerSubtitleOffsetMax => '+5秒';

  @override
  String get playerSubtitleSecondsSuffix => '秒';

  @override
  String get playerSubtitlePosition => '位置';

  @override
  String get playerSubtitlePositionBottom => '底部';

  @override
  String get playerSubtitlePositionTop => '顶部';

  @override
  String get playerSubtitlePositionLockedHint => '当前字幕为弹幕/特效字幕（含定位标签），位置调整不可用';

  @override
  String get playerSubtitleFontSize => '字号';

  @override
  String get playerSubtitleFontSizeMin => '最小';

  @override
  String get playerSubtitleFontSizeMax => '最大';

  @override
  String get playerSubtitlePanelTitle => '字幕';

  @override
  String get playerSubtitleAdjustButton => '调整';

  @override
  String get playerSubtitleAddButton => '添加';

  @override
  String get playerSubtitleOff => '关闭';

  @override
  String get playerSubtitleSearchMenu => '搜索字幕';

  @override
  String get playerSubtitleAddNasFile => '添加 NAS 字幕文件';

  @override
  String get playerSubtitleAddLocalFile => '添加电脑字幕文件';

  @override
  String get playerSubtitleDirectLinkMissingTitle => '直连播放缺失内置字幕';

  @override
  String get playerSubtitleDirectLinkMissingContent =>
      '由于网盘方的限制，直连转码播放时可能无法获取内置字幕列表。如需切换内置字幕，请切换播放方式为“NAS 代理播放”。';

  @override
  String get playerDetailSeparator => '：';

  @override
  String get playerPlayType => '播放类型';

  @override
  String get playerPlayTypeStrmDirect => 'STRM 直连播放';

  @override
  String get playerPlayTypeTranscode => '转码播放';

  @override
  String get playerPlayTypeDirect => '直接播放';

  @override
  String get playerTranscodeReason => '转码原因';

  @override
  String get playerTranscodeReasonSeparator => '；';

  @override
  String get playerPlaybackInfo => '播放信息';

  @override
  String get playerMediaSourceInfo => '媒体源信息';

  @override
  String get playerContainerFormat => '封装容器';

  @override
  String get playerBufferDuration => '缓冲时长';

  @override
  String get playerAudioCodec => '音频编码';

  @override
  String get playerGpuEnabled => '启用 GPU';

  @override
  String get playerDecodeMethod => '解码方式';

  @override
  String get playerEncodeMethod => '编码方式';

  @override
  String get playerTranscodeFrameRate => '转码帧率';

  @override
  String get playerDroppedFrames => '丢帧';

  @override
  String get playerCorruptedFrames => '坏帧';

  @override
  String get playerCodec => '编码';

  @override
  String get playerDynamicRange => '动态范围';

  @override
  String get playerFullscreenEnter => '进入全屏';

  @override
  String get playerFullscreenExit => '退出全屏';

  @override
  String get playerNextVideo => '下一个视频';

  @override
  String playerEpisodeNumber(String number) {
    return '第 $number 集';
  }

  @override
  String get playerReplay => '重播';

  @override
  String get playerUndo => '撤销';

  @override
  String get playerSkipIntroAutoSkipped => '已自动跳过片头';

  @override
  String playerSkipOutroInSeconds(int seconds) {
    return '$seconds 秒后跳过片尾';
  }

  @override
  String playerSkipOutroNextEpisodeInSeconds(int seconds) {
    return '$seconds 秒后播放下一集';
  }

  @override
  String playerSkipOutroEndInSeconds(int seconds) {
    return '$seconds 秒后结束播放';
  }

  @override
  String get playerUnknown => '未知';

  @override
  String playerAudioDefaultSuffix(String language) {
    return '$language - 默认';
  }

  @override
  String get playerSettingsWindowAspectRatioFollowVideo => '跟随视频比例';

  @override
  String get playerSettingsAspectRatioDefault => '默认';

  @override
  String get playerSettingsAdvanced => '高级';

  @override
  String get playerSettingsAutoNext => '自动连播';

  @override
  String get playerSettingsSkipIntroOutro => '跳过片头/片尾';

  @override
  String get playerSettingsWindowRatio => '窗口比例';

  @override
  String get playerSettingsAspectRatio => '画面比例';

  @override
  String get playerSettingsClientDecodeMode => '客户端解码模式';

  @override
  String get playerSettingsAudio => '音频';

  @override
  String get playerSettingsAudioPassthrough => '音频直通';

  @override
  String get playerSettingsAudioPassthroughTitle => '音频直通';

  @override
  String get playerSettingsAudioPassthroughDescription =>
      '将 AC3/DTS/EAC3/TrueHD 等压缩音频流原样输出到 HDMI/S-PDIF 外接设备解码。仅对原始音轨的直链播放生效，转码音轨会自动回落为本地解码。';

  @override
  String get playerSettingsAudioOutputDevice => '输出设备';

  @override
  String get playerSettingsAudioOutputDeviceAuto => '自动（默认）';

  @override
  String get playerSettingsAudioOutputDeviceEmpty => '未检测到可用的音频输出设备';

  @override
  String get playerSettingsAdvancedTitle => '高级设置';

  @override
  String get playerSettingsHevcToH264 => 'HEVC 转为 H.264';

  @override
  String get playerSettingsHevcToH264Description => '播放有声音无画面时可尝试开启';

  @override
  String get playerSettingsForceSdr => '色调强制映射为 SDR';

  @override
  String get playerSettingsForceSdrDescription => '画面偏暗时可尝试开启，适用于不支持 HDR 的设备';

  @override
  String get playerSettingsQuarkCdnSegment => '夸克 CDN 分片直连';

  @override
  String get playerSettingsQuarkCdnSegmentDescription =>
      '开启后按分片预取夸克网盘直连流；关闭则使用原有直连方式';

  @override
  String get playerSettingsSmartSkip => '智能跳过';

  @override
  String get playerSettingsSkipIntroOutroBoth => '跳过片头片尾';

  @override
  String get playerSettingsIntroConfigured => '已设置片头';

  @override
  String get playerSettingsOutroConfigured => '已设置片尾';

  @override
  String get playerSettingsNotSet => '未设置';

  @override
  String playerSettingsSkipScope(String title, String season) {
    return '生效范围: 《$title》 第 $season 季';
  }

  @override
  String get playerSettingsSmartSkipIntroOutro => '智能跳过片头/片尾';

  @override
  String get playerSettingsIntroDuration => '片头时长';

  @override
  String get playerSettingsOutroDuration => '片尾时长';

  @override
  String playerSettingsSetOutroToRemaining(String time) {
    return '将当前剩余时长 $time 设为片尾';
  }

  @override
  String playerSettingsSetIntroToCurrent(String time) {
    return '将当前时间 $time 设为片头';
  }

  @override
  String get playerSettingsTenMinutes => '10 分钟';

  @override
  String get playerSettingsSliderStart => '开始';

  @override
  String get playerSettingsSliderEnd => '结束';

  @override
  String get playerSettingsDecodeAutoTip => '自动选择硬件解码,失败时回退到软件解码。推荐。';

  @override
  String get playerSettingsDecodeSoftwareTip => '强制使用软件解码,兼容性最好;硬解花屏/黑屏时的兜底方案。';

  @override
  String get playerSettingsDecodeCopyTip =>
      '硬件解码但将帧拷回内存,可与所有滤镜/弹幕/截图功能共存;略费 CPU。';

  @override
  String get playerSettingsSoftwareDecode => '软件解码';

  @override
  String get playerSettingsCopyBackMode => '回拷模式';

  @override
  String get playerSettingsSpecifyHwdec => '指定硬件解码器';

  @override
  String get playerSettingsNoHwdecAvailable => '未探测到可用的硬件解码器';

  @override
  String get playerQualityTitle => '视频质量';

  @override
  String get playerQualityOriginal => '原画';

  @override
  String get playerQualityCustom => '自定义';

  @override
  String get playerQualityCustomTitle => '自定义视频质量';

  @override
  String get playerQualityDirectUnsupported => '直连播放暂不支持该画质';

  @override
  String get playerQualityLowRiskHint => '选项风控概率相对低，建议优先选择';

  @override
  String get playerQualityOriginalNoAudioHint => '直连播放原画无声音';

  @override
  String get playerQualityOriginalNoAudioTooltip =>
      '由于播放器对音频编码格式的支持有限，直连播放原画可能出现无声音的情况。可尝试切换播放方式为 “NAS 代理播放”。';

  @override
  String get playerSpeedLabel => '倍速';

  @override
  String get playerSettingsAuto => '自动';

  @override
  String get playerTranscodeReasonLowerQuality => '根据视频质量设置降低画质';

  @override
  String get playerTranscodeReasonSubtitleBurn => '字幕烧录';

  @override
  String get playerTranscodeReasonSubtitleToVtt => '字幕转为 vtt 切片';

  @override
  String get playerTranscodeReasonVideoFormat => '视频格式转换';

  @override
  String get playerTranscodeReasonAudioFormat => '音频格式转换';

  @override
  String get playerTranscodeReasonToneMapping => '色调映射';

  @override
  String get playerDecodeMethodSoftware => '软解码';

  @override
  String get playerDecodeMethodQsv => 'QSV 解码';

  @override
  String get playerDecodeMethodVaapi => 'VAAPI 解码';

  @override
  String get playerDecodeMethodNvdec => 'NVDEC 解码';

  @override
  String get playerDecodeMethodRkmpp => 'RKMPP 解码';

  @override
  String get playerEncodeMethodSoftware => '软编码';

  @override
  String get playerEncodeMethodQsv => 'QSV 编码';

  @override
  String get playerEncodeMethodQsvLowPower => 'QSV 低电压编码';

  @override
  String get playerEncodeMethodVaapi => 'VAAPI 编码';

  @override
  String get playerEncodeMethodNvenc => 'NVENC 编码';

  @override
  String get playerEncodeMethodRkmpp => 'RKMPP 编码';

  @override
  String get smartAnalysisQueuedLoading => '片头/片尾分析任务已提交';

  @override
  String get smartAnalysisCloudOrStrmRejected => '网盘或 STRM 视频无法使用“智能分析片头/片尾”功能';

  @override
  String get playerSkipSegmentIntro => '片头';

  @override
  String get playerSkipSegmentRecap => '前情提要';

  @override
  String get playerSkipSegmentOutro => '片尾';

  @override
  String get playerSkipSegmentPreview => '下集预告';

  @override
  String get playerSkipSegmentCommercial => '广告';

  @override
  String get playerSkipSegmentGeneric => '片段';

  @override
  String playerSkipSegmentJoined(String parts) {
    return '$parts';
  }

  @override
  String playerSkipSegmentInSeconds(String seconds, String subject) {
    return '$seconds 秒后跳过$subject';
  }

  @override
  String playerSkipAutoSkipped(String subject) {
    return '已自动跳过$subject';
  }

  @override
  String get playerSettingsSkipRecap => '跳过前情提要';

  @override
  String get playerSettingsSkipPreview => '跳过下集预告';

  @override
  String get playerSettingsSkipCommercial => '跳过广告';

  @override
  String get playerSettingsSmartSkipConfig => '智能跳过配置';

  @override
  String get playerSettingsSkipIntroOnly => '跳过片头';

  @override
  String get playerSettingsSkipOutroOnly => '跳过片尾';

  @override
  String get playerSkipSegmentConnector => '与';

  @override
  String get smartSkipConfigTitle => '智能跳过配置';

  @override
  String get smartSkipSave => '保存';

  @override
  String get smartSkipSaved => '智能跳过配置已保存';

  @override
  String get smartSkipSaveFailed => '保存失败';

  @override
  String get smartSkipLoginRequired => '请先登录后配置';

  @override
  String get smartSkipLoadFailed => '服务端配置加载失败，当前展示默认配置';

  @override
  String get smartSkipDetectMode => '检测模式';

  @override
  String get smartSkipAnimeMode => '动漫模式';

  @override
  String get smartSkipPreferChromaprint => '优先指纹匹配';

  @override
  String get smartSkipAlternativeBlackFrame => '备用黑帧分析器';

  @override
  String get smartSkipDetectIntro => '检测片头';

  @override
  String get smartSkipDetectOutro => '检测片尾';

  @override
  String get smartSkipDetectRecap => '检测前情提要';

  @override
  String get smartSkipDetectPreview => '检测下集预告';

  @override
  String get smartSkipDetectCommercial => '检测广告';

  @override
  String get smartSkipAdvanced => '高级';

  @override
  String get smartSkipDurationLimit => '时长限制（秒）';

  @override
  String get smartSkipBoundaryOffset => '边界偏移（秒）';

  @override
  String get smartSkipIntroStartOffset => '片头开始偏移';

  @override
  String get smartSkipIntroEndOffset => '片头结束偏移';

  @override
  String get smartSkipIntroMinDuration => '片头最短时长';

  @override
  String get smartSkipIntroMaxDuration => '片头最长时长';

  @override
  String get smartSkipOutroMinDuration => '片尾最短时长';

  @override
  String get smartSkipOutroMaxDuration => '片尾最长时长';

  @override
  String get smartSkipOutroEndOffset => '片尾结束偏移';

  @override
  String get smartSkipRestoreDefaults => '恢复默认';

  @override
  String get playerSettingsSmartSkipIntro => '跳过片头';

  @override
  String get playerSettingsSmartSkipOutro => '跳过片尾';

  @override
  String get smartSkipAnalysisFailedRetry => '分析请求提交失败，请稍后重试';

  @override
  String get smartSkipLoadConfigFailed => '加载智能跳过配置失败';

  @override
  String get smartSkipSaveConfigFailed => '保存智能跳过配置失败';

  @override
  String get smartSkipConfigConfigure => '配置';

  @override
  String get settingsSmartSkipConfigCaption => '服务端智能分析片头片尾的参数';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => '飛鯨影視';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionAccount => '帳號';

  @override
  String get settingsSectionAppearance => '外觀';

  @override
  String get settingsSectionGeneral => '一般';

  @override
  String get settingsLanguageTitle => '語言';

  @override
  String get settingsLanguageCaption => '選擇應用介面的顯示語言';

  @override
  String get settingsSectionServer => '伺服器';

  @override
  String get settingsSectionPrivacy => '隱私與安全';

  @override
  String get settingsSectionAbout => '關於';

  @override
  String get settingsAccountUnloaded => '未載入使用者資訊';

  @override
  String get settingsAccountUnloadedCaption => '登入後將在首頁自動完成使用者資訊驗證';

  @override
  String get settingsAccountAdminBadge => '管理員';

  @override
  String get settingsAccountSignOut => '登出';

  @override
  String get settingsAccountSignOutCaption => '登出目前帳號';

  @override
  String get settingsAccountSignOutConfirm => '確認登出目前帳號？';

  @override
  String get settingsAppearanceThemeMode => '佈景模式';

  @override
  String get settingsAppearanceThemeModeCaption => '是否跟隨系統佈景';

  @override
  String get settingsAppearanceFollowSystem => '跟隨系統';

  @override
  String get settingsAppearanceManual => '手動設定';

  @override
  String get settingsAppearanceColor => '顏色';

  @override
  String get settingsAppearanceColorCaption => '請選擇佈景顏色';

  @override
  String get settingsAppearanceDark => '深色';

  @override
  String get settingsAppearanceLight => '淺色';

  @override
  String get settingsAppearanceNavStyle => '導覽列樣式';

  @override
  String get settingsAppearanceNavStyleCaption => '請選擇導覽檢視版面';

  @override
  String get settingsAppearanceDetailsLiquidGlass => '播放詳細資訊面板啟用液態玻璃效果';

  @override
  String get settingsAppearanceDetailsLiquidGlassCaption =>
      '開啟後播放詳細資訊面板使用帶動畫的液態玻璃樣式，關閉則使用靜態毛玻璃樣式';

  @override
  String get settingsGeneralFontSize => '字型大小';

  @override
  String get settingsGeneralFontSizeCaption => '調整應用程式整體文字大小';

  @override
  String get settingsGeneralShortcuts => '快速鍵設定';

  @override
  String get settingsGeneralShortcutsCaption => '自訂快速鍵';

  @override
  String get settingsGeneralCustomize => '自訂';

  @override
  String get settingsServerEnable => '啟用飛鯨伺服器';

  @override
  String get settingsServerEnableCaption => '啟用後可連接飛鯨伺服器，實現智慧辨識片頭／片尾、彈幕等功能支援';

  @override
  String get settingsServerAddress => '飛鯨伺服器位址';

  @override
  String get settingsServerAddressHttpsRequired => '必須使用 HTTPS 位址';

  @override
  String get settingsServerAddressIncomplete => '請填寫完整的伺服器 URL';

  @override
  String get settingsServerAuthCode => '授權碼';

  @override
  String get settingsServerAuthCodePlaceholder => '填寫授權碼';

  @override
  String get settingsServerAuthCodeFilled => '已填寫飛鯨伺服器授權碼';

  @override
  String get settingsServerAuthCodePrompt => '填寫飛鯨伺服器授權碼';

  @override
  String get settingsServerAuthCodeLabel => '請輸入飛鯨伺服器授權碼：';

  @override
  String get settingsServerAuthCodeHint => '請在飛鯨伺服器頁面點擊「取得授權碼」後貼到這裡。';

  @override
  String get settingsServerAuthCodeHelp =>
      '請在瀏覽器中前往部署於 NAS 的飛鯨伺服器位址（應用中心版請點擊飛牛 OS 桌面中的「飛鯨影視」），點擊右上角的「取得授權碼」按鈕，複製授權碼後貼到填寫授權碼的文字框中。\\n需要伺服器版本 >= 0.6.0，低於 0.6.0 版的伺服器不支援自動更新至 0.6.0 或以上版本，請手動更新至 0.6.0 或以上版本';

  @override
  String get settingsServerTest => '測試';

  @override
  String get settingsServerTesting => '測試中';

  @override
  String settingsServerTestSuccess(String version) {
    return '飛鯨伺服器連線成功，目前伺服器版本號：$version';
  }

  @override
  String settingsServerTestConnectFailed(String error) {
    return '飛鯨伺服器連線失敗：$error';
  }

  @override
  String get settingsServerUnreachable => '飛鯨伺服器無法存取';

  @override
  String get settingsPrivacySslTitle => 'SSL 憑證信任清單';

  @override
  String get settingsPrivacySslCaption => '伺服器憑證驗證失敗時可加入信任，在此管理';

  @override
  String settingsPrivacySslTrustedCount(String count) {
    return '已信任 $count 張憑證';
  }

  @override
  String get settingsPrivacyManage => '管理';

  @override
  String get settingsPrivacyStatement => '隱私聲明';

  @override
  String get settingsPrivacyStatementBody =>
      '為了改進軟體效能，我們會收集部分硬體資訊（如 CPU、GPU 型號等）作為參考依據。這些資訊僅用於最佳化軟體，不會涉及個人隱私。';

  @override
  String get settingsPrivacyGitHubProxy => 'GitHub 資源代理';

  @override
  String get settingsPrivacyGitHubProxyCaption => '僅用於安裝檔下載';

  @override
  String get settingsPrivacyProxyAddress => '代理位址';

  @override
  String get settingsAboutVersion => '目前版本';

  @override
  String get settingsAboutCheckUpdate => '檢查更新';

  @override
  String get settingsAboutChangelog => '更新日誌';

  @override
  String get settingsAboutChangelogCaption => '檢視各版本的更新內容';

  @override
  String get settingsAboutPrerelease => '接收預先發行版本更新';

  @override
  String get settingsAboutPrereleaseEarly => '搶先體驗';

  @override
  String get settingsAboutAutoDownload => '自動下載更新';

  @override
  String get settingsAboutAutoDownloadCaption => '發現更新後在背景下載並驗證安裝檔';

  @override
  String get settingsAboutOpen => '開啟';

  @override
  String get settingsAboutClose => '關閉';

  @override
  String get settingsAboutExportLogs => '匯出錯誤日誌';

  @override
  String get settingsAboutExportLogsCaption => '支援匯出近三天的錯誤日誌，方便開發者排查問題';

  @override
  String get settingsAboutExport => '匯出';

  @override
  String get settingsAboutExportError => '匯出錯誤';

  @override
  String get settingsAboutVersionLoading => '正在讀取版本資訊…';

  @override
  String get settingsAboutVersionUnavailable => '無法讀取版本資訊';

  @override
  String get commonLoading => '載入中';

  @override
  String get commonConfirm => '確定';

  @override
  String get commonCancel => '取消';

  @override
  String get commonGotIt => '我知道了';

  @override
  String get commonUserInfoLoadFailed => '載入使用者資訊失敗';

  @override
  String get commonUserInfoLoading => '正在載入使用者資訊…';

  @override
  String get shortcutsTitle => '快速鍵設定';

  @override
  String get shortcutsTabKeyboard => '快速鍵';

  @override
  String get shortcutsTabPlayback => '播放';

  @override
  String get shortcutsTabHelp => '說明';

  @override
  String get shortcutsRestoreDefaults => '還原預設';

  @override
  String get shortcutsSearch => '搜尋';

  @override
  String get shortcutsPrompt => '請在鍵盤按下快速鍵或組合鍵';

  @override
  String get sslTrustedTitle => 'SSL 憑證信任清單';

  @override
  String get sslTrustedEmpty => '尚無信任的憑證。當伺服器憑證驗證失敗時，可以在提示中選擇「信任此憑證」。';

  @override
  String sslTrustedAddedAt(String time) {
    return '新增時間：$time';
  }

  @override
  String get sslTrustedRemove => '移除';

  @override
  String get sslTrustedRemoveAll => '全部清除';

  @override
  String get sslTrustedRemoveTitle => '移除信任的憑證';

  @override
  String sslTrustedRemoveBody(String host) {
    return '移除後，再次存取「$host」時該憑證會重新驗證。';
  }

  @override
  String get sslTrustedClearTitle => '清除全部信任的憑證';

  @override
  String get sslTrustedClearBody => '清除後，所有伺服器的憑證都會重新驗證。';

  @override
  String get supportAuthorTitle => '支持作者';

  @override
  String get supportAuthorBody =>
      '您的支持就是我持續更新的動力，如果覺得好用，請給專案點一個 Star ⭐，謝謝！(^_−)☆';

  @override
  String get supportAuthorIssues =>
      '專案確實還有很多地方需要完善，如果遇到軟體問題或 Bug，歡迎提交 Issue 或 PR。';

  @override
  String get supportAuthorOpenRepo => '開啟 Github 儲存庫';

  @override
  String get supportAuthorLater => '稍後再說';

  @override
  String get fontScaleSmall => '小';

  @override
  String get fontScaleMedium => '中';

  @override
  String get fontScaleLarge => '大';

  @override
  String get filterTitle => '篩選';

  @override
  String get filterReset => '重設';

  @override
  String get filterCollapse => '收合';

  @override
  String get filterOptionAll => '全部';

  @override
  String get filterOptionMovie => '電影';

  @override
  String get filterOptionTv => '電視劇';

  @override
  String get filterOptionWatched => '已觀看';

  @override
  String get filterOptionUnwatched => '未觀看';

  @override
  String get filterOptionMatched => '已匹配';

  @override
  String get filterOptionUnmatched => '未匹配';

  @override
  String get filterOptionNfoMatched => 'NFO 匹配';

  @override
  String get filterOptionOthers => '其他';

  @override
  String get filterOptionThisYear => '今年';

  @override
  String filterOptionDecade(String decade) {
    return '$decade 年代';
  }

  @override
  String get filterOptionDolbyVision => '杜比視界';

  @override
  String get filterOptionDolbySurround => '杜比環繞';

  @override
  String get filterOptionDolbyAtmos => '杜比全景聲';

  @override
  String get filterOptionStereo => '立體聲';

  @override
  String get filterRowMediaType => '影視類型';

  @override
  String get filterRowGenre => '類型';

  @override
  String get filterRowResolution => '解析度';

  @override
  String get filterRowColorRange => '視訊動態範圍';

  @override
  String get filterRowAudioType => '音訊規格';

  @override
  String get filterRowLocation => '國家和地區';

  @override
  String get filterRowDecade => '發行年份';

  @override
  String get filterRowRecognitionStatus => '匹配狀態';

  @override
  String get filterRowWatched => '是否已觀看';

  @override
  String get mediaInfoTitle => '檔案媒體資訊';

  @override
  String get mediaInfoEmpty => '暫無資料';

  @override
  String get mediaInfoSectionVideo => '視訊';

  @override
  String get mediaInfoSectionAudio => '音訊';

  @override
  String get mediaInfoSectionSubtitle => '字幕';

  @override
  String get mediaInfoFieldResolution => '解析度';

  @override
  String get mediaInfoFieldDynamicRange => '視訊動態範圍';

  @override
  String get mediaInfoFieldCodec => '編碼器';

  @override
  String get mediaInfoFieldProfile => '設定檔';

  @override
  String get mediaInfoFieldLevel => '等級';

  @override
  String get mediaInfoFieldFrameRate => '影格率';

  @override
  String get mediaInfoFieldBitRate => '位元率';

  @override
  String get mediaInfoFieldAspectRatio => '長寬比';

  @override
  String get mediaInfoFieldPixelFormat => '像素格式';

  @override
  String get mediaInfoFieldBitDepth => '位元深度';

  @override
  String get mediaInfoFieldColorSpace => '色彩空間';

  @override
  String get mediaInfoFieldColorPrimaries => '色彩原色';

  @override
  String get mediaInfoFieldColorTransfer => '色彩轉換';

  @override
  String get mediaInfoFieldReferenceFrames => '參考影格';

  @override
  String get mediaInfoFieldInterlaced => '交錯掃描';

  @override
  String get mediaInfoFieldLayout => '聲道配置';

  @override
  String get mediaInfoFieldChannels => '聲道';

  @override
  String get mediaInfoFieldSampleRate => '取樣率';

  @override
  String get mediaInfoFieldLanguage => '語言';

  @override
  String get mediaInfoFieldDefault => '預設';

  @override
  String get mediaInfoFieldForced => '強制';

  @override
  String get mediaInfoFieldExternal => '外部';

  @override
  String get mediaInfoYes => '是';

  @override
  String get mediaInfoNo => '否';

  @override
  String get subtitleUploadFileTypeName => '字幕檔案';

  @override
  String get subtitleUploadSelect => '選擇';

  @override
  String get subtitleUploadAdded => '新增字幕成功';

  @override
  String get subtitleUploadFailed => '新增字幕失敗，請重試';

  @override
  String subtitleUploadPartial(String count) {
    return '部分字幕新增成功，其中 $count 個失敗';
  }

  @override
  String subtitleUploadTooMany(String count) {
    return '最多選擇 $count 個檔案';
  }

  @override
  String get subtitleUploadMissingUser => '目前使用者資訊缺失，無法還原檔案選擇器狀態';

  @override
  String subtitleUploadPickerFailed(String error) {
    return '選擇字幕檔案失敗：$error';
  }

  @override
  String subtitleUploadFormatSuffix(String formats) {
    return '$formats 格式的檔案';
  }

  @override
  String get captionBack => '返回';

  @override
  String get captionRefresh => '重新整理';

  @override
  String get captionToggleNav => '切換導覽列';

  @override
  String get captionAlwaysOnTop => '視窗置頂';

  @override
  String get captionUnpin => '取消置頂';

  @override
  String get toastInfo => '資訊';

  @override
  String get toastSuccess => '成功';

  @override
  String get toastWarning => '警告';

  @override
  String get toastError => '錯誤';

  @override
  String get toastServerUrlRequired => '請填寫飛鯨伺服器 URL';

  @override
  String get toastServerAuthCodeRequired => '請填寫飛鯨伺服器授權碼';

  @override
  String get toastServerCredentialsRequired => '請填寫飛鯨伺服器 URL 和授權碼';

  @override
  String get sslPromptTitle => '憑證驗證失敗';

  @override
  String sslPromptBody(String host) {
    return '「$host」的憑證驗證未通過，可能是憑證過期、網域不符或自簽憑證。';
  }

  @override
  String sslPromptFingerprint(String fingerprint) {
    return '憑證指紋 SHA-256：$fingerprint';
  }

  @override
  String get sslPromptQuestion => '繼續存取將略過安全保護，是否繼續存取？';

  @override
  String get sslPromptTrustPersistent => '信任此憑證';

  @override
  String get sslPromptTrustOnce => '僅本次信任';

  @override
  String get sslPromptCancel => '取消存取';

  @override
  String get layoutTitle => '版面';

  @override
  String get layoutPosterWall => '海報牆';

  @override
  String get layoutVerticalPoster => '直幅海報';

  @override
  String get layoutBannerPoster => '橫幅海報';

  @override
  String get layoutList => '清單';

  @override
  String get castTitle => '演職人員';

  @override
  String get castRoleDirector => '導演';

  @override
  String get castRoleActor => '演員';

  @override
  String get castRoleWriter => '編劇';

  @override
  String get castRoleProducer => '製片人';

  @override
  String castCharacter(String role) {
    return '飾 $role';
  }

  @override
  String get sortTitle => '標題';

  @override
  String get sortAddedDate => '新增日期';

  @override
  String get sortReleaseYear => '發行年份';

  @override
  String get sortScore => '評分';

  @override
  String get sortAscending => '升冪';

  @override
  String get sortDescending => '降冪';

  @override
  String get nasSubtitleStorageLocation => '視訊所在位置';

  @override
  String get nasSubtitleSelectStorage => '請選擇儲存空間';

  @override
  String nasSubtitleTooMany(String count) {
    return '最多選擇 $count 個檔案';
  }

  @override
  String get loadFailedTitle => '載入失敗';

  @override
  String get loadFailedUnknown => '未知錯誤';

  @override
  String get loadFailedRetry => '重試';

  @override
  String get episodeViewCard => '切換為卡片檢視';

  @override
  String get episodeViewButton => '切換為序號檢視';

  @override
  String get nasBrowserEmpty => '空空如也';

  @override
  String get actionPlay => '播放';

  @override
  String get actionContinuePlay => '繼續播放';

  @override
  String get actionFavoriteAdd => '加入收藏';

  @override
  String get actionFavoriteRemove => '取消收藏';

  @override
  String get actionMarkWatched => '標記為已看';

  @override
  String get actionMarkUnwatched => '標記為未看';

  @override
  String get actionMore => '更多操作';

  @override
  String get actionMore2 => '更多';

  @override
  String get toastFavoriteAdded => '已收藏';

  @override
  String get toastFavoriteRemoved => '已取消收藏';

  @override
  String get toastMarkedUnwatched => '標記為未觀看';

  @override
  String get toastMarkedWatched => '標記為已觀看';

  @override
  String get toastOperationFailed => '操作失敗';

  @override
  String toastOperationFailedReason(String message) {
    return '操作失敗，$message';
  }

  @override
  String get mediaInfoNoOverview => '暫無介紹';

  @override
  String get mediaInfoNoInfo => '暫無信息';

  @override
  String get mediaInfoNoContent => '無內容';

  @override
  String get mediaInfoFileInfo => '檔案資訊';

  @override
  String get mediaInfoFileLocation => '檔案位置';

  @override
  String get mediaInfoFileSize => '檔案大小';

  @override
  String get mediaInfoCreatedDate => '建立日期';

  @override
  String get mediaInfoAddedDate => '新增日期';

  @override
  String get mediaInfoStreamSection => '影片/音訊資訊';

  @override
  String get linkLabel => '連結:  ';

  @override
  String get imdbLinkLabel => 'IMDB 連結';

  @override
  String defaultSuffix(String title) {
    return '$title - 預設';
  }

  @override
  String get actionViewAll => '查看全部';

  @override
  String get movieDetailNotFound => '找不到電影資訊';

  @override
  String get movieDetailDescriptionTitle => '電影簡介';

  @override
  String get movieDetailEpisodeDescriptionTitle => '劇集簡介';

  @override
  String get movieDetailSubtitleAddTitle => '新增字幕';

  @override
  String get movieDetailSubtitleAlreadyAdded => '該檔案已被新增為字幕';

  @override
  String get movieDetailSubtitleAddFailed => '新增字幕失敗';

  @override
  String movieDetailSubtitleRetry(String error) {
    return '請稍後重試：$error';
  }

  @override
  String get movieDetailSubtitleSearchMissingFile => '目前檔案資訊缺失，無法搜尋字幕';

  @override
  String get movieDetailSubtitleUploadMissingFile => '目前檔案資訊缺失，無法上傳字幕';

  @override
  String get movieDetailSubtitleDownloadSuccess => '下載成功';

  @override
  String movieDetailSubtitleDownloadFailed(String error) {
    return '下載字幕失敗: $error';
  }

  @override
  String get movieDetailSubtitleTaskCreated => '已建立字幕下載任務';

  @override
  String get movieDetailSubtitleTaskFailed => '建立字幕下載任務失敗，請重試';

  @override
  String get movieDetailSubtitleExternalSuffix => ' - 外掛';

  @override
  String get movieDetailSubtitleDeleteTitle => '刪除外掛字幕';

  @override
  String movieDetailSubtitleDeleteConfirm(String name) {
    return '確定要刪除 $name 外掛字幕嗎？';
  }

  @override
  String get movieDetailSubtitleDeleteSuccess => '刪除字幕成功';

  @override
  String movieDetailSubtitleDeleteFailed(String error) {
    return '刪除字幕失敗: $error';
  }

  @override
  String get movieDetailSubtitleNone => '無字幕';

  @override
  String movieDetailSubtitleLanguageLabel(String language) {
    return '$language字幕';
  }

  @override
  String get movieDetailAudioLabel => '音訊';

  @override
  String movieDetailAudioLanguageLabel(String language) {
    return '$language音訊';
  }

  @override
  String get movieDetailAudioStereo => '立體聲';

  @override
  String movieDetailRemaining(String time) {
    return '剩餘 $time';
  }

  @override
  String movieDetailSmartAnalysisStatus(String status) {
    return '智慧片頭/片尾偵測狀態：$status';
  }

  @override
  String get movieDetailDolbyVision => '杜比視界';

  @override
  String get movieDetailSubtitleLabel => '字幕';

  @override
  String get tvDetailNotFound => '找不到劇集資訊';

  @override
  String get tvDetailSeasonNotFound => '找不到分季資訊';

  @override
  String get tvDetailDescriptionTitle => '劇集簡介';

  @override
  String get tvDetailSmartAnalysis => '智慧分析片頭/片尾';

  @override
  String get tvDetailSeasonListTitle => '季列表';

  @override
  String tvDetailEpisodeNumber(String number) {
    return '第 $number 集';
  }

  @override
  String tvDetailSeasonNumber(String number) {
    return '第 $number 季';
  }

  @override
  String tvDetailSeasonEpisodeNumbers(String season, String episode) {
    return '第 $season 季 第 $episode 集';
  }

  @override
  String tvDetailEpisodeCount(String count) {
    return '共 $count 集';
  }

  @override
  String get tvDetailEpisodeSectionTitle => '選集';

  @override
  String get tvDetailUnknownSeason => '未知季';

  @override
  String tvDetailSeasonTitleSummary(String title, String count) {
    return '《$title》共 $count 季';
  }

  @override
  String get tvDetailEpisodeNoneOverview => '暫無劇集簡介';

  @override
  String tvDetailEpisodeRuntime(String minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get tvDetailRuntimeUnknown => '時長未知';

  @override
  String tvDetailScore(String score) {
    return '$score 分';
  }

  @override
  String get tvDetailPlayEpisode => '播放本集';

  @override
  String tvDetailSmartAnalysisStatus(String status) {
    return '智慧分析：$status';
  }

  @override
  String get tvDetailAnalysisFetching => '取得中';

  @override
  String get tvDetailAnalysisNotDetected => '未偵測';

  @override
  String get tvDetailAnalysisFailed => '取得失敗';

  @override
  String get tvDetailAnalysisPreparing => '準備中';

  @override
  String get tvDetailAnalysisPending => '等待中';

  @override
  String get tvDetailAnalysisInProgress => '分析中';

  @override
  String get tvDetailAnalysisPartialSuccess => '部分成功';

  @override
  String get tvDetailAnalysisCompleted => '已完成';

  @override
  String get tvDetailAnalysisStatusFailed => '失敗';

  @override
  String get mediaTypeMovie => '電影';

  @override
  String get mediaTypeTv => '電視節目';

  @override
  String get mediaTypeDirectory => '目錄';

  @override
  String get mediaTypeOther => '其他';

  @override
  String get mediaTypeLive => '電視直播';

  @override
  String get mediaTypeEpisode => '劇集';

  @override
  String get mediaTypeSeason => '季';

  @override
  String mediaSeasonCount(String count) {
    return '共 $count 季';
  }

  @override
  String mediaSeasonNumber(String number) {
    return '第 $number 季';
  }

  @override
  String mediaEpisodeCount(String count) {
    return '共 $count 集';
  }

  @override
  String mediaEpisodeDetail(String season, String episode) {
    return '第 $season 季 · 第 $episode 集';
  }

  @override
  String get cloudStorageBaiduPan => '百度網盤';

  @override
  String get cloudStorageAliyunDrive => '阿里雲盤';

  @override
  String get cloudStorage115 => '115 生活';

  @override
  String get cloudStorageQuark => '夸克網盤';

  @override
  String get cloudStorage123 => '123 雲盤';

  @override
  String get loginRememberPassword => '記住密碼';

  @override
  String get loginWebViewInjectedPlaceholder => '登入頁面';

  @override
  String get updateCurrentVersionLabel => '目前安裝版本';

  @override
  String get updateManualDownloadOpenFailed => '無法開啟手動下載頁面，請稍後重試。';

  @override
  String get updateOpenLinkFailed => '無法開啟連結，請稍後重試。';

  @override
  String updateBadgeSemanticLabel(String version) {
    return '發現新版本 $version，開啟更新詳情';
  }

  @override
  String get updateDialogTitleChecking => '檢查更新';

  @override
  String get updateDialogTitleAvailable => '發現新版本';

  @override
  String get updateDialogTitleDownloading => '正在下載更新';

  @override
  String get updateDialogTitleDownloaded => '下載完成';

  @override
  String get updateDialogTitleVerifying => '正在校驗更新';

  @override
  String get updateDialogTitleReadyToInstall => '更新已準備就緒';

  @override
  String get updateDialogTitleInstalling => '正在啟動安裝';

  @override
  String get updateDialogTitleCheckFailed => '檢查更新失敗';

  @override
  String get updateDialogTitleDownloadFailed => '下載更新失敗';

  @override
  String get updateDialogTitleVerificationFailed => '更新包校驗失敗';

  @override
  String get updateDialogTitleInstallFailed => '啟動安裝失敗';

  @override
  String get updateDialogTitleAutomaticDownloadExhausted => '自動下載未完成';

  @override
  String get updateDialogTitleNone => '應用程式更新';

  @override
  String get updateActionCheckInBackground => '背景下載';

  @override
  String get updateActionSkipVersion => '略過此版本';

  @override
  String get updateActionLater => '稍後再說';

  @override
  String get updateActionDownload => '下載更新';

  @override
  String get updateActionDownloadInBackground => '背景下載';

  @override
  String get updateActionCancelDownload => '取消下載';

  @override
  String get updateActionInstallLater => '稍後安裝';

  @override
  String get updateActionQuitAndInstall => '結束並安裝';

  @override
  String get updateActionRunInBackground => '背景執行';

  @override
  String get updateActionRetryDownload => '重新下載';

  @override
  String get updateActionRetryInstall => '重試安裝';

  @override
  String get updateActionManualDownload => '手動下載';

  @override
  String get updateActionClose => '關閉';

  @override
  String get updateStatusCheckingMessage => '正在從 GitHub Releases 取得更新資訊…';

  @override
  String get updateStatusUpToDate => '目前已是最新版本。';

  @override
  String get updateStatusDownloadedMessage => '更新包已下載完成，可以稍後安裝或立即結束並安裝。';

  @override
  String get updateStatusReadyMessage => '已找到可用的已下載更新包。';

  @override
  String get updateStatusVerifyingMessage => '正在安全校驗更新包，請稍候…';

  @override
  String get updateStatusInstallingMessage => '正在啟動系統安裝程式，請勿重複操作。';

  @override
  String get updateStatusIdleMessage => '尚未執行更新檢查。';

  @override
  String updateVersionLine(String version, String current) {
    return '版本 $version（目前 $current）';
  }

  @override
  String updatePackageSize(String size) {
    return '安裝包大小 $size';
  }

  @override
  String get updateReleaseNotesHeader => '更新內容';

  @override
  String get updateDownloadingPackage => '正在下載更新包';

  @override
  String updateDownloadedSize(String size) {
    return '已下載 $size';
  }

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateErrorRateLimited => 'GitHub API 存取頻率超限，通常稍後會自動恢復，請稍後再試。';

  @override
  String get updateErrorVerificationFailed => '更新包未通過安全校驗，請重新下載。';

  @override
  String get updateErrorCheckFailed => '暫時無法取得更新資訊，請檢查網路後重試。';

  @override
  String get updateErrorDownloadFailed => '更新包下載未完成，請稍後重試。';

  @override
  String get updateErrorInstallFailed => '無法啟動系統安裝程式，請稍後重試。';

  @override
  String get updateErrorAutomaticDownloadExhausted =>
      '自動下載多次未完成，你可以稍後重試或前往發佈頁手動下載。';

  @override
  String get updateErrorGeneric => '更新操作未完成，請稍後重試。';

  @override
  String get updateMarkdownEmpty => '本次更新未提供更新說明';

  @override
  String get updateMarkdownRemoteImageAlt => '遠端圖片';

  @override
  String updateMarkdownRemoteImageBlocked(String alt) {
    return '遠端圖片已封鎖：$alt';
  }

  @override
  String get updateMarkdownTruncatedSuffix => '\n\n更新說明過長，已截斷顯示。';

  @override
  String get loginHostOrFnIdPlaceholder => '請輸入 IP:Port、網域或 FN ID';

  @override
  String get loginHostValidationMessage => '請輸入正確的 IP、網域或 FN ID';

  @override
  String get loginHostRequiredMessage => '請輸入 IP、網域或 FN ID';

  @override
  String get loginUsernameRequiredMessage => '請輸入使用者名稱';

  @override
  String get loginPasswordRequiredMessage => '請輸入密碼';

  @override
  String get loginWebViewInitFailed => '瀏覽器元件初始化失敗，請稍後重試。';

  @override
  String get loginHostPlaceholder => '請輸入 IP、網域或 FN ID';

  @override
  String get loginPortPlaceholder => '連接埠';

  @override
  String get loginUsernameLabel => '使用者名稱';

  @override
  String get loginPasswordLabel => '密碼';

  @override
  String get loginUseNasLogin => '使用 NAS 登入';

  @override
  String get loginHttpsSecureAccess => 'HTTPS 安全存取';

  @override
  String get loginNext => '下一步';

  @override
  String get loginSignIn => '登入';

  @override
  String get loginVerifyingServer => '正在驗證伺服器...';

  @override
  String get loginInvalidCredentials => '使用者名稱或密碼錯誤';

  @override
  String loginServerHttpError(String status) {
    return '伺服器傳回錯誤（HTTP $status），請檢查服務狀態。';
  }

  @override
  String get loginSslCertificateFailed => 'SSL 憑證驗證失敗，請檢查 HTTPS 設定或伺服器憑證。';

  @override
  String get loginConnectionTimeout => '連線伺服器逾時，請確認伺服器位址或網路狀態。';

  @override
  String get loginConnectionFailed => '無法連線到伺服器，請檢查位址、連接埠或網路。';

  @override
  String get loginRequestCancelled => '登入要求已取消。';

  @override
  String get loginFailedCheckServer => '登入失敗，請檢查伺服器位址或稍後再試。';

  @override
  String get loginFailedCheckNetwork => '登入失敗，請檢查網路或伺服器設定。';

  @override
  String get loginFailedTokenEmpty => '登入失敗：Token 為空';

  @override
  String loginFailedWithError(String error) {
    return '登入失敗：$error';
  }

  @override
  String get loginAuthFailed => '認證失敗';

  @override
  String get loginAccessCodeInvalid => '存取碼錯誤';

  @override
  String get loginAccessCodeTitle => '請輸入存取碼';

  @override
  String get loginAccessCodeHint => '此伺服器啟用了存取碼，請輸入後繼續。';

  @override
  String get loginFnIdEmpty => 'FN ID 不能為空';

  @override
  String get loginHistoryTitle => '登入歷史';

  @override
  String get loginHistoryEmpty => '尚無歷史記錄';

  @override
  String get homeRetryLoad => '載入失敗，點擊重試';

  @override
  String get homeTitle => '首頁';

  @override
  String get homeContinueWatching => '繼續觀看';

  @override
  String get homeMediaLibrary => '媒體庫';

  @override
  String get homeContinueRemoved => '已從「繼續觀看」中移除';

  @override
  String get homeContinueRemoveFailed => '移除失敗';

  @override
  String homeContinueRemoveError(String error) {
    return '移除失敗：$error';
  }

  @override
  String homeDeleteDialogTitle(String title) {
    return '刪除 《$title》';
  }

  @override
  String get homeDeleteDialogBody =>
      '從媒體庫移除後，所選影片檔案將不再被掃描加入目前媒體庫中。請確認是否同時刪除關聯的影片檔案。';

  @override
  String get homeDeleteRemoveAndDeleteFile => '移除並刪除檔案';

  @override
  String get homeDeleteRemoveOnly => '僅移除';

  @override
  String get homeDeleted => '已刪除';

  @override
  String get homeDeleteFailed => '刪除失敗';

  @override
  String homeDeleteFailedWithError(String error) {
    return '刪除失敗：$error';
  }

  @override
  String get homeFavoriteRemoved => '已取消收藏';

  @override
  String get homeFavorited => '已收藏';

  @override
  String get homeMarkedUnwatched => '標記為未觀看';

  @override
  String get homeMarkedWatched => '標記為已觀看';

  @override
  String get homeActionFailed => '操作失敗';

  @override
  String homeActionFailedWithError(String error) {
    return '操作失敗，$error';
  }

  @override
  String get homeMenuRemoveFromContinue => '從「繼續觀看」中移除';

  @override
  String get homeMenuResume => '繼續播放';

  @override
  String get homeMenuRestart => '從頭開始播放';

  @override
  String get homeMenuDeleteVideo => '刪除影片';

  @override
  String get searchPlaceholder => '搜尋片名、演員';

  @override
  String get searchTabAll => '全部';

  @override
  String get searchTabMovie => '電影';

  @override
  String get searchTabTv => '電視劇';

  @override
  String get searchTabLiveChannel => '電視直播';

  @override
  String get searchTabPerson => '人物';

  @override
  String get searchTabOther => '其他';

  @override
  String get searchNoResults => '搜尋沒有結果';

  @override
  String get searchEnterKeyword => '輸入關鍵字搜尋';

  @override
  String searchWorkCount(String count) {
    return '$count 個作品';
  }

  @override
  String get searchScoreSuffix => '分';

  @override
  String searchEpisodeCount(String count) {
    return '共 $count 集';
  }

  @override
  String get personNoData => '無資料';

  @override
  String get personSectionActor => '作為演員';

  @override
  String get personSectionDirector => '作為導演';

  @override
  String get personSectionWriter => '作為編劇';

  @override
  String get personMore => '更多';

  @override
  String get personBiographyTitle => '演員簡介';

  @override
  String get commonDelete => '刪除';

  @override
  String get forgotPasswordTitle => '忘記密碼？';

  @override
  String get storageExternal => '外接儲存';

  @override
  String get storageRemoteMount => '遠端掛載';

  @override
  String storageVolumeName(String number) {
    return '儲存空間 $number';
  }

  @override
  String durationHoursMinutes(String hours, String minutes) {
    return '$hours 小時 $minutes 分鐘';
  }

  @override
  String durationHours(String hours) {
    return '$hours 小時';
  }

  @override
  String durationMinutesSeconds(String minutes, String seconds) {
    return '$minutes 分鐘 $seconds 秒';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get durationZeroMinutes => '0 分鐘';

  @override
  String authDirUserFiles(String username) {
    return '$username 的檔案';
  }

  @override
  String authDirUnknownUser(String uid) {
    return '使用者 $uid';
  }

  @override
  String get authDirNone => '無';

  @override
  String get authDirUnknown => '未知';

  @override
  String get mediaStreamAudio => '音訊';

  @override
  String get mediaStreamVideo => '視訊';

  @override
  String get mediaStreamSubtitle => '字幕';

  @override
  String get forgotPasswordBody =>
      '1. 如果您是 NAS 使用者，請嘗試以 NAS 帳號登入；\n2. 請聯絡管理員修改密碼。';

  @override
  String tvDetailEpisodeNumberTitle(String number, String title) {
    return '第 $number 集 $title';
  }

  @override
  String get movieDetailSubtitleDefaultSuffix => ' - 預設';

  @override
  String get timeJustNow => '剛剛';

  @override
  String timeMinutesAgo(String count) {
    return '$count 分鐘前';
  }

  @override
  String timeHoursAgo(String count) {
    return '$count 小時前';
  }

  @override
  String timeDaysAgo(String count) {
    return '$count 天前';
  }

  @override
  String timeWeeksAgo(String count) {
    return '$count 週前';
  }

  @override
  String timeMonthsAgo(String count) {
    return '$count 個月前';
  }

  @override
  String timeYearsAgo(String count) {
    return '$count 年前';
  }

  @override
  String get updateNotesEmpty => '暫無更新說明。';

  @override
  String updateNotesTruncated(String url) {
    return '\n\n> 更新說明已截斷。請前往 [Release 頁面]($url) 查看完整內容。';
  }

  @override
  String get navCategories => '分類';

  @override
  String get navFavorites => '收藏';

  @override
  String get navNoMediaLibrary => '暫無媒體庫';

  @override
  String get folderFallbackName => '資料夾';

  @override
  String get folderRescrap => '重新識別';

  @override
  String get folderRescrapStarted => '已發起重新識別';

  @override
  String get folderRescrapFailed => '重新識別失敗';

  @override
  String folderRescrapFailedWithError(String error) {
    return '重新識別失敗：$error';
  }

  @override
  String get folderRefreshMetadata => '重新整理中繼資料';

  @override
  String get folderRefreshMetadataStarted => '已發起重新整理中繼資料';

  @override
  String get folderRefreshMetadataFailed => '重新整理中繼資料失敗';

  @override
  String folderRefreshMetadataFailedWithError(String error) {
    return '重新整理中繼資料失敗：$error';
  }

  @override
  String get folderThisFolder => '該資料夾';

  @override
  String get folderDeleteConfirmTitle => '刪除';

  @override
  String folderDeleteConfirmBody(String title) {
    return '確定要從媒體庫刪除「$title」嗎？\n僅移除媒體庫項目，不會刪除磁碟上的檔案。';
  }

  @override
  String folderDeleteFailedWithError(String error) {
    return '刪除失敗：$error';
  }

  @override
  String folderItemCount(String count) {
    return '共 $count 項';
  }

  @override
  String get favoritesTabSingleEpisode => '單集';

  @override
  String get serverUpdateGetVersionFailed => '取得伺服器版本失敗';

  @override
  String get serverUpdateCheckFailed => '檢查伺服器更新異常';

  @override
  String serverUpdateCheckFailedWithError(String error) {
    return '檢查伺服器更新異常: $error';
  }

  @override
  String get serverUpdatePackageNotFound => '找不到伺服器更新套件';

  @override
  String get serverUpdateAssetMissing => '伺服器更新套件資產缺失';

  @override
  String get serverUpdateStarting => '開始伺服器更新...';

  @override
  String get serverUpdateFailed => '伺服器更新失敗';

  @override
  String serverUpdateFailedWithError(String error) {
    return '伺服器更新失敗: $error';
  }

  @override
  String get serverUpdateWaitingRestart => '等待伺服器重新啟動...';

  @override
  String serverUpdateSucceeded(String version) {
    return '伺服器已更新至 $version';
  }

  @override
  String get serverUpdateTimeout => '伺服器更新逾時，請檢查伺服器日誌';

  @override
  String get connectionTestInvalidUrl => 'FlyNarwhal 伺服器位址無效';

  @override
  String get connectionTestNoVersion => 'FlyNarwhal 伺服器未回傳版本號';

  @override
  String get smartAnalysisQueued => '已加入分析佇列';

  @override
  String get smartAnalysisSubmitted => '分析請求已提交';

  @override
  String smartAnalysisFailedSeasons(String seasons) {
    return '失敗劇季：$seasons';
  }

  @override
  String get smartAnalysisSubmitFailed => '分析請求提交失敗';

  @override
  String get shortcutFocusSearch => '聚焦搜尋輸入框';

  @override
  String get shortcutTogglePlayPause => '播放／暫停';

  @override
  String get shortcutMute => '靜音／取消靜音';

  @override
  String get shortcutSeekBackward => '倒轉 10 秒';

  @override
  String get shortcutSeekForward => '快轉 10 秒';

  @override
  String get shortcutVolumeUp => '提高音量';

  @override
  String get shortcutVolumeDown => '降低音量';

  @override
  String get shortcutToggleFullscreen => '切換全螢幕';

  @override
  String get shortcutExitFullscreen => '結束全螢幕';

  @override
  String get shortcutSearchNext => '下一個搜尋項目';

  @override
  String get shortcutSearchPrev => '上一個搜尋項目';

  @override
  String get shortcutSearchSelect => '選取搜尋項目';

  @override
  String get shortcutSearchSwitchTab => '切換搜尋分類';

  @override
  String get shortcutSearchExit => '結束搜尋';

  @override
  String get playerSubtitleExternalSuffix => ' - 外掛';

  @override
  String get playerSubtitleDefaultSuffix => ' - 預設';

  @override
  String playerVolumeLabel(String value) {
    return '目前音量：$value%';
  }

  @override
  String playerVolumeUnmuteLabel(String value) {
    return '解除靜音：$value%';
  }

  @override
  String get playerVolumeMute => '靜音';

  @override
  String get playerSeekRewindTo => '倒轉至';

  @override
  String get playerSeekForwardTo => '快進至';

  @override
  String playerSeekTimeToast(String label, String time) {
    return '$label：$time';
  }

  @override
  String get playerForceH264Disabled => '目前影片為 H.264';

  @override
  String get playerForceSdrDisabled => '目前影片為 SDR';

  @override
  String get playerCloudModeDirect => '網盤直連播放';

  @override
  String get playerCloudModeNasProxy => 'NAS 代理播放';

  @override
  String playerCloudModeSwitchedToast(String label) {
    return '播放方式切換至 $label';
  }

  @override
  String get playerCloudProxyFailedFallbackDirect => 'NAS 代理播放失敗，正在切換為網盤直連播放';

  @override
  String get playerInfoMissingSearchSubtitle => '目前檔案資訊缺失，無法搜尋字幕';

  @override
  String get playerInfoMissingAddNasSubtitle => '目前檔案資訊缺失，無法新增 NAS 字幕';

  @override
  String get playerInfoMissingUploadSubtitle => '目前檔案資訊缺失，無法上傳字幕';

  @override
  String get playerSubtitleDeleteTitle => '刪除外掛字幕';

  @override
  String playerSubtitleDeleteConfirm(String displayName) {
    return '確定要刪除 $displayName 外掛字幕嗎？';
  }

  @override
  String get playerSubtitleDeleteSuccess => '刪除字幕成功';

  @override
  String playerSubtitleDeleteFailed(String error) {
    return '刪除字幕失敗: $error';
  }

  @override
  String get playerSubtitleAddNasTitle => '新增 NAS 字幕檔案';

  @override
  String get playerSubtitleAddNasSuccess => 'NAS 字幕新增成功';

  @override
  String get playerSubtitleAlreadyMarked => '該檔案已被新增為字幕';

  @override
  String playerSubtitleAddNasFailed(String error) {
    return '新增 NAS 字幕失敗: $error';
  }

  @override
  String get playerSubtitleDownloadSuccess => '下載成功';

  @override
  String playerSubtitleDownloadFailed(String error) {
    return '下載字幕失敗: $error';
  }

  @override
  String get playerSubtitleTaskCreated => '已建立字幕下載任務';

  @override
  String get playerSubtitleTaskFailed => '建立字幕下載任務失敗，請重試';

  @override
  String playerSubtitleSwitchFailed(String error) {
    return '切換字幕失敗: $error';
  }

  @override
  String playerSwitchOriginalQualityFailed(String error) {
    return '切換原畫失敗: $error';
  }

  @override
  String playerLoadFailed(String error) {
    return '載入失敗: $error';
  }

  @override
  String playerToggleFullscreenFailed(String error) {
    return '切換全螢幕失敗: $error';
  }

  @override
  String playerSwitchPlaybackSettingsFailed(String error) {
    return '切換播放設定失敗: $error';
  }

  @override
  String get playerNotReady => '播放器尚未準備完成';

  @override
  String playerEnterPipFailed(String error) {
    return '進入子母畫面失敗: $error';
  }

  @override
  String playerExitPipFailed(String error) {
    return '結束子母畫面失敗: $error';
  }

  @override
  String playerSwitchQualityFailed(String error) {
    return '切換畫質失敗: $error';
  }

  @override
  String playerSwitchPlayModeFailed(String error) {
    return '切換播放方式失敗: $error';
  }

  @override
  String playerSwitchAudioFailed(String error) {
    return '切換音訊失敗: $error';
  }

  @override
  String playerSubtitleSwitchingTo(String language) {
    return '字幕正在切換至：$language';
  }

  @override
  String playerSubtitleSwitchingToFormat(String language, String format) {
    return '字幕正在切換至：$language $format';
  }

  @override
  String get playerClose => '關閉';

  @override
  String get playerBack => '返回';

  @override
  String get playerRewindTenSeconds => '倒轉 10 秒';

  @override
  String get playerForwardTenSeconds => '快進 10 秒';

  @override
  String get playerPlayPause => '播放/暫停';

  @override
  String get playerPip => '子母畫面';

  @override
  String get playerExitPip => '結束子母畫面';

  @override
  String get playerDanmakuClose => '關閉彈幕';

  @override
  String get playerDanmakuOpen => '開啟彈幕';

  @override
  String get playerPlaybackDetailsTooltip => '播放詳細資訊';

  @override
  String get playerSkipConfigSaved => '設定成功';

  @override
  String playerSkipConfigSaveFailed(String error) {
    return '設定失敗: $error';
  }

  @override
  String get playerDanmakuRequestFailed => '請求彈幕介面失敗，請檢查飛鯨服務端設定';

  @override
  String get playerSmartSkipRequestFailed => '請求智慧片頭片尾介面失敗，請檢查飛鯨服務端設定';

  @override
  String playerFeatureComingSoon(String feature) {
    return '$feature 暫未接入';
  }

  @override
  String get playerPlayErrorRetrySwitch => '播放出錯,請嘗試切換線路';

  @override
  String get playerNoPlayableLine => '該頻道沒有可用的播放線路';

  @override
  String get playerLoadFailedBackRetry => '載入失敗,請返回重試';

  @override
  String get playerPlayFailedSwitchLine => '播放失敗,請嘗試切換線路';

  @override
  String get playerLive => '直播中';

  @override
  String get playerPause => '暫停';

  @override
  String get playerPlay => '播放';

  @override
  String get playerDanmakuSettingsTooltip => '彈幕設定';

  @override
  String get playerDanmakuSettingsTitle => '彈幕設定';

  @override
  String get playerDanmakuAdvancedSettings => '進階設定';

  @override
  String playerDanmakuDisplayArea(String value) {
    return '顯示區域 $value%';
  }

  @override
  String playerDanmakuOpacity(String value) {
    return '不透明度 $value%';
  }

  @override
  String playerDanmakuFontSize(String value) {
    return '字號 $value%';
  }

  @override
  String playerDanmakuSpeed(String value) {
    return '速度 $value';
  }

  @override
  String get playerDanmakuSpeedVerySlow => '極慢';

  @override
  String get playerDanmakuSpeedSlow => '較慢';

  @override
  String get playerDanmakuSpeedNormal => '適中';

  @override
  String get playerDanmakuSpeedFast => '較快';

  @override
  String get playerDanmakuSpeedVeryFast => '極快';

  @override
  String get playerDanmakuSyncPlaybackSpeed => '彈幕速度同步播放倍速';

  @override
  String get playerDanmakuShowDebugInfo => '顯示彈幕除錯資訊';

  @override
  String get playerStrmDirectPlaying => '正在直連播放 STRM 檔案';

  @override
  String get playerCloudModeDirectDescription => '速度較快、省流';

  @override
  String get playerCloudModeNasProxyDescription => '色調或音訊異常時可嘗試切換';

  @override
  String get playerCloudPlayRecommend => '推薦';

  @override
  String get playerCloudPlayingNotice => '正在播放網盤上的檔案，播放速度和畫質取決於網盤方規則。';

  @override
  String get playerCloudSwitchNotice => '如遇播放異常，可嘗試切換播放方式。';

  @override
  String get playerPlayModeLabel => '播放方式';

  @override
  String get playerCloudFallbackName => '網盤';

  @override
  String get playerCloudPlayErrorTitle => '抱歉，播放出錯了';

  @override
  String get playerCloudSwitchQuality => '播放其他畫質';

  @override
  String get playerCloudSwitchToProxy => '切換 NAS 代理播放';

  @override
  String get playerStrmPlaybackErrorHint =>
      'STRM 直連播放異常，可能原因：網盤掛載連線中斷、觸發網盤風控、網盤限制非會員操作、瀏覽器不支援該檔案類型。';

  @override
  String get playerChannelLineFallback => '線路';

  @override
  String get playerSubtitleAddDialogTitle => '新增字幕';

  @override
  String get playerSubtitleSearchSortHint => '按相關度排序：';

  @override
  String get playerSubtitleSearchNoResults => '未搜尋到相關字幕';

  @override
  String playerSubtitleSearchDownloadCount(String count) {
    return '下載量 $count';
  }

  @override
  String get playerSubtitleSearchDownloading => '下載中';

  @override
  String get playerSubtitleSearchDownloadDone => '下載完成';

  @override
  String get playerSubtitleSearchDownload => '下載字幕';

  @override
  String get playerSubtitleDownloadSimilarForEpisodes => '為其他集下載相似字幕';

  @override
  String get playerSubtitleLanguageSimplifiedChinese => '簡體中文';

  @override
  String get playerSubtitleLanguageEnglish => '英文';

  @override
  String get playerSubtitleAdjust => '調整字幕';

  @override
  String get playerSubtitleReset => '重設';

  @override
  String get playerSubtitleOffset => '偏移';

  @override
  String get playerSubtitleOffsetMin => '-5秒';

  @override
  String get playerSubtitleOffsetMax => '+5秒';

  @override
  String get playerSubtitleSecondsSuffix => '秒';

  @override
  String get playerSubtitlePosition => '位置';

  @override
  String get playerSubtitlePositionBottom => '底部';

  @override
  String get playerSubtitlePositionTop => '頂部';

  @override
  String get playerSubtitlePositionLockedHint => '當前字幕為彈幕/特效字幕（含定位標籤），位置調整不可用';

  @override
  String get playerSubtitleFontSize => '字號';

  @override
  String get playerSubtitleFontSizeMin => '最小';

  @override
  String get playerSubtitleFontSizeMax => '最大';

  @override
  String get playerSubtitlePanelTitle => '字幕';

  @override
  String get playerSubtitleAdjustButton => '調整';

  @override
  String get playerSubtitleAddButton => '新增';

  @override
  String get playerSubtitleOff => '關閉';

  @override
  String get playerSubtitleSearchMenu => '搜尋字幕';

  @override
  String get playerSubtitleAddNasFile => '新增 NAS 字幕檔案';

  @override
  String get playerSubtitleAddLocalFile => '新增電腦字幕檔案';

  @override
  String get playerSubtitleDirectLinkMissingTitle => '直連播放缺失內建字幕';

  @override
  String get playerSubtitleDirectLinkMissingContent =>
      '由於網盤方的限制，直連轉碼播放時可能無法取得內建字幕列表。如需切換內建字幕，請切換播放方式為「NAS 代理播放」。';

  @override
  String get playerDetailSeparator => '：';

  @override
  String get playerPlayType => '播放類型';

  @override
  String get playerPlayTypeStrmDirect => 'STRM 直連播放';

  @override
  String get playerPlayTypeTranscode => '轉碼播放';

  @override
  String get playerPlayTypeDirect => '直接播放';

  @override
  String get playerTranscodeReason => '轉碼原因';

  @override
  String get playerTranscodeReasonSeparator => '；';

  @override
  String get playerPlaybackInfo => '播放資訊';

  @override
  String get playerMediaSourceInfo => '媒體源資訊';

  @override
  String get playerContainerFormat => '封裝容器';

  @override
  String get playerBufferDuration => '緩衝時長';

  @override
  String get playerAudioCodec => '音訊編碼';

  @override
  String get playerGpuEnabled => '啟用 GPU';

  @override
  String get playerDecodeMethod => '解碼方式';

  @override
  String get playerEncodeMethod => '編碼方式';

  @override
  String get playerTranscodeFrameRate => '轉碼幀率';

  @override
  String get playerDroppedFrames => '丟幀';

  @override
  String get playerCorruptedFrames => '壞幀';

  @override
  String get playerCodec => '編碼';

  @override
  String get playerDynamicRange => '動態範圍';

  @override
  String get playerFullscreenEnter => '進入全螢幕';

  @override
  String get playerFullscreenExit => '退出全螢幕';

  @override
  String get playerNextVideo => '下一個影片';

  @override
  String playerEpisodeNumber(String number) {
    return '第 $number 集';
  }

  @override
  String get playerReplay => '重播';

  @override
  String get playerUndo => '復原';

  @override
  String get playerSkipIntroAutoSkipped => '已自動跳過片頭';

  @override
  String playerSkipOutroInSeconds(int seconds) {
    return '$seconds 秒後跳過片尾';
  }

  @override
  String playerSkipOutroNextEpisodeInSeconds(int seconds) {
    return '$seconds 秒後播放下一集';
  }

  @override
  String playerSkipOutroEndInSeconds(int seconds) {
    return '$seconds 秒後結束播放';
  }

  @override
  String get playerUnknown => '未知';

  @override
  String playerAudioDefaultSuffix(String language) {
    return '$language - 預設';
  }

  @override
  String get playerSettingsWindowAspectRatioFollowVideo => '跟隨影片比例';

  @override
  String get playerSettingsAspectRatioDefault => '預設';

  @override
  String get playerSettingsAdvanced => '進階';

  @override
  String get playerSettingsAutoNext => '自動連播';

  @override
  String get playerSettingsSkipIntroOutro => '跳過片頭/片尾';

  @override
  String get playerSettingsWindowRatio => '視窗比例';

  @override
  String get playerSettingsAspectRatio => '畫面比例';

  @override
  String get playerSettingsClientDecodeMode => '客戶端解碼模式';

  @override
  String get playerSettingsAudio => '音訊';

  @override
  String get playerSettingsAudioPassthrough => '音訊直通';

  @override
  String get playerSettingsAudioPassthroughTitle => '音訊直通';

  @override
  String get playerSettingsAudioPassthroughDescription =>
      '將 AC3/DTS/EAC3/TrueHD 等壓縮音訊流原樣輸出到 HDMI/S-PDIF 外接裝置解碼。僅對原始音軌的直連播放生效，轉碼音軌會自動回落為本機解碼。';

  @override
  String get playerSettingsAudioOutputDevice => '輸出裝置';

  @override
  String get playerSettingsAudioOutputDeviceAuto => '自動（預設）';

  @override
  String get playerSettingsAudioOutputDeviceEmpty => '未偵測到可用的音訊輸出裝置';

  @override
  String get playerSettingsAdvancedTitle => '進階設定';

  @override
  String get playerSettingsHevcToH264 => 'HEVC 轉為 H.264';

  @override
  String get playerSettingsHevcToH264Description => '播放有聲音無畫面時可嘗試開啟';

  @override
  String get playerSettingsForceSdr => '色調強制映射為 SDR';

  @override
  String get playerSettingsForceSdrDescription => '畫面偏暗時可嘗試開啟，適用於不支援 HDR 的裝置';

  @override
  String get playerSettingsQuarkCdnSegment => '夸克 CDN 分片直連';

  @override
  String get playerSettingsQuarkCdnSegmentDescription =>
      '開啟後按分片預取夸克網盤直連流；關閉則使用原有直連方式';

  @override
  String get playerSettingsSmartSkip => '智能跳過';

  @override
  String get playerSettingsSkipIntroOutroBoth => '跳過片頭片尾';

  @override
  String get playerSettingsIntroConfigured => '已設定片頭';

  @override
  String get playerSettingsOutroConfigured => '已設定片尾';

  @override
  String get playerSettingsNotSet => '未設定';

  @override
  String playerSettingsSkipScope(String title, String season) {
    return '生效範圍: 《$title》 第 $season 季';
  }

  @override
  String get playerSettingsSmartSkipIntroOutro => '智能跳過片頭/片尾';

  @override
  String get playerSettingsIntroDuration => '片頭時長';

  @override
  String get playerSettingsOutroDuration => '片尾時長';

  @override
  String playerSettingsSetOutroToRemaining(String time) {
    return '將當前剩餘時長 $time 設為片尾';
  }

  @override
  String playerSettingsSetIntroToCurrent(String time) {
    return '將當前時間 $time 設為片頭';
  }

  @override
  String get playerSettingsTenMinutes => '10 分鐘';

  @override
  String get playerSettingsSliderStart => '開始';

  @override
  String get playerSettingsSliderEnd => '結束';

  @override
  String get playerSettingsDecodeAutoTip => '自動選擇硬體解碼，失敗時回退到軟體解碼。推薦。';

  @override
  String get playerSettingsDecodeSoftwareTip => '強制使用軟體解碼，相容性最好；硬解花屏/黑屏時的兜底方案。';

  @override
  String get playerSettingsDecodeCopyTip =>
      '硬體解碼但將幀拷回記憶體，可與所有濾鏡/彈幕/截圖功能共存；略費 CPU。';

  @override
  String get playerSettingsSoftwareDecode => '軟體解碼';

  @override
  String get playerSettingsCopyBackMode => '回拷模式';

  @override
  String get playerSettingsSpecifyHwdec => '指定硬體解碼器';

  @override
  String get playerSettingsNoHwdecAvailable => '未偵測到可用的硬體解碼器';

  @override
  String get playerQualityTitle => '影片畫質';

  @override
  String get playerQualityOriginal => '原畫';

  @override
  String get playerQualityCustom => '自訂';

  @override
  String get playerQualityCustomTitle => '自訂影片畫質';

  @override
  String get playerQualityDirectUnsupported => '直連播放暫不支援此畫質';

  @override
  String get playerQualityLowRiskHint => '此選項風控機率相對較低，建議優先選擇';

  @override
  String get playerQualityOriginalNoAudioHint => '直連播放原畫無聲音';

  @override
  String get playerQualityOriginalNoAudioTooltip =>
      '由於播放器對音訊編碼格式的支援有限，直連播放原畫可能出現無聲音的情況。可嘗試切換播放方式為「NAS 代理播放」。';

  @override
  String get playerSpeedLabel => '倍速';

  @override
  String get playerSettingsAuto => '自動';

  @override
  String get playerTranscodeReasonLowerQuality => '依影片畫質設定降低畫質';

  @override
  String get playerTranscodeReasonSubtitleBurn => '字幕燒錄';

  @override
  String get playerTranscodeReasonSubtitleToVtt => '字幕轉為 vtt 切片';

  @override
  String get playerTranscodeReasonVideoFormat => '視訊格式轉換';

  @override
  String get playerTranscodeReasonAudioFormat => '音訊格式轉換';

  @override
  String get playerTranscodeReasonToneMapping => '色調映射';

  @override
  String get playerDecodeMethodSoftware => '軟解碼';

  @override
  String get playerDecodeMethodQsv => 'QSV 解碼';

  @override
  String get playerDecodeMethodVaapi => 'VAAPI 解碼';

  @override
  String get playerDecodeMethodNvdec => 'NVDEC 解碼';

  @override
  String get playerDecodeMethodRkmpp => 'RKMPP 解碼';

  @override
  String get playerEncodeMethodSoftware => '軟編碼';

  @override
  String get playerEncodeMethodQsv => 'QSV 編碼';

  @override
  String get playerEncodeMethodQsvLowPower => 'QSV 低電壓編碼';

  @override
  String get playerEncodeMethodVaapi => 'VAAPI 編碼';

  @override
  String get playerEncodeMethodNvenc => 'NVENC 編碼';

  @override
  String get playerEncodeMethodRkmpp => 'RKMPP 編碼';

  @override
  String get smartAnalysisQueuedLoading => '片頭／片尾分析任務已提交';

  @override
  String get smartAnalysisCloudOrStrmRejected => '網盤或 STRM 影片無法使用「智慧分析片頭／片尾」功能';

  @override
  String get playerSkipSegmentIntro => '片頭';

  @override
  String get playerSkipSegmentRecap => '前情提要';

  @override
  String get playerSkipSegmentOutro => '片尾';

  @override
  String get playerSkipSegmentPreview => '下集預告';

  @override
  String get playerSkipSegmentCommercial => '廣告';

  @override
  String get playerSkipSegmentGeneric => '片段';

  @override
  String playerSkipSegmentJoined(String parts) {
    return '$parts';
  }

  @override
  String playerSkipSegmentInSeconds(String seconds, String subject) {
    return '$seconds 秒後跳過$subject';
  }

  @override
  String playerSkipAutoSkipped(String subject) {
    return '已自動跳過$subject';
  }

  @override
  String get playerSettingsSkipRecap => '跳過前情提要';

  @override
  String get playerSettingsSkipPreview => '跳過下集預告';

  @override
  String get playerSettingsSkipCommercial => '跳過廣告';

  @override
  String get playerSettingsSmartSkipConfig => '智慧跳過設定';

  @override
  String get playerSettingsSkipIntroOnly => '跳過片頭';

  @override
  String get playerSettingsSkipOutroOnly => '跳過片尾';

  @override
  String get playerSkipSegmentConnector => '與';

  @override
  String get smartSkipConfigTitle => '智慧跳過設定';

  @override
  String get smartSkipSave => '儲存';

  @override
  String get smartSkipSaved => '智慧跳過設定已儲存';

  @override
  String get smartSkipSaveFailed => '儲存失敗';

  @override
  String get smartSkipLoginRequired => '請先登入後再設定';

  @override
  String get smartSkipLoadFailed => '伺服器設定載入失敗，目前顯示預設設定';

  @override
  String get smartSkipDetectMode => '偵測模式';

  @override
  String get smartSkipAnimeMode => '動漫模式';

  @override
  String get smartSkipPreferChromaprint => '優先指紋比對';

  @override
  String get smartSkipAlternativeBlackFrame => '備用黑畫面分析器';

  @override
  String get smartSkipDetectIntro => '偵測片頭';

  @override
  String get smartSkipDetectOutro => '偵測片尾';

  @override
  String get smartSkipDetectRecap => '偵測前情提要';

  @override
  String get smartSkipDetectPreview => '偵測下集預告';

  @override
  String get smartSkipDetectCommercial => '偵測廣告';

  @override
  String get smartSkipAdvanced => '進階';

  @override
  String get smartSkipDurationLimit => '時長限制（秒）';

  @override
  String get smartSkipBoundaryOffset => '邊界偏移（秒）';

  @override
  String get smartSkipIntroStartOffset => '片頭開始偏移';

  @override
  String get smartSkipIntroEndOffset => '片頭結束偏移';

  @override
  String get smartSkipIntroMinDuration => '片頭最短時長';

  @override
  String get smartSkipIntroMaxDuration => '片頭最長時長';

  @override
  String get smartSkipOutroMinDuration => '片尾最短時長';

  @override
  String get smartSkipOutroMaxDuration => '片尾最長時長';

  @override
  String get smartSkipOutroEndOffset => '片尾結束偏移';

  @override
  String get smartSkipRestoreDefaults => '還原預設';

  @override
  String get playerSettingsSmartSkipIntro => '跳過片頭';

  @override
  String get playerSettingsSmartSkipOutro => '跳過片尾';

  @override
  String get smartSkipAnalysisFailedRetry => '分析請求提交失敗，請稍後重試';

  @override
  String get smartSkipLoadConfigFailed => '載入智慧跳過設定失敗';

  @override
  String get smartSkipSaveConfigFailed => '儲存智慧跳過設定失敗';

  @override
  String get smartSkipConfigConfigure => '設定';

  @override
  String get settingsSmartSkipConfigCaption => '伺服器智慧分析片頭片尾的參數';
}
