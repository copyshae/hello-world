#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk 'MathGradingApp'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
$url = 'https://raw.githubusercontent.com/copyshae/hello-world/master/scripts/math-homework-grader-app.ps1'
$dest = Join-Path $appDir 'math-homework-grader-app.ps1'
Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
$txt = Get-Content -LiteralPath $dest -Raw -Encoding UTF8
if ($txt -notmatch '請 Gemini 自動批閱') { throw '下載的腳本沒有 Gemini 自動批閱，請稍後再試' }
Write-Host "已更新：$dest"
Write-Host "請關閉舊的「習作批改」視窗後，再雙擊桌面 習作批改.vbs"
Write-Host "1) 按「Gemini金鑰」貼上 aistudio.google.com/apikey 的 key"
Write-Host "2) 批閱方式選「請 Gemini 自動批閱（API）」→ 開始批此生（免手動貼檔）"
