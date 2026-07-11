#define MyAppId "{9A262498-6C63-4816-A346-056028719600}"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MyAppArch
  #define MyAppArch "amd64"
#endif
#ifndef FlutterBundleDir
  #define FlutterBundleDir "..\\build\\windows\\x64\\runner\\Release"
#endif

#define MyAppName "飞鲸影视"
#define MyAppPublisher "JankinWu"
#define MyAppExecutable "fly_narwhal.exe"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\FlyNarwhal
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=FlyNarwhal_Setup_Windows_{#MyAppArch}_{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
#if MyAppArch == "amd64" || MyAppArch == "aarch64"
ArchitecturesAllowed=x64 arm64
ArchitecturesInstallIn64BitMode=x64 arm64
#endif

[Files]
Source: "{#FlutterBundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExecutable}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExecutable}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务："

[Run]
Filename: "{app}\{#MyAppExecutable}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent
