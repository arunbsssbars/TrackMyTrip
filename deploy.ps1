# Shortcut to execute the Universal Antigravity Build & Distribution Pipeline
param(
    [ValidateSet("release", "debug")][string]$BuildType = "release",
    [string]$TesterEmail = "arunbsssbars@gmail.com",
    [switch]$SkipTests
)

$scriptPath = Join-Path (Split-Path (Get-Location).Path -Parent) "deploy_global.ps1"
if (-not (Test-Path $scriptPath)) {
    $scriptPath = "D:\Program\Antigravity\deploy_global.ps1"
}

& $scriptPath -ProjectPath (Get-Location).Path -BuildType $BuildType -TesterEmail $TesterEmail -SkipTests:$SkipTests
