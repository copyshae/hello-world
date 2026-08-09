#Requires -Version 5.1
<#
.SYNOPSIS
  護眼／用藥／飲水／用餐 定時彈跳提醒（背景常駐）。

.DESCRIPTION
  依 eye-care-reminders.config.json：
  - 07:30 早餐：點眼藥水 + 百恩晴 + 開始補水時段
  - 07:30～17:00：用眼休息（預設每 20 分遠眺 20 秒；每 60 分休息 5 分）、飲水
  - 12:00 午餐＋點藥水＋喝水
  - 18:00 晚餐＋點藥水
  - 21:00 益生菌
  - 22:00 睡前點藥水

  本工具僅提醒，不取代醫師指示。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\start-eye-care-reminders.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\start-eye-care-reminders.ps1 -Once   # 只檢查當下應否提醒後結束
#>
[CmdletBinding()]
param(
  [string]$ConfigPath = '',
  [switch]$Once,
  [switch]$NoSound
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = Join-Path $ScriptDir 'eye-care-reminders.config.json'
}
$PopupPs1 = Join-Path $ScriptDir 'show-popup-reminder.ps1'
if (-not (Test-Path -LiteralPath $PopupPs1)) {
  throw "找不到 $PopupPs1"
}
if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "找不到設定檔 $ConfigPath"
}

$cfg = Get-Content -LiteralPath $ConfigPath -Encoding UTF8 -Raw | ConvertFrom-Json
$stateDir = Join-Path $env:LOCALAPPDATA 'hello-world-eye-care'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$statePath = Join-Path $stateDir 'state.json'

function Get-State {
  if (Test-Path -LiteralPath $statePath) {
    try {
      return (Get-Content -LiteralPath $statePath -Encoding UTF8 -Raw | ConvertFrom-Json)
    } catch {}
  }
  return [pscustomobject]@{ day = ''; fired = @() }
}

function Save-State($st) {
  ($st | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $statePath -Encoding UTF8
}

function Parse-Hm([string]$hm) {
  $parts = $hm.Split(':')
  return @{ H = [int]$parts[0]; M = [int]$parts[1] }
}

function Get-MinutesOfDay([datetime]$dt) {
  return ($dt.Hour * 60 + $dt.Minute)
}

function Show-Reminder {
  param([string]$Id, [string]$Title, [string]$Message, [int]$AutoClose = 0)
  $st = Get-State
  $today = (Get-Date).ToString('yyyy-MM-dd')
  if ($st.day -ne $today) {
    $st = [pscustomobject]@{ day = $today; fired = @() }
  }
  $fired = @($st.fired)
  if ($fired -contains $Id) { return $false }

  Write-Host ("[{0}] {1} — {2}" -f (Get-Date -Format 'HH:mm:ss'), $Title, $Message)
  $args = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', $PopupPs1,
    '-Title', $Title,
    '-Message', $Message
  )
  if ($AutoClose -gt 0) { $args += @('-AutoCloseSeconds', "$AutoClose") }
  if ($NoSound) { $args += '-NoSound' }

  Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Wait

  $fired += $Id
  $st.day = $today
  $st.fired = $fired
  Save-State $st
  return $true
}

function Test-InWindow($nowMin, $startMin, $endMin) {
  return ($nowMin -ge $startMin -and $nowMin -le $endMin)
}

Write-Host '護眼提醒常駐中（關閉此視窗即停止）。Ctrl+C 結束。'
Write-Host ("設定檔: {0}" -f $ConfigPath)
Write-Host '僅供個人提醒，用藥／點藥請依醫師指示。'
Write-Host ''

while ($true) {
  $now = Get-Date
  $nowMin = Get-MinutesOfDay $now
  $dayKey = $now.ToString('yyyy-MM-dd')

  $start = Parse-Hm $cfg.dayStart
  $end = Parse-Hm $cfg.dayEnd
  $lunch = Parse-Hm $cfg.lunchTime
  $dinner = Parse-Hm $cfg.dinnerTime
  $probiotic = Parse-Hm $cfg.probioticTime
  $bed = Parse-Hm $cfg.bedtimeDropsTime

  $startMin = $start.H * 60 + $start.M
  $endMin = $end.H * 60 + $end.M
  $lunchMin = $lunch.H * 60 + $lunch.M
  $dinnerMin = $dinner.H * 60 + $dinner.M
  $probioticMin = $probiotic.H * 60 + $probiotic.M
  $bedMin = $bed.H * 60 + $bed.M

  # --- 固定時段 ---
  if ($now.Hour -eq $start.H -and $now.Minute -eq $start.M) {
    [void](Show-Reminder -Id ($dayKey + '|morning') -Title '早安・護眼用藥' -Message ("現在 {0}`n1) 早餐後點眼藥水`n2) 服用「百恩晴」`n3) 開始補水（至下午 {1}）`n右眼雷射後請避免長時間盯螢幕。" -f $cfg.dayStart, $cfg.dayEnd))
  }

  if ($now.Hour -eq $lunch.H -and $now.Minute -eq $lunch.M) {
    [void](Show-Reminder -Id ($dayKey + '|lunch') -Title '午餐・點藥・喝水' -Message ("現在 {0} 用餐時間`n1) 用餐`n2) 點眼藥水`n3) 喝一杯水`n用餐後可閉眼休息片刻。" -f $cfg.lunchTime))
  }

  if ($now.Hour -eq $dinner.H -and $now.Minute -eq $dinner.M) {
    [void](Show-Reminder -Id ($dayKey + '|dinner') -Title '晚餐・點眼藥水' -Message ("現在 {0}`n1) 晚餐`n2) 點眼藥水（三餐之一）`n用眼請放慢，光線勿過暗。" -f $cfg.dinnerTime))
  }

  if ($now.Hour -eq $probiotic.H -and $now.Minute -eq $probiotic.M) {
    [void](Show-Reminder -Id ($dayKey + '|probiotic') -Title '晚上・益生菌' -Message ("現在 {0}`n請服用益生菌。`n稍後睡前還要再點一次眼藥水。" -f $cfg.probioticTime))
  }

  if ($now.Hour -eq $bed.H -and $now.Minute -eq $bed.M) {
    [void](Show-Reminder -Id ($dayKey + '|bed') -Title '睡前・點眼藥水' -Message ("現在 {0}`n睡前點眼藥水。`n螢幕請關閉，讓眼睛充分休息。" -f $cfg.bedtimeDropsTime))
  }

  # --- 日間區間：用眼休息、飲水（避開與整點固定提醒同一分鐘） ---
  $inDay = Test-InWindow $nowMin $startMin $endMin
  $onFixed = (
    ($nowMin -eq $startMin) -or ($nowMin -eq $lunchMin) -or
    ($nowMin -eq $dinnerMin) -or ($nowMin -eq $probioticMin) -or ($nowMin -eq $bedMin)
  )

  if ($inDay -and -not $onFixed) {
    $sinceStart = $nowMin - $startMin

    # 長休息優先（每 60 分）
    $longEvery = [int]$cfg.longEyeRestEveryMinutes
    if ($longEvery -lt 1) { $longEvery = 60 }
    if ($sinceStart -gt 0 -and ($sinceStart % $longEvery) -eq 0) {
      $id = '{0}|longrest|{1}' -f $dayKey, $nowMin
      $mins = [int]$cfg.longEyeRestMinutes
      if ($mins -lt 1) { $mins = 5 }
      [void](Show-Reminder -Id $id -Title '用眼長休息' -Message ("已連續用眼一段時間。`n請離開螢幕休息約 {0} 分鐘：`n遠眺／閉目／走動，勿滑手機。" -f $mins) -AutoClose 0)
    }
    else {
      $shortEvery = [int]$cfg.eyeRestEveryMinutes
      if ($shortEvery -lt 1) { $shortEvery = 20 }
      if ($sinceStart -gt 0 -and ($sinceStart % $shortEvery) -eq 0) {
        $id = '{0}|eyrest|{1}' -f $dayKey, $nowMin
        $sec = [int]$cfg.eyeRestSeconds
        if ($sec -lt 10) { $sec = 20 }
        [void](Show-Reminder -Id $id -Title '用眼短休息' -Message ("停下螢幕 {0} 秒。`n看向 6 公尺外景物，或閉眼放鬆。`n（白內障／黃斑部／雷射後保養）" -f $sec) -AutoClose ([Math]::Max($sec + 10, 25)))
      }
    }

    $waterEvery = [int]$cfg.waterEveryMinutes
    if ($waterEvery -lt 1) { $waterEvery = 60 }
    if ($sinceStart -gt 0 -and ($sinceStart % $waterEvery) -eq 0 -and $nowMin -ne $lunchMin) {
      $id = '{0}|water|{1}' -f $dayKey, $nowMin
      [void](Show-Reminder -Id $id -Title '飲水提醒' -Message "請喝一杯水。`n日間（$($cfg.dayStart)–$($cfg.dayEnd)）請保持補水。" -AutoClose 20)
    }
  }

  if ($Once) { break }
  Start-Sleep -Seconds 20
}
