#define MyAppName "飞牛影视"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "JankinWu"
#define MyAppExeName "FnMedia.exe"
#define MyAppPackageName "FnMedia"

#ifndef MyAppArch
  #if GetEnv('PROCESSOR_ARCHITEW6432') == 'AMD64' || GetEnv('PROCESSOR_ARCHITECTURE') == 'AMD64'
    #define MyAppArch "amd64"
  #elif GetEnv('PROCESSOR_ARCHITEW6432') == 'ARM64' || GetEnv('PROCESSOR_ARCHITECTURE') == 'ARM64'
    #define MyAppArch "aarch64"
  #else
    #define MyAppArch "x86"
  #endif
#endif

#pragma encoding("utf-8")

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{9A262498-6C63-4816-A346-056028719600}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppPackageName}
DisableProgramGroupPage=yes
; Remove the following line if you want the standard folder selection
DisableDirPage=no

OutputDir=.
OutputBaseFilename=FnMedia_Setup_{#MyAppArch}_{#MyAppVersion}
SetupIconFile=favicon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
#if MyAppArch == "amd64" || MyAppArch == "aarch64"
ArchitecturesAllowed=x64 arm64
ArchitecturesInstallIn64BitMode=x64 arm64
#endif

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; NOTE: You must run "./gradlew createReleaseDistributable" before compiling this script
Source: "..\composeApp\build\compose\binaries\main-release\app\{#MyAppPackageName}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
