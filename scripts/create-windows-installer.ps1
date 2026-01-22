# PowerShell script to create Windows installer using NSIS
# This script packages Bear binaries into a Windows installer

param(
    [string]$Version = "0.0.0",
    [string]$TargetTriple = "x86_64-pc-windows-msvc"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Creating Bear Windows Installer" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host "Target: $TargetTriple" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Determine script and project directories
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BearDir = Join-Path $ProjectRoot "Bear"
$NSISDir = Join-Path $ScriptDir "nsis"
$DistDir = Join-Path $ProjectRoot "dist"

# Determine the actual target directory
$ActualTarget = $TargetTriple -replace '\.2\.17$', ''
$TargetDir = Join-Path $BearDir "target\$ActualTarget\release"

# Verify Bear binaries exist
$BearExe = Join-Path $TargetDir "bear.exe"
if (-not (Test-Path $BearExe))
{
    Write-Host "Error: bear.exe not found at $BearExe" -ForegroundColor Red
    Write-Host "Please build Bear first." -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Found bear.exe" -ForegroundColor Green

# Verify NSIS script exists
$NSISScript = Join-Path $NSISDir "bear-installer.nsi"
if (-not (Test-Path $NSISScript))
{
    Write-Host "Error: NSIS script not found at $NSISScript" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Found NSIS script" -ForegroundColor Green

# Ensure LICENSE file exists (NSIS requires .txt extension)
$LicenseSource = Join-Path $BearDir "LICENSE"
$LicenseTarget = Join-Path $BearDir "LICENSE.txt"
if ((Test-Path $LicenseSource) -and (-not (Test-Path $LicenseTarget)))
{
    Copy-Item $LicenseSource $LicenseTarget
    Write-Host "✓ Created LICENSE.txt" -ForegroundColor Green
}

# Create distribution directory
if (-not (Test-Path $DistDir))
{
    New-Item -ItemType Directory -Path $DistDir | Out-Null
    Write-Host "✓ Created dist directory" -ForegroundColor Green
}

# Build installer with NSIS
Write-Host ""
Write-Host "Building installer..." -ForegroundColor Cyan

# Find NSIS executable
$NSISPath = $null
$PossiblePaths = @(
    "C:\Program Files (x86)\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe",
    "$env:ProgramFiles\NSIS\makensis.exe",
    "${env:ProgramFiles(x86)}\NSIS\makensis.exe"
)

foreach ($Path in $PossiblePaths)
{
    if (Test-Path $Path)
    {
        $NSISPath = $Path
        break
    }
}

# Try to find in PATH
if (-not $NSISPath)
{
    $NSISPath = Get-Command makensis.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}

if (-not $NSISPath)
{
    Write-Host "Error: NSIS not found. Please install NSIS from https://nsis.sourceforge.io/" -ForegroundColor Red
    Write-Host "Or install via Chocolatey: choco install nsis" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Found NSIS at: $NSISPath" -ForegroundColor Green

$NSISArgs = @(
    "/DAPP_VERSION=$Version",
    "/V4",  # Verbose level 4
    $NSISScript
)

& $NSISPath $NSISArgs

if ($LASTEXITCODE -ne 0)
{
    Write-Host "Error: NSIS compilation failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Move installer to dist directory
$InstallerName = "bear-$Version-windows-installer.exe"
$InstallerSource = Join-Path $NSISDir $InstallerName
$InstallerTarget = Join-Path $DistDir "$TargetTriple-installer.exe"

if (Test-Path $InstallerSource)
{
    Move-Item -Path $InstallerSource -Destination $InstallerTarget -Force
    Write-Host ""
    Write-Host "✓ Installer created successfully!" -ForegroundColor Green
    Write-Host "Location: $InstallerTarget" -ForegroundColor Cyan
} else
{
    Write-Host "Error: Installer not found at expected location" -ForegroundColor Red
    exit 1
}

# Display installer information
$InstallerSize = (Get-Item $InstallerTarget).Length / 1MB
Write-Host ""
Write-Host "Installer Details:" -ForegroundColor Cyan
Write-Host "  Name: $(Split-Path -Leaf $InstallerTarget)" -ForegroundColor White
Write-Host "  Size: $([math]::Round($InstallerSize, 2)) MB" -ForegroundColor White
Write-Host "  Path: $InstallerTarget" -ForegroundColor White

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Windows installer creation completed!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
