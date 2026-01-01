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

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\swaloka_looping_tool.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; Include VC++ Redistributable installer (optional - skip if not present in build)
; Download from https://aka.ms/vs/17/release/vc_redist.x64.exe and place in windows folder to bundle it
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall skipifsourcedoesntexist

[Icons]
Name: "{group}\Swaloka Looping Tool"; Filename: "{app}\swaloka_looping_tool.exe"
Name: "{autodesktop}\Swaloka Looping Tool"; Filename: "{app}\swaloka_looping_tool.exe"; Tasks: desktopicon

[Run]
; Install VC++ Redistributable silently if needed and if bundled
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Runtime..."; Check: VCRedistNeedsInstall; Flags: waituntilterminated skipifdoesntexist
Filename: "{app}\swaloka_looping_tool.exe"; Description: "{cm:LaunchProgram,Swaloka Looping Tool}"; Flags: nowait postinstall skipifsilent

[Code]
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
