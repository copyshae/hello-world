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
foreach ($n in @('標準答案', '輸入', '輸出', '認知輸入', '重謄補充')) {
  New-Item -ItemType Directory -Force -Path (Join-Path $work $n) | Out-Null
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

Write-Host "Installed: $appDir"
Write-Host "Work: $work  (put each student one file in 輸入\)"
Write-Host "Desktop shortcut: 習作批改.vbs"
Write-Host "Need Python + pip install pypdf reportlab for PDF output"
