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
  String get settingsPrivacyGitHubProxyCaption => '仅用于安装包下载，默认关闭';

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
  String get settingsPrivacyGitHubProxyCaption => '僅用於安裝檔下載，預設關閉';

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
}
