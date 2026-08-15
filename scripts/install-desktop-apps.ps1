#Requires -Version 5.1
# 電腦完整版一鍵安裝：習作台（掌握／發送）＋習作批改（批閱／產練習）
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$desk = [Environment]::GetFolderPath('Desktop')

Write-Host "===== 電腦完整版安裝 ====="
Write-Host "桌面：$desk"
Write-Host ""

$teacherInstall = Join-Path $here 'install-teacher-desk.ps1'
if (-not (Test-Path -LiteralPath $teacherInstall)) {
  throw "找不到 install-teacher-desk.ps1，請先 git pull origin master"
}
& $teacherInstall

$graderInstall = Join-Path $here 'install-math-homework-grader.ps1'
if (Test-Path -LiteralPath $graderInstall) {
  & $graderInstall
} else {
  Write-Host "（略過習作批改：找不到安裝腳本）"
}

Write-Host ""
Write-Host "===== 安裝完成（電腦完整版）====="
Write-Host "請雙擊桌面："
Write-Host "  習作台.cmd　　＝　掌握程度／發送／篩選／與手機同步"
Write-Host "  習作批改.vbs　＝　批閱習作／自產練習（完整批改流程）"
Write-Host "資料夾："
Write-Host "  桌面\習作台資料\"
Write-Host "  桌面\MathGrading\"
Write-Host "手機版：https://copyshae.github.io/hello-world/directory/apps/teacher-desk/"
