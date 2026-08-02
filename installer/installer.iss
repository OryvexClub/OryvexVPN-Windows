#define MyAppName "OryvexVPN"
#define MyAppExeName "warp_vpn_app.exe"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "OryvexVPN"
#define MyAppURL "https://oryvex.com"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{5E2B7B0E-9F0A-4F49-8E4E-9C0A7E9E7A11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
OutputDir=Output
OutputBaseFilename=OryvexVPN-Setup-v{#MyAppVersion}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupLogging=yes
CloseApplications=yes
RestartApplications=no
MinVersion=10.0
LicenseFile=..\LICENSE
ShowLanguageDialog=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; Name: "farsi"; MessagesFile: "compiler:Languages\\Farsi.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "quicklaunchicon"; Description: "Create a &Quick Launch icon"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start {#MyAppName} when Windows starts"; GroupDescription: "Startup Options:"

[Files]
Source: "{#ReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallRun]
Filename: "taskkill"; Parameters: "/F /IM {#MyAppExeName}"; Flags: runhidden; StatusMsg: "Stopping {#MyAppName}..."
Filename: "sc"; Parameters: "stop WireGuardTunnel$OryvexVPN"; Flags: runhidden
Filename: "sc"; Parameters: "delete WireGuardTunnel$OryvexVPN"; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"

[Code]
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  Result := True;

  // Check if app is running
  if CheckForMutexes('OryvexVPN_SingleInstance') then
  begin
    if MsgBox('OryvexVPN is currently running. Setup must close it to continue.' + #13#10 + #13#10 +
              'Click OK to close OryvexVPN and continue, or Cancel to exit setup.',
              mbConfirmation, MB_OKCANCEL) = IDOK then
    begin
      Exec('taskkill', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(1000);
      Result := True;
    end
    else
      Result := False;
  end;
end;

function InitializeUninstall(): Boolean;
var
  ResultCode: Integer;
begin
  Result := True;

  // Stop the app before uninstalling
  Exec('taskkill', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(500);

  // Stop and remove WireGuard service
  Exec('sc', 'stop WireGuardTunnel$OryvexVPN', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(500);
  Exec('sc', 'delete WireGuardTunnel$OryvexVPN', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;
