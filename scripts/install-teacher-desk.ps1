#Requires -Version 5.1
# 安裝「習作台」桌面視窗（繁體中文）
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

# 若舊英文資料夾有狀態檔，自動複製過來（不覆蓋已有新檔）
$oldWork = Join-Path $desk 'TeacherDesk'
$oldState = Join-Path $oldWork 'class-state.json'
$newState = Join-Path $work '班級狀態.json'
$legacyState = Join-Path $work 'class-state.json'
if ((Test-Path -LiteralPath $oldState) -and -not (Test-Path -LiteralPath $newState) -and -not (Test-Path -LiteralPath $legacyState)) {
  Copy-Item -LiteralPath $oldState -Destination $newState -Force
  Write-Host "已從舊資料夾帶入班級狀態。"
}

$vbs = @"
Set sh = CreateObject("WScript.Shell")
desk = sh.SpecialFolders("Desktop")
ps1 = desk & "\習作台程式\teacher-desk-app.ps1"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """ -WorkDir """ & desk & "\習作台資料"""
sh.Run cmd, 0, False
"@
Set-Content -LiteralPath (Join-Path $appDir '啟動.vbs') -Value $vbs -Encoding ASCII
Set-Content -LiteralPath (Join-Path $desk '習作台.vbs') -Value $vbs -Encoding ASCII

$readme = @"
習作台已安裝（繁體中文介面）

捷徑：桌面「習作台.vbs」
程式：桌面\習作台程式\
資料：桌面\習作台資料\班級狀態.json
掃描：桌面\習作台資料\掃描匯入\

手機版（Safari 加入主畫面）：
https://copyshae.github.io/hello-world/directory/apps/teacher-desk/
"@
Set-Content -LiteralPath (Join-Path $work '安裝說明.txt') -Value $readme -Encoding UTF8

Write-Host "已安裝程式資料夾：$appDir"
Write-Host "已建立工作資料夾：$work"
Write-Host "桌面捷徑：習作台.vbs"
Write-Host "手機版：https://copyshae.github.io/hello-world/directory/apps/teacher-desk/"
