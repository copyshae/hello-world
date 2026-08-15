#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'math-homework-grader-app.ps1'
$py = Join-Path $here 'math_grade_make_note_pdf.py'
if (-not (Test-Path -LiteralPath $src)) { throw "找不到 $src" }

$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk 'MathGradingApp'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
Copy-Item -LiteralPath $src -Destination (Join-Path $appDir 'math-homework-grader-app.ps1') -Force
if (Test-Path -LiteralPath $py) {
  Copy-Item -LiteralPath $py -Destination (Join-Path $appDir 'math_grade_make_note_pdf.py') -Force
}

$work = Join-Path $desk 'MathGrading'
foreach ($n in @('標準答案', '輸入', '輸出', '認知輸入', '重謄補充', '數位練習', '列印專用', '練習回傳', '練習歷程', '手寫匯入')) {
  New-Item -ItemType Directory -Force -Path (Join-Path $work $n) | Out-Null
}
$printList = Join-Path (Join-Path $work '列印專用') '需列印座號.txt'
if (-not (Test-Path -LiteralPath $printList)) {
  @(
    '# 沒有手機／平板等通訊裝置、需要紙本練習的座號'
    '# 一行一個，或用逗號分隔，例如：03  或  07, 12, 18'
    ''
  ) | Set-Content -LiteralPath $printList -Encoding UTF8
}

$vbs = @"
Set sh = CreateObject("WScript.Shell")
desk = sh.SpecialFolders("Desktop")
ps1 = desk & "\MathGradingApp\math-homework-grader-app.ps1"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """ -WorkDir """ & desk & "\MathGrading"""
sh.Run cmd, 0, False
"@
Set-Content -LiteralPath (Join-Path $appDir 'launch.vbs') -Value $vbs -Encoding ASCII
Set-Content -LiteralPath (Join-Path $desk '習作批改.vbs') -Value $vbs -Encoding ASCII

Write-Host "已安裝程式資料夾：$appDir"
Write-Host "已建立工作資料夾：$work（請把每位學生一檔放進「輸入」）"
Write-Host "桌面捷徑：習作批改.vbs"
Write-Host "產出 PDF 需安裝 Python，並執行：pip install pypdf reportlab"
