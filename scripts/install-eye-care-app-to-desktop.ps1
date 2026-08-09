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

# 清除舊的自動關閉設定，避免一閃而過
$jsonPath = Join-Path $appDir 'reminders.json'
if (Test-Path -LiteralPath $jsonPath) {
  try {
    $cfg = Get-Content -LiteralPath $jsonPath -Encoding UTF8 -Raw | ConvertFrom-Json
    foreach ($it in @($cfg.items)) { $it.autoCloseSeconds = 0 }
    $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
  } catch {}
}

# 不用 start：視窗關閉前命令列會保留；出錯會 pause
$cmd = Join-Path $appDir '啟動護眼提醒.cmd'
@(
  '@echo off'
  'chcp 65001 >nul'
  'cd /d "%~dp0"'
  'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0eye-care-reminder-app.ps1"'
  'if errorlevel 1 ('
  '  echo.'
  '  echo 啟動失敗，請把上方紅字拍照或複製給協助者。'
  '  pause'
  ')'
) | Set-Content -LiteralPath $cmd -Encoding ASCII

$deskCmd = Join-Path $desk '護眼提醒.cmd'
Copy-Item -LiteralPath $cmd -Destination $deskCmd -Force

Write-Host "已安裝到: $appDir"
Write-Host "請雙擊桌面「護眼提醒.cmd」"
Write-Host "提醒改為：先跳出系統對話框（按確定）→ 再放大字視窗（按知道了），不會自動關。"
