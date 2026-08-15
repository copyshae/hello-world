#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'math-homework-grader-app.ps1'
if (-not (Test-Path -LiteralPath $src)) { throw "找不到 $src" }

$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk 'MathGradingApp'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
Copy-Item -LiteralPath $src -Destination (Join-Path $appDir 'math-homework-grader-app.ps1') -Force

# 預設工作樹
$work = Join-Path $desk 'MathGrading'
foreach ($n in @('標準答案', '輸入', '輸出')) {
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

Write-Host "Installed."
Write-Host "Work folder: $work"
Write-Host "Put each student PDF/image into: $work\輸入"
Write-Host "Double-click Desktop: 習作批改.vbs"
