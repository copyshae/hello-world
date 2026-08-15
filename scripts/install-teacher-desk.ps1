#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'teacher-desk-app.ps1'
if (-not (Test-Path -LiteralPath $src)) { throw "找不到 $src" }

$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk 'TeacherDeskApp'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
Copy-Item -LiteralPath $src -Destination (Join-Path $appDir 'teacher-desk-app.ps1') -Force

$work = Join-Path $desk 'TeacherDesk'
New-Item -ItemType Directory -Force -Path $work | Out-Null

$vbs = @"
Set sh = CreateObject("WScript.Shell")
desk = sh.SpecialFolders("Desktop")
ps1 = desk & "\TeacherDeskApp\teacher-desk-app.ps1"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """ -WorkDir """ & desk & "\TeacherDesk"""
sh.Run cmd, 0, False
"@
Set-Content -LiteralPath (Join-Path $appDir 'launch.vbs') -Value $vbs -Encoding ASCII
Set-Content -LiteralPath (Join-Path $desk '習作台.vbs') -Value $vbs -Encoding ASCII

Write-Host "Installed: $appDir"
Write-Host "Work: $work  (class-state.json)"
Write-Host "Desktop shortcut: 習作台.vbs"
Write-Host "Phone PWA: https://copyshae.github.io/hello-world/directory/apps/teacher-desk/"
