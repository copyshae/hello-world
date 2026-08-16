# Install "push learning log" shortcut for all Cursor projects on this PC.
#
# Usage (run once on each computer):
#   cd <hello-world repo>
#   powershell -ExecutionPolicy Bypass -File .\install-push-log-shortcut.ps1
#
# Source: this repo .cursor/skills and .cursor/rules
# Destination: %USERPROFILE%\.cursor\skills and %USERPROFILE%\.cursor\rules

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$srcSkill = Join-Path $root '.cursor\skills\push-learning-log\SKILL.md'
$srcRule = Join-Path $root '.cursor\rules\push-learning-log.mdc'

if (-not (Test-Path -LiteralPath $srcSkill)) {
  throw "Missing skill file. Run git pull first: $srcSkill"
}
if (-not (Test-Path -LiteralPath $srcRule)) {
  throw "Missing rule file. Run git pull first: $srcRule"
}

$destSkillDir = Join-Path $env:USERPROFILE '.cursor\skills\push-learning-log'
$destRuleDir = Join-Path $env:USERPROFILE '.cursor\rules'
New-Item -ItemType Directory -Force -Path $destSkillDir, $destRuleDir | Out-Null

Copy-Item -LiteralPath $srcSkill -Destination (Join-Path $destSkillDir 'SKILL.md') -Force
Copy-Item -LiteralPath $srcRule -Destination (Join-Path $destRuleDir 'push-learning-log.mdc') -Force

$deskSkill = Join-Path $root '.cursor\skills\install-desktop-apps\SKILL.md'
$deskRule = Join-Path $root '.cursor\rules\install-desktop-apps.mdc'
if ((Test-Path -LiteralPath $deskSkill) -and (Test-Path -LiteralPath $deskRule)) {
  $deskSkillDir = Join-Path $env:USERPROFILE '.cursor\skills\install-desktop-apps'
  New-Item -ItemType Directory -Force -Path $deskSkillDir | Out-Null
  Copy-Item -LiteralPath $deskSkill -Destination (Join-Path $deskSkillDir 'SKILL.md') -Force
  Copy-Item -LiteralPath $deskRule -Destination (Join-Path $destRuleDir 'install-desktop-apps.mdc') -Force
}

Write-Host 'Installed for all Cursor projects on this PC:'
Write-Host ("  skill: {0}\SKILL.md" -f $destSkillDir)
Write-Host ("  rule:  {0}\push-learning-log.mdc" -f $destRuleDir)
Write-Host ''
Write-Host 'Reopen a Cursor chat, then type the shortcut: tui-ri-zhi'
Write-Host 'Desktop apps shortcut: 裝習作台和習作批改'