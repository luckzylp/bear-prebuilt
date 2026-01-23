; ==========================================
; Bear Installer (x64 / ARM64 compatible)
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
!include "WinMessages.nsh"

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
    GetDlgItem $1 $0 1019 ; Browse
    EnableWindow $1 0
    GetDlgItem $1 $0 1001 ; Path edit
    EnableWindow $1 0
FunctionEnd

; ------------------------------------------
; Architecture sanity check (runtime)

Function .onInit
    ; Check if running on x64 Windows
    ${If} ${RunningX64}
        ; This is x64 Windows, check if installer matches
        StrCmp "${TARGET_TRIPLE}" "x86_64-pc-windows-msvc" ok_arch 0
        MessageBox MB_ICONSTOP "This installer is for x86_64 architecture but you are trying to install on a different architecture."
        Abort
    ${Else}
        ; Not x64, could be ARM64 or x86
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

    ; Executable
    File /oname=bear.exe "${BASE_DIR}\${TARGET_DIR}\bear.exe"

    ; Wrapper executable - always include, will be silently skipped if not found
    DetailPrint "Including wrapper.exe from: ${BASE_DIR}\${TARGET_DIR}\wrapper.exe"
    File /oname=wrapper.exe "${BASE_DIR}\${TARGET_DIR}\wrapper.exe"

    ; Optional DLLs - always try to include
    DetailPrint "Including DLLs from: ${BASE_DIR}\${TARGET_DIR}\*.dll"
    File "${BASE_DIR}\${TARGET_DIR}\*.dll"

    ; Docs
    DetailPrint "Including README.md"
    File "${BASE_DIR}\README.md"
    DetailPrint "Including LICENSE.txt"
    File /oname=LICENSE.txt "${BASE_DIR}\LICENSE.txt"

    ; Registry
    WriteRegStr HKLM "Software\${APP_NAME}" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "Software\${APP_NAME}" "Version" "${APP_VERSION}"

    ; Add to system PATH
    DetailPrint "Adding $INSTDIR to system PATH..."
    Push "$INSTDIR"
    Call AddToPath

    ; Uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Add/Remove Programs
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\bear.exe"
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1

    ; Size
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "EstimatedSize" "$0"
SectionEnd

; ------------------------------------------
; Uninstall section

Section "Uninstall"
    ; Remove from system PATH
    DetailPrint "Removing $INSTDIR from system PATH..."
    Push "$INSTDIR"
    Call RemoveFromPath

    Delete "$INSTDIR\bear.exe"
    Delete "$INSTDIR\wrapper.exe"
    Delete "$INSTDIR\*.dll"
    Delete "$INSTDIR\README.md"
    Delete "$INSTDIR\LICENSE.txt"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir "$INSTDIR"

    DeleteRegKey HKLM "${UNINSTALL_KEY}"
    DeleteRegKey HKLM "Software\${APP_NAME}"
SectionEnd

; ------------------------------------------
; Helper functions for PATH management

Function AddToPath
    Exch $0
    Push $1
    Push $2
    Push $3

    ; Read current system PATH
    ReadRegStr $1 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"

    ; Check if path is already in PATH
    StrCmp $1 "" AddPath
    Push "$1;"
    Push "$0;"
    Call StrStr
    Pop $2
    StrCmp $2 "" AddPath
        Goto Done

    AddPath:
    ; Append new path
    StrCpy $2 $1 1 -1
    StrCmp $2 ";" PathOk
        StrCpy $1 "$1;"

    PathOk:
    StrCpy $1 "$1$0"

    ; Write back to registry
    WriteRegStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$1"

    ; Notify shell of environment change
    System::Call 'shell32.dll::SHChangeNotify(i 0x08000000, i 0, i 0, i 0)'

    DetailPrint "Added $0 to system PATH"

    Done:
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

Function RemoveFromPath
    Exch $0
    Push $1
    Push $2
    Push $3
    Push $4

    ; Read current system PATH
    ReadRegStr $1 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"

    ; Check if path exists
    StrCmp $1 "" Done

    ; Remove path from PATH (handle semicolons)
    StrCpy $2 ""
    StrCpy $4 "$1"

    ; Find and remove $0 from $4
    StrLen $3 "$0"
    StrCmp $4 "" RemoveDone

    RemoveLoop:
    StrCpy $2 $4 $3
    StrCmp $2 "$0" FoundPath
    StrCmp $4 "" RemoveDone
    StrCpy $2 $4 1 -1
    StrCmp $2 ";" NoLeadingSep
    StrCpy $4 "$4;"
    NoLeadingSep:
    StrCpy $4 $4 -1
    Goto RemoveLoop

    FoundPath:
    ; Remove $0 and leading/trailing semicolons
    StrCpy $2 $4
    StrCpy $4 "$2"
    StrCpy $2 $4 $3
    StrCpy $4 "$4" "" $3
    ; Clean up leading semicolon
    StrCpy $2 $4 1
    StrCmp $2 ";" StripLeading
    Goto StripDone
    StripLeading:
    StrCpy $4 $4 "" 1
    StripDone:
    ; Clean up trailing semicolon
    StrCpy $2 $4 1 -1
    StrCmp $2 ";" StripTrailing
    Goto PathDone
    StripTrailing:
    StrCpy $4 $4 -1
    PathDone:

    ; Write back to registry
    WriteRegStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$4"

    ; Notify shell of environment change
    System::Call 'shell32.dll::SHChangeNotify(i 0x08000000, i 0, i 0, i 0)'

    DetailPrint "Removed $0 from system PATH"

    RemoveDone:
    Done:
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

; StrStr function - finds substring
Function StrStr
    Exch $R1 ; stack = $R1, $R2
    Exch ; stack = $R1, $R2, $R1
    Exch $R2 ; stack = $R2, $R1, $R2
    Push $R3
    Push $R4
    Push $R5
    Push $R6
    Push $R7

    StrCpy $R3 $R2
    StrCpy $R4 $R1
    StrLen $R5 $R2
    StrLen $R6 $R1

    StrCmp $R5 0 StringEnd

    Loop:
    StrCpy $R7 $R3 $R5
    StrCmp $R7 $R2 Found
    StrCmp $R3 "" StringEnd
    StrCpy $R3 "$R3" -1
    Goto Loop

    Found:
    StrCpy $R7 $R3 $R5
    StrCmp $R7 $R2 Found2
    StrCmp $R3 "" StringEnd
    StrCpy $R3 "$R3" -1
    Goto Loop

    Found2:
    StrCpy $R1 $R3

    StringEnd:
    Pop $R7
    Pop $R6
    Pop $R5
    Pop $R4
    Pop $R3
    Pop $R2
    Exch $R1
FunctionEnd
