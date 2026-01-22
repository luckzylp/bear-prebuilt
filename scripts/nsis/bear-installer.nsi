; NSIS Installer Script for Bear
; Generates Windows installer with fixed installation path and PATH modification

!define APP_NAME "Bear"
; APP_VERSION is passed via command line: /DAPP_VERSION=x.x.x
!ifndef APP_VERSION
  !define APP_VERSION "0.0.0"  ; Fallback version if not specified
!endif
!define PUBLISHER "Bear Development Team"
!define INSTALL_DIR "C:\Program Files\Bear"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"

;--------------------------------
; Includes

!include "MUI2.nsh"
!include "x64.nsh"
!include "WinMessages.nsh"

;--------------------------------
; General Configuration

Name "${APP_NAME} ${APP_VERSION}"
OutFile "bear-${APP_VERSION}-windows-installer.exe"
InstallDir "${INSTALL_DIR}"
InstallDirRegKey HKLM "Software\${APP_NAME}" "InstallDir"

; Request administrator privileges
RequestExecutionLevel admin

; Compression
SetCompressor /SOLID lzma

;--------------------------------
; Interface Settings

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install-blue.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall-blue.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\nsis-r.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\win.bmp"

;--------------------------------
; Pages

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\Bear\LICENSE.txt"
!define MUI_PAGE_CUSTOMFUNCTION_PRE DirectoryPre
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
; Languages

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Custom Functions

; Disable directory modification (fixed path requirement)
Function DirectoryPre
    ; Lock the installation directory - user cannot change it
    FindWindow $0 "#32770" "" $HWNDPARENT
    GetDlgItem $1 $0 1019
    EnableWindow $1 0  ; Disable the browse button
    GetDlgItem $1 $0 1001
    EnableWindow $1 0  ; Disable the directory text field
FunctionEnd

;--------------------------------
; Installer Sections

Section "Bear Core Files" SecCore
    SectionIn RO  ; Required section, cannot be unselected

    SetOutPath "$INSTDIR"

    ; Install executables
    File /oname=bear.exe "..\..\Bear\target\release\bear.exe"

    ; Install wrapper if it exists
    IfFileExists "..\..\Bear\target\release\wrapper.exe" 0 +2
    File /oname=wrapper.exe "..\..\Bear\target\release\wrapper.exe"

    ; Install intercept if it exists
    IfFileExists "..\..\Bear\target\release\intercept.exe" 0 +2
    File /oname=intercept.exe "..\..\Bear\target\release\intercept.exe"

    ; Install library files if they exist
    IfFileExists "..\..\Bear\target\release\*.dll" 0 +2
    File "..\..\Bear\target\release\*.dll"

    ; Install documentation
    IfFileExists "..\..\Bear\README.md" 0 +2
    File "..\..\Bear\README.md"

    IfFileExists "..\..\Bear\LICENSE.txt" 0 +3
    File "..\..\Bear\LICENSE.txt"
    Goto +2
    IfFileExists "..\..\Bear\LICENSE" 0 +2
    File /oname=LICENSE.txt "..\..\Bear\LICENSE"

    ; Write installation directory to registry
    WriteRegStr HKLM "Software\${APP_NAME}" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "Software\${APP_NAME}" "Version" "${APP_VERSION}"

    ; Create uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Add to Add/Remove Programs
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\bear.exe"
    WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1

    ; Estimate size (in KB)
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "EstimatedSize" "$0"

    ; Add to system PATH
    Call AddToPath

SectionEnd

;--------------------------------
; Uninstaller Section

Section "Uninstall"

    ; Remove from PATH
    Call un.RemoveFromPath

    ; Remove files
    Delete "$INSTDIR\bear.exe"
    Delete "$INSTDIR\wrapper.exe"
    Delete "$INSTDIR\intercept.exe"
    Delete "$INSTDIR\*.dll"
    Delete "$INSTDIR\README.md"
    Delete "$INSTDIR\LICENSE.txt"
    Delete "$INSTDIR\Uninstall.exe"

    ; Remove directories
    RMDir "$INSTDIR"

    ; Remove registry keys
    DeleteRegKey HKLM "${UNINSTALL_KEY}"
    DeleteRegKey HKLM "Software\${APP_NAME}"

SectionEnd

;--------------------------------
; PATH Modification Functions

Function AddToPath
    ; Read current system PATH
    ReadRegStr $0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "PATH"

    ; Check if already in PATH
    ${StrContains} $1 "$INSTDIR" "$0"
    StrCmp $1 "" 0 AlreadyInPath

    ; Add to PATH
    StrCpy $0 "$0;$INSTDIR"
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "PATH" $0

    ; Broadcast environment change
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

    DetailPrint "Added $INSTDIR to system PATH"
    Goto Done

    AlreadyInPath:
        DetailPrint "$INSTDIR already in PATH"

    Done:
FunctionEnd

Function un.RemoveFromPath
    ; Read current system PATH
    ReadRegStr $0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "PATH"

    ; Remove our directory from PATH
    ${un.StrRep} $1 $0 "$INSTDIR;" ""
    ${un.StrRep} $0 $1 ";$INSTDIR" ""
    ${un.StrRep} $1 $0 "$INSTDIR" ""

    ; Write updated PATH
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "PATH" $1

    ; Broadcast environment change
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

    DetailPrint "Removed $INSTDIR from system PATH"
FunctionEnd

;--------------------------------
; String Functions

!macro _StrContainsConstructor OUT NEEDLE HAYSTACK
  Push `${HAYSTACK}`
  Push `${NEEDLE}`
  Call StrContains
  Pop `${OUT}`
!macroend

!define StrContains '!insertmacro "_StrContainsConstructor"'

Function StrContains
  Exch $STR_NEEDLE
  Exch 1
  Exch $STR_HAYSTACK
  Push $STR_LEN
  Push $STR_POS
  Push $STR_TEMP

  StrLen $STR_LEN $STR_NEEDLE
  StrCpy $STR_POS 0

  loop:
    StrCpy $STR_TEMP $STR_HAYSTACK $STR_LEN $STR_POS
    StrCmp $STR_TEMP $STR_NEEDLE found
    IntOp $STR_POS $STR_POS + 1
    StrCpy $STR_TEMP $STR_HAYSTACK 1 $STR_POS
    StrCmp $STR_TEMP "" done loop

  found:
    StrCpy $STR_HAYSTACK $STR_NEEDLE
    Goto end

  done:
    StrCpy $STR_HAYSTACK ""

  end:
    Pop $STR_TEMP
    Pop $STR_POS
    Pop $STR_LEN
    Pop $STR_NEEDLE
    Exch $STR_HAYSTACK
FunctionEnd

!macro _StrRepConstructor OUT OLD NEW STR
  Push `${STR}`
  Push `${OLD}`
  Push `${NEW}`
  Call un.StrRep
  Pop `${OUT}`
!macroend

!define un.StrRep '!insertmacro "_StrRepConstructor"'

Function un.StrRep
  Exch $R4
  Exch 1
  Exch $R5
  Exch 2
  Exch $R1
  Push $R2
  Push $R3
  Push $R6
  Push $R7
  Push $R8
  Push $R9

  StrCpy $R2 -1
  StrLen $R3 $R5
  StrLen $R7 $R1
  StrLen $R8 $R4

  loop:
    IntOp $R2 $R2 + 1
    StrCpy $R6 $R1 $R3 $R2
    StrCmp $R6 "" done
    StrCmp $R6 $R5 found loop

  found:
    StrCpy $R6 $R1 $R2
    IntOp $R9 $R2 + $R3
    StrCpy $R7 $R1 "" $R9
    StrCpy $R1 $R6$R4$R7
    StrLen $R7 $R1
    IntOp $R2 $R2 + $R8
    IntOp $R2 $R2 - 1
    Goto loop

  done:
    Pop $R9
    Pop $R8
    Pop $R7
    Pop $R6
    Pop $R3
    Pop $R2
    Pop $R5
    Pop $R4
    Exch $R1
FunctionEnd

; GetSize function
!include "FileFunc.nsh"
!insertmacro GetSize
