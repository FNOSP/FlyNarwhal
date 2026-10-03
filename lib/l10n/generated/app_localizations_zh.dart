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
}
