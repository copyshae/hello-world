#Requires -Version 5.1
# 一鍵安裝桌面視窗：習作台（必要）＋習作批改（若倉庫有檔）
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$desk = [Environment]::GetFolderPath('Desktop')
Write-Host "Desktop: $desk"
Write-Host "Scripts: $here"

$teacherInstall = Join-Path $here 'install-teacher-desk.ps1'
if (-not (Test-Path -LiteralPath $teacherInstall)) {
  throw "找不到 install-teacher-desk.ps1（請先 git pull）"
}
& $teacherInstall

# 掃描匯入夾（給 CS／手機下載的 PDF 圖）
$scanIn = Join-Path (Join-Path $desk 'TeacherDesk') '掃描匯入'
New-Item -ItemType Directory -Force -Path $scanIn | Out-Null

$graderInstall = Join-Path $here 'install-math-homework-grader.ps1'
if (Test-Path -LiteralPath $graderInstall) {
  & $graderInstall
} else {
  Write-Host "（略過習作批改：倉庫尚無 install-math-homework-grader.ps1）"
}

Write-Host ""
Write-Host "完成。請看桌面捷徑："
Write-Host "  習作台.vbs     = 掌握／發送／與手機同步"
Write-Host "  習作批改.vbs   = 批閱／產練習（若已安裝）"
Write-Host "工作夾：Desktop\TeacherDesk\  與  Desktop\MathGrading\"
