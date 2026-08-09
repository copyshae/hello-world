#Requires -Version 5.1
<#
.SYNOPSIS
  桌面護眼提醒視窗程式：可彈性修改提醒時間與文案，並常駐提醒。

.DESCRIPTION
  - 大字高對比介面
  - 支援「每日固定時間」與「時段內每隔 N 分鐘」
  - 設定存到同目錄 reminders.json（可手動改，也可在視窗內改）
  - 僅供個人提醒，非醫療指示

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\eye-care-reminder-app.ps1
#>
param(
  [string]$DataDir = '',
  [string]$SyncDir = ''
)

$ErrorActionPreference = 'Stop'
try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

if ([string]::IsNullOrWhiteSpace($DataDir)) {
  $DataDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not (Test-Path -LiteralPath $DataDir)) {
  New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
}
$script:DataDir = $DataDir

# 設定可放 OneDrive 同步；「已提醒過」狀態只留本機，避免兩台搶同一 state
if (-not [string]::IsNullOrWhiteSpace($SyncDir)) {
  New-Item -ItemType Directory -Force -Path $SyncDir | Out-Null
  $script:ConfigPath = Join-Path $SyncDir 'reminders.json'
} else {
  $script:ConfigPath = Join-Path $DataDir 'reminders.json'
}
$localStateDir = Join-Path $env:LOCALAPPDATA 'EyeCareReminder'
New-Item -ItemType Directory -Force -Path $localStateDir | Out-Null
$script:StatePath = Join-Path $localStateDir 'state.json'

function New-DefaultConfig {
  return [ordered]@{
    version = 1
    items   = @(
      @{ id = [guid]::NewGuid().ToString('n'); enabled = $true; kind = 'daily'; time = '07:30'; everyMinutes = 0; windowStart = '07:30'; windowEnd = '17:00'; title = '早安・護眼用藥'; message = "1) 早餐後點眼藥水`n2) 服用百恩晴`n3) 開始日間補水"; autoCloseSeconds = 0 }
      @{ id = [guid]::NewGuid().ToString('n'); enabled = $true; kind = 'daily'; time = '12:00'; everyMinutes = 0; windowStart = '07:30'; windowEnd = '17:00'; title = '午餐・點藥・喝水'; message = "1) 用餐`n2) 點眼藥水`n3) 喝一杯水"; autoCloseSeconds = 0 }
      @{ id = [guid]::NewGuid().ToString('n'); enabled = $true; kind = 'daily'; time = '18:00'; everyMinutes = 0; windowStart = '07:30'; windowEnd = '17:00'; title = '晚餐・點眼藥水'; message = "1) 晚餐`n2) 點眼藥水"; autoCloseSeconds = 0 }
      @{ id = [guid]::NewGuid().ToString('n'); enabled = $true; kind = 'daily'; time = '21:00'; everyMinutes = 0; windowStart = '07:30'; windowEnd = '17:00'; title = '晚上・益生菌'; message = '請服用益生菌'; autoCloseSeconds = 0 }
      @{ id = [guid]::NewGuid().ToString('n'); enabled = $true; kind = 'daily'; time = '22:00'; everyMinutes = 0; windowStart = '07:30'; windowEnd = '17:00'; title = '睡前・點眼藥水'; message = '睡前點眼藥水，關閉螢幕休息'; autoCloseSeconds = 0 }
      @{ id = [guid]::NewGuid().ToString('n'); enabled = $true; kind = 'interval'; time = ''; everyMinutes = 20; windowStart = '07:30'; windowEnd = '17:00'; title = '用眼短休息'; message = "停下螢幕約 20 秒`n看向遠處或閉眼放鬆"; autoCloseSeconds = 0 }
      @{ id = [guid]::NewGuid().ToString('n'); enabled = $true; kind = 'interval'; time = ''; everyMinutes = 60; windowStart = '07:30'; windowEnd = '17:00'; title = '用眼長休息'; message = "離開螢幕約 5 分鐘`n遠眺／走動，勿滑手機"; autoCloseSeconds = 0 }
      @{ id = [guid]::NewGuid().ToString('n'); enabled = $true; kind = 'interval'; time = ''; everyMinutes = 60; windowStart = '07:30'; windowEnd = '17:00'; title = '飲水提醒'; message = '請喝一杯水'; autoCloseSeconds = 0 }
    )
  }
}

function Convert-ToPlain($obj) {
  # ordered/hashtable tree -> PSCustomObject-friendly JSON roundtrip
  return ($obj | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
}

function Save-Config($cfg) {
  $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
}

function Load-Config {
  if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
    $cfg = Convert-ToPlain (New-DefaultConfig)
    Save-Config $cfg
    return $cfg
  }
  try {
    $cfg = Get-Content -LiteralPath $script:ConfigPath -Encoding UTF8 -Raw | ConvertFrom-Json
    # 舊設定若有自動關閉，一律改為 0（避免一閃而過）
    foreach ($it in @($cfg.items)) {
      $it.autoCloseSeconds = 0
    }
    return $cfg
  } catch {
    $cfg = Convert-ToPlain (New-DefaultConfig)
    Save-Config $cfg
    return $cfg
  }
}

function Get-State {
  if (Test-Path -LiteralPath $script:StatePath) {
    try { return (Get-Content -LiteralPath $script:StatePath -Encoding UTF8 -Raw | ConvertFrom-Json) } catch {}
  }
  return [pscustomobject]@{ day = ''; fired = @() }
}

function Save-State($st) {
  $st | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:StatePath -Encoding UTF8
}

function Show-Popup([string]$Title, [string]$Message, [int]$AutoCloseSeconds) {
  # 為避免一閃而過：不自動關閉，必須按「知道了」
  $null = $AutoCloseSeconds

  # 先用系統對話框（最不容易錯過），再顯示大字視窗
  [System.Media.SystemSounds]::Exclamation.Play()
  Start-Sleep -Milliseconds 120
  [System.Media.SystemSounds]::Exclamation.Play()
  [void][System.Windows.Forms.MessageBox]::Show(
    $Message,
    $Title,
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Exclamation
  )

  $form = New-Object System.Windows.Forms.Form
  $script:popupForm = $form
  $form.Text = $Title
  $form.StartPosition = 'CenterScreen'
  $form.FormBorderStyle = 'FixedDialog'
  $form.MaximizeBox = $false
  $form.MinimizeBox = $false
  $form.TopMost = $true
  $form.ShowInTaskbar = $true
  $form.TopLevel = $true
  $form.Size = New-Object System.Drawing.Size(640, 420)
  $form.BackColor = [System.Drawing.Color]::FromArgb(255, 252, 230)

  $h = New-Object System.Windows.Forms.Label
  $h.Text = $Title
  $h.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 26, [System.Drawing.FontStyle]::Bold)
  $h.ForeColor = [System.Drawing.Color]::FromArgb(120, 40, 0)
  $h.Location = New-Object System.Drawing.Point(24, 18)
  $h.Size = New-Object System.Drawing.Size(580, 48)

  $b = New-Object System.Windows.Forms.Label
  $b.Text = $Message
  $b.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 18)
  $b.ForeColor = [System.Drawing.Color]::Black
  $b.Location = New-Object System.Drawing.Point(24, 80)
  $b.Size = New-Object System.Drawing.Size(580, 200)

  $hint = New-Object System.Windows.Forms.Label
  $hint.Text = '不會自動關閉，請按「知道了」'
  $hint.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 12)
  $hint.ForeColor = [System.Drawing.Color]::FromArgb(90, 70, 40)
  $hint.Location = New-Object System.Drawing.Point(24, 290)
  $hint.Size = New-Object System.Drawing.Size(360, 28)

  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = '知道了'
  $ok.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 16, [System.Drawing.FontStyle]::Bold)
  $ok.Size = New-Object System.Drawing.Size(160, 52)
  $ok.Location = New-Object System.Drawing.Point(440, 300)
  $ok.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 20)
  $ok.ForeColor = [System.Drawing.Color]::White
  $ok.FlatStyle = 'Flat'
  $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $form.AcceptButton = $ok

  $form.Controls.AddRange(@($h, $b, $hint, $ok))
  $form.Add_Shown({
      $f = $script:popupForm
      $f.WindowState = 'Normal'
      $f.TopMost = $true
      $f.Activate()
      $f.BringToFront()
      [void]$f.Focus()
    })

  [void]$form.ShowDialog()
}

function Parse-Hm([string]$hm) {
  if ([string]::IsNullOrWhiteSpace($hm)) { return $null }
  $p = $hm.Trim().Split(':')
  if ($p.Count -lt 2) { return $null }
  return @{ H = [int]$p[0]; M = [int]$p[1] }
}

function Item-Summary($it) {
  $en = if ($it.enabled) { '✓' } else { '✗' }
  if ($it.kind -eq 'daily') {
    return ("{0} 每日 {1}｜{2}" -f $en, $it.time, $it.title)
  }
  return ("{0} 每{1}分 {2}-{3}｜{4}" -f $en, $it.everyMinutes, $it.windowStart, $it.windowEnd, $it.title)
}

# -------- UI --------
$script:cfg = Load-Config
$script:running = $false
$script:selectedIndex = -1

$fontUi = New-Object System.Drawing.Font('Microsoft JhengHei UI', 12)
$fontBig = New-Object System.Drawing.Font('Microsoft JhengHei UI', 16, [System.Drawing.FontStyle]::Bold)

$script:mainForm = New-Object System.Windows.Forms.Form
$mainForm = $script:mainForm
$mainForm.Text = '護眼提醒設定'
$mainForm.Size = New-Object System.Drawing.Size(900, 640)
$mainForm.StartPosition = 'CenterScreen'
$mainForm.BackColor = [System.Drawing.Color]::FromArgb(245, 248, 244)
$mainForm.Font = $fontUi
$mainForm.MinimumSize = New-Object System.Drawing.Size(860, 600)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = '護眼提醒（可改時間與文案）'
$lblTitle.Font = $fontBig
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(20, 70, 50)
$lblTitle.Location = New-Object System.Drawing.Point(20, 14)
$lblTitle.Size = New-Object System.Drawing.Size(560, 36)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "設定檔：$($script:ConfigPath)"
$lblPath.Location = New-Object System.Drawing.Point(20, 50)
$lblPath.Size = New-Object System.Drawing.Size(840, 24)
$lblPath.ForeColor = [System.Drawing.Color]::FromArgb(80, 90, 85)

$list = New-Object System.Windows.Forms.ListBox
$list.Location = New-Object System.Drawing.Point(20, 84)
$list.Size = New-Object System.Drawing.Size(420, 400)
$list.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 13)

function Refresh-List {
  $list.Items.Clear()
  $items = @($script:cfg.items)
  for ($i = 0; $i -lt $items.Count; $i++) {
    [void]$list.Items.Add((Item-Summary $items[$i]))
  }
}

$grp = New-Object System.Windows.Forms.GroupBox
$grp.Text = '編輯選取項目'
$grp.Location = New-Object System.Drawing.Point(460, 84)
$grp.Size = New-Object System.Drawing.Size(400, 400)

function Add-LabeledText([int]$y, [string]$label, [int]$width = 250) {
  $lb = New-Object System.Windows.Forms.Label
  $lb.Text = $label
  $lb.Location = New-Object System.Drawing.Point(16, $y)
  $lb.Size = New-Object System.Drawing.Size(110, 28)
  $tb = New-Object System.Windows.Forms.TextBox
  $tb.Location = New-Object System.Drawing.Point(130, ($y - 2))
  $tb.Size = New-Object System.Drawing.Size($width, 30)
  $tb.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 13)
  $grp.Controls.Add($lb)
  $grp.Controls.Add($tb)
  return $tb
}

$cmbKind = New-Object System.Windows.Forms.ComboBox
$cmbKind.DropDownStyle = 'DropDownList'
$cmbKind.Items.AddRange(@('每日固定時間', '時段內每隔N分'))
$cmbKind.Location = New-Object System.Drawing.Point(130, 28)
$cmbKind.Size = New-Object System.Drawing.Size(250, 30)
$cmbKind.SelectedIndex = 0
$lbKind = New-Object System.Windows.Forms.Label
$lbKind.Text = '類型'
$lbKind.Location = New-Object System.Drawing.Point(16, 30)
$lbKind.Size = New-Object System.Drawing.Size(110, 28)
$grp.Controls.Add($lbKind)
$grp.Controls.Add($cmbKind)

$txtTime = Add-LabeledText 70 '時間HH:mm'
$txtEvery = Add-LabeledText 110 '每隔分鐘'
$txtWinStart = Add-LabeledText 150 '時段開始'
$txtWinEnd = Add-LabeledText 190 '時段結束'
$txtTitle = Add-LabeledText 230 '標題'
$txtMsg = New-Object System.Windows.Forms.TextBox
$txtMsg.Multiline = $true
$txtMsg.ScrollBars = 'Vertical'
$txtMsg.Location = New-Object System.Drawing.Point(16, 300)
$txtMsg.Size = New-Object System.Drawing.Size(364, 70)
$txtMsg.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 12)
$lbMsg = New-Object System.Windows.Forms.Label
$lbMsg.Text = '提醒文案'
$lbMsg.Location = New-Object System.Drawing.Point(16, 270)
$lbMsg.Size = New-Object System.Drawing.Size(200, 24)
$chkEnabled = New-Object System.Windows.Forms.CheckBox
$chkEnabled.Text = '啟用'
$chkEnabled.Location = New-Object System.Drawing.Point(300, 268)
$chkEnabled.Size = New-Object System.Drawing.Size(80, 28)
$chkEnabled.Checked = $true
$grp.Controls.AddRange(@($lbMsg, $txtMsg, $chkEnabled))

function Load-EditorFromSelection {
  if ($list.SelectedIndex -lt 0) { return }
  $it = @($script:cfg.items)[$list.SelectedIndex]
  $script:selectedIndex = $list.SelectedIndex
  if ($it.kind -eq 'interval') { $cmbKind.SelectedIndex = 1 } else { $cmbKind.SelectedIndex = 0 }
  $txtTime.Text = [string]$it.time
  $txtEvery.Text = [string]$it.everyMinutes
  $txtWinStart.Text = [string]$it.windowStart
  $txtWinEnd.Text = [string]$it.windowEnd
  $txtTitle.Text = [string]$it.title
  $txtMsg.Text = [string]$it.message
  $chkEnabled.Checked = [bool]$it.enabled
}

$list.Add_SelectedIndexChanged({ Load-EditorFromSelection })

function Read-EditorToItem($existingId) {
  $kind = if ($cmbKind.SelectedIndex -eq 1) { 'interval' } else { 'daily' }
  $every = 0
  [void][int]::TryParse($txtEvery.Text, [ref]$every)
  return [pscustomobject]@{
    id               = $(if ($existingId) { $existingId } else { [guid]::NewGuid().ToString('n') })
    enabled          = [bool]$chkEnabled.Checked
    kind             = $kind
    time             = $txtTime.Text.Trim()
    everyMinutes     = $every
    windowStart      = $(if ($txtWinStart.Text.Trim()) { $txtWinStart.Text.Trim() } else { '07:30' })
    windowEnd        = $(if ($txtWinEnd.Text.Trim()) { $txtWinEnd.Text.Trim() } else { '17:00' })
    title            = $(if ($txtTitle.Text.Trim()) { $txtTitle.Text.Trim() } else { '提醒' })
    message          = $txtMsg.Text
    autoCloseSeconds = 0
  }
}

function Apply-EditorToSelected {
  if ($script:selectedIndex -lt 0 -and $list.SelectedIndex -lt 0) {
    [System.Windows.Forms.MessageBox]::Show('請先選左側一筆，或按「新增」', '提示') | Out-Null
    return
  }
  $idx = $list.SelectedIndex
  if ($idx -lt 0) { $idx = $script:selectedIndex }
  $items = [System.Collections.ArrayList]@($script:cfg.items)
  $oldId = $items[$idx].id
  $items[$idx] = Read-EditorToItem $oldId
  $script:cfg = [pscustomobject]@{ version = 1; items = @($items.ToArray()) }
  Save-Config $script:cfg
  Refresh-List
  $list.SelectedIndex = $idx
  $status.Text = '已套用並儲存'
}

$btnSaveItem = New-Object System.Windows.Forms.Button
$btnSaveItem.Text = '套用這筆'
$btnSaveItem.Location = New-Object System.Drawing.Point(20, 500)
$btnSaveItem.Size = New-Object System.Drawing.Size(120, 42)
$btnSaveItem.Add_Click({ Apply-EditorToSelected })

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = '新增'
$btnAdd.Location = New-Object System.Drawing.Point(150, 500)
$btnAdd.Size = New-Object System.Drawing.Size(90, 42)
$btnAdd.Add_Click({
    $items = [System.Collections.ArrayList]@($script:cfg.items)
    $newItem = Read-EditorToItem $null
    if ([string]::IsNullOrWhiteSpace($newItem.message)) { $newItem.message = '新提醒' }
    if ($newItem.kind -eq 'daily' -and [string]::IsNullOrWhiteSpace($newItem.time)) { $newItem.time = '08:00' }
    if ($newItem.kind -eq 'interval' -and $newItem.everyMinutes -le 0) { $newItem.everyMinutes = 30 }
    [void]$items.Add($newItem)
    $script:cfg = [pscustomobject]@{ version = 1; items = @($items.ToArray()) }
    Save-Config $script:cfg
    Refresh-List
    $list.SelectedIndex = $items.Count - 1
    $status.Text = '已新增'
  })

$btnDel = New-Object System.Windows.Forms.Button
$btnDel.Text = '刪除'
$btnDel.Location = New-Object System.Drawing.Point(250, 500)
$btnDel.Size = New-Object System.Drawing.Size(90, 42)
$btnDel.Add_Click({
    if ($list.SelectedIndex -lt 0) { return }
    $idx = $list.SelectedIndex
    $items = [System.Collections.ArrayList]@($script:cfg.items)
    $items.RemoveAt($idx)
    $script:cfg = [pscustomobject]@{ version = 1; items = @($items.ToArray()) }
    Save-Config $script:cfg
    Refresh-List
    $status.Text = '已刪除'
  })

$btnTest = New-Object System.Windows.Forms.Button
$btnTest.Text = '試播這筆'
$btnTest.Location = New-Object System.Drawing.Point(350, 500)
$btnTest.Size = New-Object System.Drawing.Size(110, 42)
$btnTest.Add_Click({
    $it = Read-EditorToItem 'test'
    Show-Popup $it.title $it.message ([int]$it.autoCloseSeconds)
  })

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = '開始提醒'
$btnStart.Location = New-Object System.Drawing.Point(480, 500)
$btnStart.Size = New-Object System.Drawing.Size(130, 42)
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 70)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatStyle = 'Flat'

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = '停止'
$btnStop.Location = New-Object System.Drawing.Point(620, 500)
$btnStop.Size = New-Object System.Drawing.Size(90, 42)
$btnStop.Enabled = $false

$btnOpenFolder = New-Object System.Windows.Forms.Button
$btnOpenFolder.Text = '開啟資料夾'
$btnOpenFolder.Location = New-Object System.Drawing.Point(720, 500)
$btnOpenFolder.Size = New-Object System.Drawing.Size(140, 42)
$btnOpenFolder.Add_Click({ Start-Process explorer.exe (Split-Path -Parent $script:ConfigPath) })

$status = New-Object System.Windows.Forms.Label
$status.Text = '提示：改完按「套用這筆」→「開始提醒」。僅供提醒，用藥請依醫師指示。'
$status.Location = New-Object System.Drawing.Point(20, 555)
$status.Size = New-Object System.Drawing.Size(840, 30)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 15000

function Test-ShouldFire($it, $now) {
  if (-not $it.enabled) { return $false }
  $nowMin = $now.Hour * 60 + $now.Minute
  if ($it.kind -eq 'daily') {
    $hm = Parse-Hm ([string]$it.time)
    if (-not $hm) { return $false }
    return ($now.Hour -eq $hm.H -and $now.Minute -eq $hm.M)
  }
  # interval
  $a = Parse-Hm ([string]$it.windowStart)
  $b = Parse-Hm ([string]$it.windowEnd)
  if (-not $a -or -not $b) { return $false }
  $startMin = $a.H * 60 + $a.M
  $endMin = $b.H * 60 + $b.M
  if ($nowMin -lt $startMin -or $nowMin -gt $endMin) { return $false }
  $every = [int]$it.everyMinutes
  if ($every -lt 1) { return $false }
  $since = $nowMin - $startMin
  return ($since -gt 0 -and ($since % $every) -eq 0)
}

function Fire-Id($it, $now) {
  if ($it.kind -eq 'daily') {
    return ('{0}|d|{1}' -f $now.ToString('yyyy-MM-dd'), $it.id)
  }
  return ('{0}|i|{1}|{2}' -f $now.ToString('yyyy-MM-dd'), $it.id, ($now.Hour * 60 + $now.Minute))
}

$timer.Add_Tick({
    if (-not $script:running) { return }
    # reload config each tick so external edits apply
    try { $script:cfg = Load-Config } catch {}
    $now = Get-Date
    $st = Get-State
    $today = $now.ToString('yyyy-MM-dd')
    if ($st.day -ne $today) { $st = [pscustomobject]@{ day = $today; fired = @() } }
    $fired = @($st.fired)
    foreach ($it in @($script:cfg.items)) {
      if (-not (Test-ShouldFire $it $now)) { continue }
      $fid = Fire-Id $it $now
      if ($fired -contains $fid) { continue }
      $status.Text = ("提醒中：{0} {1}" -f $now.ToString('HH:mm'), $it.title)
      Show-Popup ([string]$it.title) ([string]$it.message) ([int]$it.autoCloseSeconds)
      $fired += $fid
      $st.day = $today
      $st.fired = $fired
      Save-State $st
    }
    if ($script:running) {
      $status.Text = ("提醒執行中… {0}（每 15 秒檢查）" -f $now.ToString('HH:mm:ss'))
    }
  })

$btnStart.Add_Click({
    if ($list.SelectedIndex -ge 0) { Apply-EditorToSelected }
    else { Save-Config $script:cfg }
    $script:running = $true
    $btnStart.Enabled = $false
    $btnStop.Enabled = $true
    $status.Text = '提醒已開始（可縮到工作列；關閉視窗會停止）'
    $timer.Interval = 15000
    $timer.Start()
  })

$btnStop.Add_Click({
    $script:running = $false
    $timer.Stop()
    $btnStart.Enabled = $true
    $btnStop.Enabled = $false
    $status.Text = '已停止提醒'
  })

$mainForm.Add_FormClosing({
    $script:running = $false
    $timer.Stop()
  })

$mainForm.Controls.AddRange(@(
    $lblTitle, $lblPath, $list, $grp,
    $btnSaveItem, $btnAdd, $btnDel, $btnTest, $btnStart, $btnStop, $btnOpenFolder, $status
  ))

Refresh-List
if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }

[void]$mainForm.ShowDialog()

} catch {
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [void][System.Windows.Forms.MessageBox]::Show(
      ("啟動失敗（不會一閃就沒）：`n`n{0}" -f $_.Exception.Message),
      '護眼提醒',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    )
  } catch {
    # 最後手段：寫入桌面錯誤檔
    $errFile = Join-Path ([Environment]::GetFolderPath('Desktop')) '護眼提醒-錯誤.txt'
    Set-Content -LiteralPath $errFile -Value $_.Exception.ToString() -Encoding UTF8
  }
  exit 1
}
