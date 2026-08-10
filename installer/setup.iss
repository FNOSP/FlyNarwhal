#pragma encoding("utf-8")

#define MyAppId "{{9A262498-6C63-4816-A346-056028719600}"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MyAppArch
  #define MyAppArch "amd64"
#endif
#ifndef FlutterBundleDir
  #if MyAppArch == "aarch64"
    #define FlutterBundleDir "..\\build\\windows\\arm64\\runner\\Release"
  #else
    #define FlutterBundleDir "..\\build\\windows\\x64\\runner\\Release"
  #endif
#endif

#define MyAppName "飞鲸影视"
#define MyAppPublisher "JankinWu"
#define MyAppExecutable "FlyNarwhal.exe"
#define MyUpdaterExecutable "updater.exe"
#define MyPreviousUpdaterExecutable "flynarwhal-updater.exe"
#define MyLegacyUpdaterExecutable "fntv-updater.exe"
#define MyInstallerIcon "..\\windows\\runner\\resources\\app_icon.ico"

#if !DirExists(FlutterBundleDir)
  #error FlutterBundleDir does not exist.
#endif
#if !FileExists(FlutterBundleDir + "\\" + MyAppExecutable)
  #error Flutter bundle is missing FlyNarwhal.exe.
#endif
#if !FileExists(FlutterBundleDir + "\\" + MyUpdaterExecutable)
  #error Flutter bundle is missing updater.exe.
#endif
#if FileExists(FlutterBundleDir + "\\" + MyPreviousUpdaterExecutable)
  #error Flutter bundle still contains the previous updater executable.
#endif
#if FileExists(FlutterBundleDir + "\\" + MyLegacyUpdaterExecutable)
  #error Flutter bundle still contains the legacy updater executable.
#endif
#if !FileExists(MyInstallerIcon)
  #error Installer icon file does not exist.
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\FlyNarwhal
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=FlyNarwhal_Setup_Windows_{#MyAppArch}_{#MyAppVersion}
SetupIconFile={#MyInstallerIcon}
UninstallDisplayIcon={app}\{#MyAppExecutable}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
#if MyAppArch == "amd64"
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#elif MyAppArch == "aarch64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
  #error Unsupported Windows architecture. Only amd64 and aarch64 are allowed.
#endif

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"

[Files]
Source: "{#FlutterBundleDir}\{#MyAppExecutable}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#FlutterBundleDir}\{#MyUpdaterExecutable}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#FlutterBundleDir}\*"; DestDir: "{app}"; Excludes: "{#MyAppExecutable},{#MyUpdaterExecutable},{#MyPreviousUpdaterExecutable},{#MyLegacyUpdaterExecutable}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExecutable}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExecutable}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{app}\{#MyAppExecutable}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
