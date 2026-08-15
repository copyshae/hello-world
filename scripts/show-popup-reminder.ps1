#Requires -Version 5.1
<#
.SYNOPSIS
  彈跳式置頂提醒視窗（大字高對比，適合用眼保養提醒）。
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
$form.Size = New-Object System.Drawing.Size(560, 340)
$form.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 245)
$form.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 14)

$header = New-Object System.Windows.Forms.Label
$header.Text = $Title
$header.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 22, [System.Drawing.FontStyle]::Bold)
$header.ForeColor = [System.Drawing.Color]::FromArgb(20, 70, 50)
$header.AutoSize = $false
$header.Location = New-Object System.Drawing.Point(28, 20)
$header.Size = New-Object System.Drawing.Size(490, 42)

$body = New-Object System.Windows.Forms.Label
$body.Text = $Message
$body.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 16)
$body.ForeColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
$body.AutoSize = $false
$body.Location = New-Object System.Drawing.Point(28, 75)
$body.Size = New-Object System.Drawing.Size(490, 140)

$ok = New-Object System.Windows.Forms.Button
$ok.Text = '知道了'
$ok.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 14, [System.Drawing.FontStyle]::Bold)
$ok.Size = New-Object System.Drawing.Size(140, 48)
$ok.Location = New-Object System.Drawing.Point(378, 230)
$ok.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 70)
$ok.ForeColor = [System.Drawing.Color]::White
$ok.FlatStyle = 'Flat'
$ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $ok

$timerLabel = New-Object System.Windows.Forms.Label
$timerLabel.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 12)
$timerLabel.ForeColor = [System.Drawing.Color]::FromArgb(80, 90, 85)
$timerLabel.AutoSize = $false
$timerLabel.Location = New-Object System.Drawing.Point(28, 240)
$timerLabel.Size = New-Object System.Drawing.Size(320, 32)
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
