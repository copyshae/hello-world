#Requires -Version 5.1
# 安裝／修復掃具台
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'scan-equip-app.ps1'
if (-not (Test-Path -LiteralPath $src)) { throw "找不到 $src" }

$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk '掃具台程式'
$work = Join-Path $desk '掃具台資料'
New-Item -ItemType Directory -Force -Path $appDir,$work | Out-Null

$raw = Get-Content -LiteralPath $src -Raw -Encoding UTF8
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText((Join-Path $appDir 'scan-equip-app.ps1'), $raw, $utf8Bom)

$cmd = @"
@echo off
chcp 65001 >nul
title 掃具台
cd /d "%USERPROFILE%\Desktop"
echo 正在啟動掃具台...
start "" "https://copyshae.github.io/hello-world/directory/apps/scan-equip/"
"@
Set-Content -LiteralPath (Join-Path $desk '掃具台.cmd') -Value $cmd -Encoding ASCII

Write-Host "已安裝完成"
Write-Host "請雙擊桌面：掃具台.cmd"
Write-Host "或直接開啟手機版："
Write-Host "https://copyshae.github.io/hello-world/directory/apps/scan-equip/"
