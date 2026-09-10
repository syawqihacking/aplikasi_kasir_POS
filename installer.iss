; Inno Setup installer — Mesya Mart (customerbandung.exe), AppVersion 1.0.0 dari pubspec.yaml.
; Model benar: install per-user TANPA admin, app jalan dari Program Files tanpa error DB.
; - DB ditulis ke %AppData% via getApplicationSupportDirectory() + setDatabasesPath()
;   (lihat lib/database/database_helper.dart -> ensureStorageReady()), BUKAN folder install.
;
; Yang DIBUANG dari script user (jangan dikembalikan):
; - Izin level admin -> diganti lowest (mode admin memaksa UAC + install ke
;   Program Files yang read-only untuk user biasa = SQLITE_CANTOPEN / Access denied).
; - [Dirs] {app}\dart_tool -> DIBUANG. Folder install tidak boleh ditulis saat runtime;
;   folder dart_tool adalah artifact dev (lokasi default ffi lama), bukan data runtime.
; - [Run] perintah grant-ACL Windows -> DIBUANG. Melonggarkan ACL Program Files itu salah
;   secara keamanan dan tidak diperlukan karena DB sudah di %AppData%.
; - Path absolut mesin developer (folder Users di drive sistem) -> diganti path
;   RELATIF terhadap root repo.
; - AppId kurung ganda -> diperbaiki satu kurung (format GUID Inno yang valid).

#define MyAppName "Mesya Mart"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Maz_uqhy"
#define MyAppURL "https://github.com/syawqihacking/aplikasi_kasir_POS"
#define MyAppExeName "customerbandung.exe"
#define ReleaseDir "build\windows\x64\runner\Release"
#define AppIconFile "windows\runner\resources\app_icon.ico"

[Setup]
AppId={8D980621-83FD-41F1-AFA6-19196A50FAA0}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile={#AppIconFile}
OutputDir=installer-output
OutputBaseFilename=CustomerBandung_Setup_v{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; HANYA hasil flutter build windows --release (exe + dll + data/).
; Tanpa folder dart_tool / lib / windows-source — itu source/dev artifact, bukan runtime.
Source: "{#ReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
