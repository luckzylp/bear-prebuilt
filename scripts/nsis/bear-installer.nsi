; NSIS Installer Script for Bear
; Final, stable version (CI-friendly, no custom string hacks)

;--------------------------------
; App metadata

!define APP_NAME "Bear"
!ifndef APP_VERSION
  !define APP_VERSION "0.0.0"
!endif
!define PUBLISHER "Bear Development Team"
!define INSTALL_DIR "C:\Program Files\Bear"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
!define BASE_DIR "..\..\Bear"

!ifndef TARGET_DIR
  !define TARGET_DIR "target\release"
!endif

;--------------------------------
; Includes

!include "MUI2.nsh"
!include "x64.nsh"
!include "WinMessages.nsh"
!include "FileFunc.nsh"
!include "EnvVarUpdate.nsh"

!insertmacro GetSize

;--------------------------------
; General configuration

Name "${APP_NAME} ${APP_VERSION}"
OutFile "bear-${APP_VERSION}-windows-installer.exe"
InstallDir "${INSTALL_DIR}"
InstallDirRegKey HKLM "Software\${APP_NAME}" "InstallDir"

RequestExecutionLevel admin
SetCompressor /SOLID lzma

;--------------------------------
; UI configuration

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install-blue.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall-blue.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\nsis-r.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\win.bmp"

;--------------------------------
; Pages

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${BASE_DIR}\LICENSE.txt"

!define MUI_PAGE_CUSTOMFUNCTION_PRE DirectoryPre
!insertmacro MUI_PAGE_DIRECTORY

!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Lock install directory (fixed path)

Function DirectoryPre
    FindWindow $0 "#32770" "" $HWNDPARENT
    GetDlgItem $1 $0 1019 ; Browse button
    EnableWindow $1 0
    GetDlgItem $1 $0 1001 ; Path edit box
    EnableWindow $1 0
FunctionEnd

;--------------------------------
; Installer section

Section "Bear Core Files" SecCore
    SectionIn RO

    SetOutPath "$INSTDIR"

    ; Executables
    File /oname=bear.exe "${BASE_DIR}\${TARGET_DIR}\bear.exe"

    IfFileExists "${BASE_DIR}\${TARGET_DIR}\wrapper.exe" 0 +2
    File /oname=wrapper.exe "${BASE_DIR}\${TARGET_DIR}\wrapper.exe"

    ; DLLs
    IfFileExists "${BASE_DIR}\${TARGET_DIR}\*.dll" 0 +2
    File "${BASE_DIR}\${TARGET_DIR}\*.dll"

    ; Docs
    IfFileExists "${BASE_DIR}\README.md" 0 +2
    File "${BASE_DIR}\README.md"

    IfFileExists "${BASE_DIR}\LICENSE.txt" 0 +2
    File /oname=LICENSE.txt "${BASE_DIR}\LICENSE.txt"

    ; Registry (install info)
    WriteRegStr HKLM "Software\${APP_NAME}" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "Software\${APP_NAME}" "Version" "${APP_VERSION}"

    ; Uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Add/Remove Programs
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\bear.exe"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1

    ; Estimated size (KB)
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "EstimatedSize" "$0"

    ; Add to system PATH
    ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR"

SectionEnd

;--------------------------------
; Uninstaller

Section "Uninstall"

    ; Remove from PATH
    ${EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR"

    ; Files
    Delete "$INSTDIR\bear.exe"
    Delete "$INSTDIR\wrapper.exe"
    Delete "$INSTDIR\*.dll"
    Delete "$INSTDIR\README.md"
    Delete "$INSTDIR\LICENSE.txt"
    Delete "$INSTDIR\Uninstall.exe"

    ; Directory
    RMDir "$INSTDIR"

    ; Registry
    DeleteRegKey HKLM "${UNINSTALL_KEY}"
    DeleteRegKey HKLM "Software\${APP_NAME}"

SectionEnd
