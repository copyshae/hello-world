#Requires -Version 5.1
<#
.SYNOPSIS
  把「護眼提醒」視窗程式安裝到桌面，並建立捷徑。
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'eye-care-reminder-app.ps1'
if (-not (Test-Path -LiteralPath $src)) {
  throw "找不到 $src ；請先用 git 取出此檔"
}

$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk '護眼提醒'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
Copy-Item -LiteralPath $src -Destination (Join-Path $appDir 'eye-care-reminder-app.ps1') -Force

# 若尚無 reminders.json，啟動時會自動建立預設
$cmd = Join-Path $appDir '啟動護眼提醒.cmd'
@(
  '@echo off'
  'chcp 65001 >nul'
  'cd /d "%~dp0"'
  'start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0eye-care-reminder-app.ps1"'
) | Set-Content -LiteralPath $cmd -Encoding ASCII

# 桌面捷徑 .cmd 複製一份方便雙擊
$deskCmd = Join-Path $desk '護眼提醒.cmd'
Copy-Item -LiteralPath $cmd -Destination $deskCmd -Force

Write-Host "已安裝到: $appDir"
Write-Host "請雙擊桌面「護眼提醒.cmd」開啟"
Write-Host "在視窗內可改時間／文案 → 套用這筆 → 開始提醒"
