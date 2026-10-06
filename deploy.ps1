param(
    [ValidateSet("release", "debug")][string]$BuildType = "release",
    [string]$TesterEmail = "arunbsssbars@gmail.com",
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  TrackMyTrip Build and Distribution Pipeline" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$projectDir = $PSScriptRoot
Set-Location $projectDir

$pubspecPath = Join-Path $projectDir "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
    Write-Host "Error: pubspec.yaml not found in $projectDir" -ForegroundColor Red
    exit 1
}

$pubspecContent = Get-Content $pubspecPath -Raw
$projectVersion = "1.0.0"
if ($pubspecContent -match "(?m)^version:\s*([^\r\n#]+)") {
    $projectVersion = $matches[1].Trim()
}

$cleanProjectName = "TrackMyTrip"
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"

Write-Host "Project Detected : $cleanProjectName" -ForegroundColor Green
Write-Host "Version          : $projectVersion" -ForegroundColor Green
Write-Host "Build Mode       : $BuildType" -ForegroundColor Green
Write-Host "Tester Target    : $TesterEmail" -ForegroundColor Green
Write-Host "-----------------------------------------------------------------"

# Phase 1 & 2: Verification
if (-not $SkipTests) {
    Write-Host "[Phase 1/4] Running Static Analysis..." -ForegroundColor Yellow
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Static analysis failed. Aborting build." -ForegroundColor Red
        exit 1
    }
    Write-Host "Static analysis passed with zero errors!" -ForegroundColor Green

    Write-Host "[Phase 2/4] Running Test Suite..." -ForegroundColor Yellow
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Tests failed. Aborting build." -ForegroundColor Red
        exit 1
    }
    Write-Host "All tests passed successfully!" -ForegroundColor Green
} else {
    Write-Host "Skipping tests (-SkipTests active)" -ForegroundColor Yellow
}

# Phase 3: Compilation
Write-Host "[Phase 3/4] Compiling Flutter Android APK ($BuildType)..." -ForegroundColor Yellow
if ($BuildType -eq "release") {
    flutter build apk --release
} else {
    flutter build apk --debug
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation failed." -ForegroundColor Red
    exit 1
}

$apkSource = if ($BuildType -eq "release") {
    Join-Path $projectDir "build/app/outputs/flutter-apk/app-release.apk"
} else {
    Join-Path $projectDir "build/app/outputs/flutter-apk/app-debug.apk"
}

if (-not (Test-Path $apkSource)) {
    Write-Host "Error: Built APK not found at $apkSource" -ForegroundColor Red
    exit 1
}

$apkItem = Get-Item $apkSource
$apkSizeMB = [math]::Round($apkItem.Length / 1MB, 2)
Write-Host "Build Complete! Size: $apkSizeMB MB" -ForegroundColor Green

# Phase 4: Distribution
Write-Host "[Phase 4/4] Distributing Artifacts..." -ForegroundColor Yellow

$possibleDrivePaths = @(
    "G:\My Drive\development",
    "G:\Shared drives\development",
    "H:\My Drive\development",
    "$env:USERPROFILE\Google Drive\development",
    "$env:USERPROFILE\My Drive\development",
    "D:\Google Drive\development",
    "D:\Program\Antigravity\build_releases\development"
)

$targetDriveFolder = $null
foreach ($p in $possibleDrivePaths) {
    $parent = Split-Path $p -Parent
    if (Test-Path $parent -or Test-Path $p) {
        $targetDriveFolder = $p
        break
    }
}

if (-not $targetDriveFolder) {
    $targetDriveFolder = "D:\Program\Antigravity\build_releases\development"
}

$projectDriveDir = Join-Path $targetDriveFolder $cleanProjectName
if (-not (Test-Path $projectDriveDir)) {
    New-Item -ItemType Directory -Path $projectDriveDir -Force | Out-Null
}

$versionTag = $projectVersion.Replace("+", "_")
$versionedApkName = "$cleanProjectName-v$versionTag-$timestamp.apk"
$latestApkName = "$cleanProjectName-latest.apk"

$destVersioned = Join-Path $projectDriveDir $versionedApkName
$destLatest = Join-Path $projectDriveDir $latestApkName

Copy-Item $apkSource $destVersioned -Force
Copy-Item $apkSource $destLatest -Force

Write-Host "[Google Drive / Local Releases]:" -ForegroundColor Cyan
Write-Host "   Folder  : $projectDriveDir"
Write-Host "   Latest  : $latestApkName"
Write-Host "   Version : $versionedApkName"

# Firebase App Distribution
$googleServicesPath = Join-Path $projectDir "android/app/google-services.json"
if (Test-Path $googleServicesPath) {
    $fbCmd = Get-Command "firebase" -ErrorAction SilentlyContinue
    if ($fbCmd) {
        $rawJson = Get-Content $googleServicesPath -Raw
        $appId = $null
        $projectId = $null
        if ($rawJson -match '"mobilesdk_app_id":\s*"([^"]+)"') {
            $appId = $matches[1]
        }
        if ($rawJson -match '"project_id":\s*"([^"]+)"') {
            $projectId = $matches[1]
        }

        if ($appId -and $projectId) {
            Write-Host "[Firebase App Distribution]:" -ForegroundColor Cyan
            Write-Host "   Project : $projectId | App: $appId"
            Write-Host "   Uploading to testers ($TesterEmail)..." -ForegroundColor DarkGray
            
            $nowStr = Get-Date -Format "yyyy-MM-dd HH:mm"
            $notes = "$cleanProjectName v$projectVersion ($BuildType) built via Antigravity at $nowStr"
            & firebase appdistribution:distribute $apkSource --app $appId --project $projectId --testers $TesterEmail --release-notes $notes
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   Delivered directly to tester phone notification!" -ForegroundColor Green
            }
        }
    }
}

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "DISTRIBUTION PIPELINE COMPLETE!" -ForegroundColor Green
Write-Host "   App: $cleanProjectName | Size: $apkSizeMB MB"
Write-Host "   Artifact: $destLatest"
Write-Host "=================================================================" -ForegroundColor Green
