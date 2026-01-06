# export_build.ps1 - Build script for One Button Beekeeper
# Exports the game to Windows using Godot's command line

param(
    [switch]$Debug,
    [switch]$SkipImport
)

$ErrorActionPreference = "Stop"

# Paths
$ProjectRoot = $PSScriptRoot
$GodotConsole = "$ProjectRoot\Godot\Godot.exe"
$GodotGui = "$ProjectRoot\Godot\Godot.exe"
$ExportPreset = "Windows Desktop"
$OutputPath = "$ProjectRoot\builds\windows\OneButtonBeekeeper.exe"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "One Button Beekeeper - Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Godot console exists
if (-not (Test-Path $GodotConsole)) {
    Write-Host "ERROR: Godot console executable not found at:" -ForegroundColor Red
    Write-Host "  $GodotConsole" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure Godot is installed in the Godot folder." -ForegroundColor Yellow
    exit 1
}

# Step 1: Import assets (unless skipped)
if (-not $SkipImport) {
    Write-Host "[1/3] Importing assets..." -ForegroundColor Yellow
    & $GodotConsole --path $ProjectRoot --import --headless
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Asset import failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Assets imported successfully." -ForegroundColor Green
} else {
    Write-Host "[1/3] Skipping asset import." -ForegroundColor Gray
}

# Step 2: Run automated tests
Write-Host ""
Write-Host "[2/3] Running automated tests..." -ForegroundColor Yellow
& $GodotConsole --path $ProjectRoot --headless -- --autotest
$testResult = $LASTEXITCODE
if ($testResult -ne 0) {
    Write-Host "ERROR: Automated tests failed with exit code $testResult!" -ForegroundColor Red
    exit 1
}
Write-Host "  All tests passed." -ForegroundColor Green

# Step 3: Export the game
Write-Host ""
Write-Host "[3/3] Exporting game..." -ForegroundColor Yellow

# Create output directory if needed
$OutputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Export command
if ($Debug) {
    Write-Host "  Building DEBUG version..." -ForegroundColor Cyan
    & $GodotConsole --path $ProjectRoot --export-debug "$ExportPreset" $OutputPath --headless
} else {
    Write-Host "  Building RELEASE version..." -ForegroundColor Cyan
    & $GodotConsole --path $ProjectRoot --export-release "$ExportPreset" $OutputPath --headless
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Export failed!" -ForegroundColor Red
    exit 1
}

# Check if output exists
if (Test-Path $OutputPath) {
    $fileInfo = Get-Item $OutputPath
    $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Output: $OutputPath" -ForegroundColor White
    Write-Host "Size: $sizeMB MB" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "ERROR: Export completed but output file not found!" -ForegroundColor Red
    exit 1
}

exit 0
