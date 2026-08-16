#Requires -Version 5.1
# 安裝／修復習作台（精簡穩定版；錯誤會留在桌面）
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'teacher-desk-app.ps1'
if (-not (Test-Path -LiteralPath $src)) { throw "找不到 $src" }

$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk '習作台程式'
$work = Join-Path $desk '習作台資料'
New-Item -ItemType Directory -Force -Path $appDir,$work,(Join-Path $work '掃描匯入'),(Join-Path $work '匯出給手機') | Out-Null

$raw = Get-Content -LiteralPath $src -Raw -Encoding UTF8
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText((Join-Path $appDir 'teacher-desk-app.ps1'), $raw, $utf8Bom)

$cmd = @"
@echo off
chcp 65001 >nul
title 習作台
cd /d "%USERPROFILE%\Desktop"
echo 正在啟動習作台...
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%USERPROFILE%\Desktop\習作台程式\teacher-desk-app.ps1" -WorkDir "%USERPROFILE%\Desktop\習作台資料"
set ERR=%ERRORLEVEL%
if exist "%USERPROFILE%\Desktop\習作台錯誤.txt" (
  echo.
  echo ===== 錯誤內容 =====
  type "%USERPROFILE%\Desktop\習作台錯誤.txt"
  echo ====================
)
if not "%ERR%"=="0" (
  echo.
  echo 啟動失敗，錯誤代碼 %ERR%
  echo 請把上方文字複製給 Cursor
  pause
  exit /b %ERR%
)
"@
Set-Content -LiteralPath (Join-Path $desk '習作台.cmd') -Value $cmd -Encoding ASCII
Set-Content -LiteralPath (Join-Path $appDir '啟動習作台.cmd') -Value $cmd -Encoding ASCII

$vbs = @"
Set sh = CreateObject("WScript.Shell")
sh.Run """" & sh.SpecialFolders("Desktop") & "\習作台.cmd""", 1, False
"@
Set-Content -LiteralPath (Join-Path $desk '習作台.vbs') -Value $vbs -Encoding ASCII

Write-Host "已安裝完成"
Write-Host "請雙擊桌面：習作台.cmd"
Write-Host "若失敗，桌面會有「習作台錯誤.txt」"
