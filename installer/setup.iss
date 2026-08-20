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
#define MyNativeHelperExecutable "FlyNarwhalInstallHelper.exe"
#define MyProtectedHelperExecutable "FlyNarwhalProtectedHelper.exe"
#define MyRecoveryHostExecutable "FlyNarwhalRecoveryHost.exe"
#define MyPreviousUpdaterExecutable "updater.exe"
#define MyLegacyUpdaterExecutable "flynarwhal-updater.exe"
#define MyOlderUpdaterExecutable "fntv-updater.exe"
#define MyInstallerIcon "..\\windows\\runner\\resources\\app_icon.ico"

#if !DirExists(FlutterBundleDir)
  #error FlutterBundleDir does not exist.
#endif
#if !FileExists(FlutterBundleDir + "\\" + MyAppExecutable)
  #error Flutter bundle is missing FlyNarwhal.exe.
#endif
#if !FileExists(FlutterBundleDir + "\\" + MyNativeHelperExecutable)
  #error Flutter bundle is missing FlyNarwhalInstallHelper.exe.
#endif
#if !FileExists(FlutterBundleDir + "\\" + MyProtectedHelperExecutable)
  #error Flutter bundle is missing FlyNarwhalProtectedHelper.exe.
#endif
#if !FileExists(FlutterBundleDir + "\\" + MyRecoveryHostExecutable)
  #error Flutter bundle is missing FlyNarwhalRecoveryHost.exe.
#endif
#if FileExists(FlutterBundleDir + "\\" + MyPreviousUpdaterExecutable)
  #error Flutter bundle still contains a forbidden legacy updater executable.
#endif
#if FileExists(FlutterBundleDir + "\\" + MyLegacyUpdaterExecutable)
  #error Flutter bundle still contains a forbidden legacy updater executable.
#endif
#if FileExists(FlutterBundleDir + "\\" + MyOlderUpdaterExecutable)
  #error Flutter bundle still contains a forbidden legacy updater executable.
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
Source: "{#FlutterBundleDir}\{#MyNativeHelperExecutable}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#FlutterBundleDir}\{#MyProtectedHelperExecutable}"; DestDir: "{localappdata}\FlyNarwhal\updater\protected"; Flags: ignoreversion
Source: "{#FlutterBundleDir}\{#MyRecoveryHostExecutable}"; DestDir: "{localappdata}\FlyNarwhal\updater\protected"; Flags: ignoreversion
Source: "{#FlutterBundleDir}\*"; DestDir: "{app}"; Excludes: "{#MyAppExecutable},{#MyNativeHelperExecutable},{#MyProtectedHelperExecutable},{#MyRecoveryHostExecutable},{#MyPreviousUpdaterExecutable},{#MyLegacyUpdaterExecutable},{#MyOlderUpdaterExecutable}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: files; Name: "{app}\{#MyPreviousUpdaterExecutable}"
Type: files; Name: "{app}\{#MyLegacyUpdaterExecutable}"
Type: files; Name: "{app}\{#MyOlderUpdaterExecutable}"

[UninstallDelete]
Type: files; Name: "{app}\{#MyNativeHelperExecutable}"
Type: files; Name: "{app}\{#MyPreviousUpdaterExecutable}"
Type: files; Name: "{app}\{#MyLegacyUpdaterExecutable}"
Type: files; Name: "{app}\{#MyOlderUpdaterExecutable}"
Type: files; Name: "{localappdata}\FlyNarwhal\updater\protected\{#MyProtectedHelperExecutable}"
Type: files; Name: "{localappdata}\FlyNarwhal\updater\protected\{#MyRecoveryHostExecutable}"
Type: files; Name: "{localappdata}\FlyNarwhal\updater\protected\endpoint-policy.json"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExecutable}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExecutable}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{app}\{#MyAppExecutable}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function JsonEscape(const Value: String): String;
var
  Temp: String;
begin
  // StringChangeEx mutates a var string and returns an integer count.
  Temp := Value;
  StringChangeEx(Temp, '\', '\\', True);
  StringChangeEx(Temp, '"', '\"', True);
  Result := Temp;
end;

procedure WriteProtectedEndpointMetadata();
var
  ProtectedRoot: String;
  ProtectedHelperPath: String;
  RecoveryHostPath: String;
  PolicyPath: String;
  ProtectedHelperSha: String;
  RecoveryHostSha: String;
  PolicyJson: String;
begin
  ProtectedRoot := ExpandConstant('{localappdata}\FlyNarwhal\updater\protected');
  ProtectedHelperPath := ProtectedRoot + '\{#MyProtectedHelperExecutable}';
  RecoveryHostPath := ProtectedRoot + '\{#MyRecoveryHostExecutable}';
  PolicyPath := ProtectedRoot + '\endpoint-policy.json';
  ProtectedHelperSha := GetSHA256OfFile(ProtectedHelperPath);
  RecoveryHostSha := GetSHA256OfFile(RecoveryHostPath);
  PolicyJson :=
    '{"schemaVersion":1,"endpointVersion":"{#MyAppVersion}","protectedRoot":"' +
    JsonEscape(ProtectedRoot) + '"}';
  SaveStringToFile(PolicyPath, PolicyJson, False);
  RegWriteDWordValue(HKCU, 'Software\JankinWu\FlyNarwhal\Updater\Endpoint\Current',
    'SchemaVersion', 1);
  RegWriteStringValue(HKCU, 'Software\JankinWu\FlyNarwhal\Updater\Endpoint\Current',
    'EndpointVersion', '{#MyAppVersion}');
  RegWriteStringValue(HKCU, 'Software\JankinWu\FlyNarwhal\Updater\Endpoint\Current',
    'ProtectedHelperPath', ProtectedHelperPath);
  RegWriteStringValue(HKCU, 'Software\JankinWu\FlyNarwhal\Updater\Endpoint\Current',
    'ProtectedHelperSha256', ProtectedHelperSha);
  RegWriteStringValue(HKCU, 'Software\JankinWu\FlyNarwhal\Updater\Endpoint\Current',
    'RecoveryHostPath', RecoveryHostPath);
  RegWriteStringValue(HKCU, 'Software\JankinWu\FlyNarwhal\Updater\Endpoint\Current',
    'RecoveryHostSha256', RecoveryHostSha);
  RegWriteStringValue(HKCU, 'Software\JankinWu\FlyNarwhal\Updater\Endpoint\Current',
    'PolicyPath', PolicyPath);
  if DirExists(ExpandConstant('{localappdata}\FlyNarwhal\updates\worker-runtime')) then
  begin
    DelTree(ExpandConstant('{localappdata}\FlyNarwhal\updates\worker-runtime'), True, True, True);
  end;
  if DirExists(ExpandConstant('{localappdata}\FlyNarwhal\updates\recovery-runtime')) then
  begin
    DelTree(ExpandConstant('{localappdata}\FlyNarwhal\updates\recovery-runtime'), True, True, True);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    WriteProtectedEndpointMetadata();
  end;
end;
