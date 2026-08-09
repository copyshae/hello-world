#Requires -Version 5.1
<#
.SYNOPSIS
  把「護眼提醒」安裝到桌面：用 VBS 靜音啟動（不會閃黑色視窗）。
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

$jsonPath = Join-Path $appDir 'reminders.json'
if (Test-Path -LiteralPath $jsonPath) {
  try {
    $cfg = Get-Content -LiteralPath $jsonPath -Encoding UTF8 -Raw | ConvertFrom-Json
    foreach ($it in @($cfg.items)) { $it.autoCloseSeconds = 0 }
    $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
  } catch {}
}

# VBS：視窗樣式 0 = 完全隱藏黑色主控台
$vbs = Join-Path $appDir '啟動護眼提醒.vbs'
$ps1Esc = (Join-Path $appDir 'eye-care-reminder-app.ps1') -replace '\\', '\\'
$vbsBody = @"
Set sh = CreateObject("WScript.Shell")
ps1 = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\eye-care-reminder-app.ps1"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """"
sh.Run cmd, 0, False
"@
Set-Content -LiteralPath $vbs -Value $vbsBody -Encoding ASCII

# 桌面主捷徑：VBS（不閃黑窗）
$deskVbs = Join-Path $desk '護眼提醒.vbs'
Copy-Item -LiteralPath $vbs -Destination $deskVbs -Force

# 除錯用 CMD（會顯示黑窗，出錯可 pause）
$dbg = Join-Path $appDir '除錯啟動.cmd'
@(
  '@echo off'
  'chcp 65001 >nul'
  'cd /d "%~dp0"'
  'echo 正在啟動（除錯模式，看得到黑窗）...'
  'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0eye-care-reminder-app.ps1"'
  'echo.'
  'echo 視窗已關閉。若剛才有紅字，請拍照。'
  'pause'
) | Set-Content -LiteralPath $dbg -Encoding ASCII

$deskDbg = Join-Path $desk '護眼提醒-除錯.cmd'
Copy-Item -LiteralPath $dbg -Destination $deskDbg -Force

# 移除容易閃黑窗的舊 cmd 捷徑（若存在）
$oldCmd = Join-Path $desk '護眼提醒.cmd'
if (Test-Path -LiteralPath $oldCmd) {
  Remove-Item -LiteralPath $oldCmd -Force -ErrorAction SilentlyContinue
}

Write-Host "已安裝到: $appDir"
Write-Host "請雙擊桌面「護眼提醒.vbs」（不會閃黑色視窗）"
Write-Host "若設定視窗沒出現，再雙擊「護眼提醒-除錯.cmd」看錯誤"
