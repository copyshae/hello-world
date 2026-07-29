# 將「推日誌」捷徑安裝到本機（所有專案可用）
#
# 用法（任一台電腦執行一次）：
#   cd <hello-world 倉庫>
#   powershell -ExecutionPolicy Bypass -File .\install-push-log-shortcut.ps1
#
# 來源：本倉庫 .cursor/skills 與 .cursor/rules
# 目標：%USERPROFILE%\.cursor\skills 與 %USERPROFILE%\.cursor\rules

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$srcSkill = Join-Path $root '.cursor\skills\push-learning-log\SKILL.md'
$srcRule = Join-Path $root '.cursor\rules\push-learning-log.mdc'

if (-not (Test-Path -LiteralPath $srcSkill)) { throw "找不到 $srcSkill（請先 git pull）" }
if (-not (Test-Path -LiteralPath $srcRule)) { throw "找不到 $srcRule（請先 git pull）" }

$destSkillDir = Join-Path $env:USERPROFILE '.cursor\skills\push-learning-log'
$destRuleDir = Join-Path $env:USERPROFILE '.cursor\rules'
New-Item -ItemType Directory -Force -Path $destSkillDir, $destRuleDir | Out-Null

Copy-Item -LiteralPath $srcSkill -Destination (Join-Path $destSkillDir 'SKILL.md') -Force
Copy-Item -LiteralPath $srcRule -Destination (Join-Path $destRuleDir 'push-learning-log.mdc') -Force

Write-Host '已安裝到本機（適用所有 Cursor 專案）：'
Write-Host "  skill: $destSkillDir\SKILL.md"
Write-Host "  rule:  $destRuleDir\push-learning-log.mdc"
Write-Host ''
Write-Host '請重新開啟 Cursor 對話後，輸入：推日誌'
