; ==========================================
; Bear Installer (x64 / ARM64 compatible)
; Aligned with Bear v3+ Windows layout (bear/INSTALL.md and
; bear/src/installation.rs): only bear-driver.exe and bear-wrapper.exe
; are produced. The `bear` user command is a generated .cmd shim.
; ==========================================

Unicode true
RequestExecutionLevel admin
SetCompressor /SOLID lzma

!define APP_NAME "Bear"
!ifndef APP_VERSION
  !define APP_VERSION "0.0.0"
!endif
!define PUBLISHER "Bear Development Team"
!define INSTALL_DIR "C:\Program Files\Bear"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
!define BASE_DIR "..\..\Bear"

!ifndef TARGET_TRIPLE
  !error "TARGET_TRIPLE not defined (x86_64-pc-windows-msvc / aarch64-pc-windows-msvc)"
!endif

!define TARGET_DIR "target\${TARGET_TRIPLE}\release"

; ------------------------------------------
; Includes

!include "MUI2.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"

!insertmacro GetSize

; ------------------------------------------
; Metadata

Name "${APP_NAME} ${APP_VERSION}"
OutFile "bear-${APP_VERSION}-${TARGET_TRIPLE}-installer.exe"
InstallDir "${INSTALL_DIR}"
InstallDirRegKey HKLM "Software\${APP_NAME}" "InstallDir"

; ------------------------------------------
; UI

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install-blue.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall-blue.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${BASE_DIR}\LICENSE.txt"

!define MUI_PAGE_CUSTOMFUNCTION_PRE DisableDirPage
!insertmacro MUI_PAGE_DIRECTORY

!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ------------------------------------------
; Disable directory change (fixed install dir)

Function DisableDirPage
    FindWindow $0 "#32770" "" $HWNDPARENT
    GetDlgItem $1 $0 1019
    EnableWindow $1 0
    GetDlgItem $1 $0 1001
    EnableWindow $1 0
FunctionEnd

; ------------------------------------------
; Architecture sanity check

Function .onInit
    ${If} ${RunningX64}
        StrCmp "${TARGET_TRIPLE}" "x86_64-pc-windows-msvc" ok_arch 0
        MessageBox MB_ICONSTOP "This installer is for x86_64, but you are on a different architecture."
        Abort
    ${Else}
        StrCmp "${TARGET_TRIPLE}" "aarch64-pc-windows-msvc" ok_arch 0
        MessageBox MB_ICONSTOP "This installer requires 64-bit Windows."
        Abort
    ${EndIf}
ok_arch:
FunctionEnd

; ------------------------------------------
; Install section

Section "Bear Core" SecCore
    SectionIn RO
    SetOutPath "$INSTDIR"

    DetailPrint "Including bear-driver.exe"
    File "${BASE_DIR}\${TARGET_DIR}\bear-driver.exe"

    DetailPrint "Including bear-wrapper.exe"
    File "${BASE_DIR}\${TARGET_DIR}\bear-wrapper.exe"

    ; Generated `bear` shim (cmd). Calls bear-driver.exe by relative path
    ; so it works regardless of the absolute install location.
    FileOpen $0 "$INSTDIR\bear.cmd" w
    FileWrite $0 "@echo off$\r$\n"
    FileWrite $0 "$\"%~dp0bear-driver.exe$\" %*$\r$\n"
    FileClose $0
    DetailPrint "Generated bear.cmd shim"

    ; Docs
    DetailPrint "Including README.md"
    File "${BASE_DIR}\README.md"
    DetailPrint "Including LICENSE.txt"
    File /oname=LICENSE.txt "${BASE_DIR}\LICENSE.txt"

    ; Registry
    WriteRegStr HKLM "Software\${APP_NAME}" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "Software\${APP_NAME}" "Version" "${APP_VERSION}"

    ; Uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Add/Remove Programs
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\bear-driver.exe"
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1

    ; Tell the user to add $INSTDIR to PATH manually.
    DetailPrint "Add $INSTDIR to your PATH to use 'bear' from any shell."

    ; Size
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "EstimatedSize" "$0"
SectionEnd

; ------------------------------------------
; Uninstall section

Section "Uninstall"
    Delete "$INSTDIR\bear-driver.exe"
    Delete "$INSTDIR\bear-wrapper.exe"
    Delete "$INSTDIR\bear.cmd"
    Delete "$INSTDIR\README.md"
    Delete "$INSTDIR\LICENSE.txt"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir "$INSTDIR"

    DeleteRegKey HKLM "${UNINSTALL_KEY}"
    DeleteRegKey HKLM "Software\${APP_NAME}"
SectionEnd
