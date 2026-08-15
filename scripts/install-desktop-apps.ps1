#Requires -Version 5.1
# 一鍵安裝桌面視窗程式（介面與提示皆繁體中文）
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$desk = [Environment]::GetFolderPath('Desktop')

Write-Host "桌面位置：$desk"
Write-Host "安裝腳本：$here"
Write-Host ""

$teacherInstall = Join-Path $here 'install-teacher-desk.ps1'
if (-not (Test-Path -LiteralPath $teacherInstall)) {
  throw "找不到 install-teacher-desk.ps1，請先執行：git pull origin master"
}
& $teacherInstall

$graderInstall = Join-Path $here 'install-math-homework-grader.ps1'
if (Test-Path -LiteralPath $graderInstall) {
  & $graderInstall
} else {
  Write-Host "（略過習作批改：尚未找到安裝腳本）"
}

Write-Host ""
Write-Host "安裝完成。請到桌面雙擊："
Write-Host "  習作台.vbs　　＝　掌握程度／發送練習／與手機同步"
Write-Host "  習作批改.vbs　＝　批閱習作／產出練習（若已安裝）"
Write-Host "工作資料夾："
Write-Host "  桌面\習作台資料\"
Write-Host "  桌面\MathGrading\（習作批改用，內含中文子資料夾）"
