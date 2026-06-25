# PowerShell script to create Windows installer using NSIS.
#
# Bear v3+ on Windows produces only two executables (per Bear/INSTALL.md):
#   - bear-driver.exe
#   - bear-wrapper.exe
# There is no preload library on Windows. The user-facing `bear` command is
# a small .cmd shim that calls bear-driver.exe with the forwarded arguments.

param(
    [string]$Version = "0.0.0",
    [string]$TargetTriple = "x86_64-pc-windows-msvc",
    [string]$SourcePath = ""
)

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Creating Bear Windows Installer" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host "Target: $TargetTriple" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$NSISDir = Join-Path $ScriptDir "nsis"
$DistDir = Join-Path $ProjectRoot "dist"

if ($SourcePath -eq "") {
    $BearDir = Join-Path $ProjectRoot "Bear"
} else {
    $BearDir = $SourcePath
    Write-Host "Using custom SourcePath: $BearDir" -ForegroundColor Yellow
}

# --- target dir -------------------------------------------------------------
$ActualTarget = $TargetTriple -replace '\.2\.17$', ''
$TargetDir = Join-Path $BearDir "target\$ActualTarget\release"
if (-not (Test-Path $TargetDir)) {
    $TargetDir = Join-Path $BearDir "target\release"
}
Write-Host "Actual target directory: $TargetDir" -ForegroundColor Cyan

# --- validate artifacts ----------------------------------------------------
$DriverExe = Join-Path $TargetDir "bear-driver.exe"
$WrapperExe = Join-Path $TargetDir "bear-wrapper.exe"
foreach ($art in @($DriverExe, $WrapperExe)) {
    if (-not (Test-Path $art)) {
        Write-Host "Error: required artifact not found: $art" -ForegroundColor Red
        Write-Host "Did the cargo build for target '$TargetTriple' complete successfully?" -ForegroundColor Yellow
        exit 1
    }
}
Write-Host "✓ Found bear-driver.exe and bear-wrapper.exe" -ForegroundColor Green

# --- NSIS script ------------------------------------------------------------
$NSISScript = Join-Path $NSISDir "bear-installer.nsi"
if (-not (Test-Path $NSISScript)) {
    Write-Host "Error: NSIS script not found at $NSISScript" -ForegroundColor Red
    exit 1
}

# --- LICENSE.txt (NSIS requires .txt extension) ----------------------------
$LicenseSource = Join-Path $BearDir "LICENSE"
$LicenseTarget = Join-Path $BearDir "LICENSE.txt"
$CopyingSource = Join-Path $BearDir "COPYING"
$HaveLicense = $false
if (Test-Path -Path $CopyingSource) {
    Copy-Item $CopyingSource $LicenseTarget -Force
    $HaveLicense = $true
} elseif (Test-Path -Path $LicenseSource) {
    Copy-Item $LicenseSource $LicenseTarget -Force
    $HaveLicense = $true
} elseif (-not (Test-Path -Path $LicenseTarget)) {
    Write-Host "Warning: LICENSE/COPYING not found, creating minimal license stub" -ForegroundColor Yellow
    @"
Bear - Build EAR (Compilation Database) Tool

Prebuilt distribution. For full license information see:
https://github.com/rizsotto/Bear
"@ | Set-Content -Path $LicenseTarget
}

# --- ensure dist dir exists -------------------------------------------------
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir | Out-Null
}

# --- find NSIS --------------------------------------------------------------
$NSISPath = $null
$PossiblePaths = @(
    "C:\Program Files (x86)\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe",
    "$env:ProgramFiles\NSIS\makensis.exe",
    "${env:ProgramFiles(x86)}\NSIS\makensis.exe"
)
foreach ($p in $PossiblePaths) {
    if (Test-Path $p) { $NSISPath = $p; break }
}
if (-not $NSISPath) {
    $NSISPath = (Get-Command makensis.exe -ErrorAction SilentlyContinue).Source
}
if (-not $NSISPath) {
    Write-Host "Error: NSIS not found. Install via Chocolatey: choco install nsis" -ForegroundColor Red
    exit 1
}
Write-Host "✓ NSIS at: $NSISPath" -ForegroundColor Green

# --- run NSIS ---------------------------------------------------------------
$NSISArgs = @(
    "/DAPP_VERSION=$Version"
    "/DTARGET_TRIPLE=$ActualTarget"
    "/V4"
    $NSISScript
)

Write-Host ""
Write-Host "Building installer..." -ForegroundColor Cyan
& $NSISPath $NSISArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: NSIS compilation failed (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

# --- move installer ---------------------------------------------------------
$InstallerName = "bear-$Version-$TargetTriple-installer.exe"
$InstallerSource = Join-Path $NSISDir $InstallerName
$InstallerTarget = Join-Path $DistDir "bear-$Version-$TargetTriple-installer.exe"

if (Test-Path $InstallerSource) {
    Move-Item -Path $InstallerSource -Destination $InstallerTarget -Force
    Write-Host ""
    Write-Host "✓ Installer created: $InstallerTarget" -ForegroundColor Green
} else {
    Write-Host "Error: installer not found at $InstallerSource" -ForegroundColor Red
    exit 1
}

$SizeMB = [math]::Round((Get-Item $InstallerTarget).Length / 1MB, 2)
Write-Host "  Name: $(Split-Path -Leaf $InstallerTarget)"
Write-Host "  Size: $SizeMB MB"
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Windows installer creation completed!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
