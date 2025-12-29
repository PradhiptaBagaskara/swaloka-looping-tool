[Setup]
AppId={{8B9E8FB6-A255-4A57-7C71-F3D1EAF483A1}
AppName=Swaloka Looping Tool
AppVersion=1.0.0
AppPublisher=com.swaloka
DefaultDirName={autopf}\Swaloka Looping Tool
DefaultGroupName=Swaloka Looping Tool
AllowNoIcons=yes
OutputDir=..\..\
OutputBaseFilename=Swaloka_Looping_Tool_Windows_Installer
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\swaloka_looping_tool.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Swaloka Looping Tool"; Filename: "{app}\swaloka_looping_tool.exe"
Name: "{autodesktop}\Swaloka Looping Tool"; Filename: "{app}\swaloka_looping_tool.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\swaloka_looping_tool.exe"; Description: "{cm:LaunchProgram,Swaloka Looping Tool}"; Flags: nowait postinstall skipifsilent
