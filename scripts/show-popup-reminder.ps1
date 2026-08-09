#Requires -Version 5.1
<#
.SYNOPSIS
  彈跳式置頂提醒視窗（WinForms）。

.DESCRIPTION
  螢幕中央跳出提醒；可立刻顯示，或 -DelayMinutes 延遲後再跳。
  適合「Takeout 下載好了嗎」「該備份了」這類一次性提醒。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\show-popup-reminder.ps1 -Message "記得下載 Google Takeout"
  powershell -ExecutionPolicy Bypass -File .\scripts\show-popup-reminder.ps1 -Title "備份提醒" -Message "檢查 E:\GOOGLE相簿" -DelayMinutes 30
  powershell -ExecutionPolicy Bypass -File .\scripts\show-popup-reminder.ps1 -Message "喝水休息" -AutoCloseSeconds 20
#>
[CmdletBinding()]
param(
  [string]$Title = '提醒',
  [Parameter(Mandatory = $true)]
  [string]$Message,
  [int]$DelayMinutes = 0,
  [int]$AutoCloseSeconds = 0,
  [switch]$NoSound
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

if ($DelayMinutes -gt 0) {
  Write-Host ("將在 {0} 分鐘後跳出提醒…" -f $DelayMinutes)
  Start-Sleep -Seconds ($DelayMinutes * 60)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = $Title
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true
$form.ShowInTaskbar = $true
$form.Size = New-Object System.Drawing.Size(460, 260)
$form.BackColor = [System.Drawing.Color]::FromArgb(232, 239, 230)
$form.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 11)

$header = New-Object System.Windows.Forms.Label
$header.Text = $Title
$header.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 14, [System.Drawing.FontStyle]::Bold)
$header.ForeColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
$header.AutoSize = $false
$header.Location = New-Object System.Drawing.Point(24, 18)
$header.Size = New-Object System.Drawing.Size(400, 32)

$body = New-Object System.Windows.Forms.Label
$body.Text = $Message
$body.ForeColor = [System.Drawing.Color]::FromArgb(26, 31, 28)
$body.AutoSize = $false
$body.Location = New-Object System.Drawing.Point(24, 60)
$body.Size = New-Object System.Drawing.Size(400, 100)

$ok = New-Object System.Windows.Forms.Button
$ok.Text = '知道了'
$ok.Size = New-Object System.Drawing.Size(120, 36)
$ok.Location = New-Object System.Drawing.Point(310, 170)
$ok.BackColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
$ok.ForeColor = [System.Drawing.Color]::White
$ok.FlatStyle = 'Flat'
$ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $ok

$timerLabel = New-Object System.Windows.Forms.Label
$timerLabel.ForeColor = [System.Drawing.Color]::FromArgb(74, 92, 82)
$timerLabel.AutoSize = $false
$timerLabel.Location = New-Object System.Drawing.Point(24, 175)
$timerLabel.Size = New-Object System.Drawing.Size(260, 28)
$timerLabel.Text = ''

$form.Controls.AddRange(@($header, $body, $ok, $timerLabel))

if ($AutoCloseSeconds -gt 0) {
  $script:left = $AutoCloseSeconds
  $timerLabel.Text = ("{0} 秒後自動關閉" -f $script:left)
  $t = New-Object System.Windows.Forms.Timer
  $t.Interval = 1000
  $t.Add_Tick({
      $script:left--
      if ($script:left -le 0) {
        $t.Stop()
        $form.Close()
      } else {
        $timerLabel.Text = ("{0} 秒後自動關閉" -f $script:left)
      }
    })
  $t.Start()
}

if (-not $NoSound) {
  [System.Media.SystemSounds]::Asterisk.Play()
}

[void]$form.ShowDialog()
