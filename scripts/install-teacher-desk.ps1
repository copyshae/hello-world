#Requires -Version 5.1
# 安裝／修復「習作台」桌面視窗（繁體中文；可見錯誤）
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'teacher-desk-app.ps1'
if (-not (Test-Path -LiteralPath $src)) { throw "找不到程式檔：$src" }

$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk '習作台程式'
$work = Join-Path $desk '習作台資料'

New-Item -ItemType Directory -Force -Path $appDir | Out-Null
Copy-Item -LiteralPath $src -Destination (Join-Path $appDir 'teacher-desk-app.ps1') -Force

New-Item -ItemType Directory -Force -Path $work | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $work '掃描匯入') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $work '匯出給手機') | Out-Null

$oldWork = Join-Path $desk 'TeacherDesk'
$oldState = Join-Path $oldWork 'class-state.json'
$newState = Join-Path $work '班級狀態.json'
$legacyState = Join-Path $work 'class-state.json'
if ((Test-Path -LiteralPath $oldState) -and -not (Test-Path -LiteralPath $newState) -and -not (Test-Path -LiteralPath $legacyState)) {
  Copy-Item -LiteralPath $oldState -Destination $newState -Force
}

# 用 .cmd 啟動（不要 Hidden，出錯看得到）
$cmdText = @"
@echo off
chcp 65001 >nul
title 習作台
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0teacher-desk-app.ps1" -WorkDir "%USERPROFILE%\Desktop\習作台資料"
if errorlevel 1 (
  echo.
  echo 啟動失敗，請把上方紅字拍照或複製給 Cursor。
  pause
)
"@
$cmdPath = Join-Path $appDir '啟動習作台.cmd'
Set-Content -LiteralPath $cmdPath -Value $cmdText -Encoding ASCII

# 桌面捷徑改指向 cmd（比較穩）
$deskCmd = Join-Path $desk '習作台.cmd'
Copy-Item -LiteralPath $cmdPath -Destination $deskCmd -Force

# 相容舊的 vbs：改成呼叫 cmd
$vbs = @"
Set sh = CreateObject("WScript.Shell")
desk = sh.SpecialFolders("Desktop")
sh.Run """" & desk & "\習作台.cmd""", 1, False
"@
Set-Content -LiteralPath (Join-Path $desk '習作台.vbs') -Value $vbs -Encoding ASCII
Set-Content -LiteralPath (Join-Path $appDir '啟動.vbs') -Value $vbs -Encoding ASCII

$readme = @"
習作台已安裝（繁體中文）

請雙擊桌面「習作台.cmd」或「習作台.vbs」
若開不起來，用「習作台.cmd」可看到錯誤訊息。

程式：桌面\習作台程式\
資料：桌面\習作台資料\

手機版：
https://copyshae.github.io/hello-world/directory/apps/teacher-desk/
"@
Set-Content -LiteralPath (Join-Path $work '安裝說明.txt') -Value $readme -Encoding UTF8

Write-Host "已安裝：$appDir"
Write-Host "請雙擊桌面：習作台.cmd"
Write-Host "（若失敗會暫停並顯示錯誤）"
