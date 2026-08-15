#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk 'MathGradingApp'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
$url = 'https://raw.githubusercontent.com/copyshae/hello-world/master/scripts/math-homework-grader-app.ps1'
$dest = Join-Path $appDir 'math-homework-grader-app.ps1'
Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
# 確認有 Gemini 選項
$txt = Get-Content -LiteralPath $dest -Raw -Encoding UTF8
if ($txt -notmatch '請 Gemini') { throw '下載的腳本沒有 Gemini 選項，請稍後再試' }
Write-Host "已更新：$dest"
Write-Host "請關閉舊的「習作批改」視窗後，再雙擊桌面 習作批改.vbs"
Write-Host "批閱方式應出現：請 Gemini 直接批閱／請 Gemini 手寫加強批閱"
