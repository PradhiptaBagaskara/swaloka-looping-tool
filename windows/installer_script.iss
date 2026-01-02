[Setup]
AppId={{8B9E8FB6-A255-4A57-7C71-F3D1EAF483A1}
AppName=Swaloka Looping Tool
AppVersion=1.0.0
AppPublisher=com.swaloka
DefaultDirName={autopf}\Swaloka Looping Tool
DefaultGroupName=Swaloka Looping Tool
AllowNoIcons=yes
OutputDir=..\
OutputBaseFilename=Swaloka_Looping_Tool_Windows_Installer
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "installffmpeg"; Description: "Install FFmpeg (required for video processing)"; GroupDescription: "Dependencies:"; Flags: checkablealone

[Files]
Source: "..\build\windows\x64\runner\Release\swaloka_looping_tool.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; Include VC++ Redistributable installer (optional - skip if not present in build)
; Download from https://aka.ms/vs/17/release/vc_redist.x64.exe and place in windows folder to bundle it
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall skipifsourcedoesntexist
; Include FFmpeg setup scripts
Source: "setup_ffmpeg.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "setup_ffmpeg.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Swaloka Looping Tool"; Filename: "{app}\swaloka_looping_tool.exe"
Name: "{autodesktop}\Swaloka Looping Tool"; Filename: "{app}\swaloka_looping_tool.exe"; Tasks: desktopicon

[Run]
; Install VC++ Redistributable silently if needed and if bundled
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Runtime..."; Check: VCRedistNeedsInstall; Flags: waituntilterminated skipifdoesntexist
; Install FFmpeg if task is checked and not already installed
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\setup_ffmpeg.ps1"" -Silent -AddToSystemPath"; StatusMsg: "Installing FFmpeg..."; Tasks: installffmpeg; Check: ShouldInstallFFmpeg; Flags: waituntilterminated runhidden
Filename: "{app}\swaloka_looping_tool.exe"; Description: "{cm:LaunchProgram,Swaloka Looping Tool}"; Flags: nowait postinstall skipifsilent

[Code]
var
  FFmpegCheckResult: Integer;
  FFmpegAlreadyInstalled: Boolean;

function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Check if FFmpeg is already installed
  FFmpegAlreadyInstalled := Exec('cmd.exe', '/c ffmpeg -version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
  Result := True;
end;

function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  // Check if VC++ 2015-2022 Redistributable is installed (x64)
  // Registry key for VC++ 14.x (2015-2022)
  Result := True;
  if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
  begin
    // Version format: v14.xx.xxxxx - check if major version >= 14.29 (VS 2019 16.10+)
    if (CompareStr(Version, 'v14.29') >= 0) then
      Result := False;
  end;

  // Also skip if the redistributable file wasn't bundled
  if Result then
    Result := FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe'));
end;

function ShouldInstallFFmpeg: Boolean;
begin
  // Only install if not already installed
  Result := not FFmpegAlreadyInstalled;
end;

function FFmpegStatusMessage: String;
begin
  if FFmpegAlreadyInstalled then
    Result := 'FFmpeg is already installed on your system.'
  else
    Result := 'FFmpeg is not installed. It is required for video processing.';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  // On the Ready page, show FFmpeg status
  if CurPageID = wpReady then
  begin
    if not FFmpegAlreadyInstalled then
    begin
      if not IsTaskSelected('installffmpeg') then
      begin
        if MsgBox('FFmpeg is not installed and is required for this application to work.' + #13#10#13#10 +
                  'Do you want to install FFmpeg now?' + #13#10#13#10 +
                  'This will download and install FFmpeg automatically.',
                  mbConfirmation, MB_YESNO) = IDYES then
        begin
          WizardForm.TasksList.Checked[1] := True; // Check the FFmpeg task
        end;
      end;
    end;
  end;
end;
