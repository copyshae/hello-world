#Requires -Version 5.1
<#
.SYNOPSIS
  登入 Windows 時自動啟動護眼提醒常駐。
#>
[CmdletBinding()]
param(
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartPs1 = Join-Path $ScriptDir 'start-eye-care-reminders.ps1'
$TaskName = 'HelloWorld-EyeCareReminders'

if ($Uninstall) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "已移除工作排程: $TaskName"
  exit 0
}

if (-not (Test-Path -LiteralPath $StartPs1)) {
  throw "找不到 $StartPs1"
}

$arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File "{0}"' -f $StartPs1
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "已登錄：登入後自動啟動「$TaskName」"
Write-Host "立刻手動啟動："
Write-Host ('  powershell -ExecutionPolicy Bypass -File "{0}"' -f $StartPs1)
Write-Host "移除："
Write-Host ('  powershell -ExecutionPolicy Bypass -File "{0}" -Uninstall' -f $MyInvocation.MyCommand.Path)
