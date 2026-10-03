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
}
