#Requires -Version 5.1
<#
  習作台（桌面，繁體中文介面）：掌握程度／發送、LINE 文案、管道偏好、與手機資料互通。
  只用座號、不存姓名。資料：工作夾\班級狀態.json
#>
param([string]$WorkDir = "")

$ErrorActionPreference = 'Stop'
try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
} catch {
  throw "無法載入視窗元件：$_"
}
[System.Windows.Forms.Application]::EnableVisualStyles()
try {
  $zh = [System.Globalization.CultureInfo]::GetCultureInfo('zh-TW')
  [System.Threading.Thread]::CurrentThread.CurrentUICulture = $zh
  [System.Threading.Thread]::CurrentThread.CurrentCulture = $zh
} catch {}

$desk = [Environment]::GetFolderPath('Desktop')
if (-not $WorkDir) {
  $cand = Join-Path $desk '習作台資料'
  $legacy = Join-Path $desk 'TeacherDesk'
  if (Test-Path -LiteralPath $cand) { $WorkDir = $cand }
  elseif (Test-Path -LiteralPath $legacy) { $WorkDir = $legacy }
  else { $WorkDir = $cand }
}
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir '掃描匯入') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir '匯出給手機') | Out-Null

$StatePath = Join-Path $WorkDir '班級狀態.json'
$LegacyStatePath = Join-Path $WorkDir 'class-state.json'
if (-not (Test-Path -LiteralPath $StatePath) -and (Test-Path -LiteralPath $LegacyStatePath)) {
  $StatePath = $LegacyStatePath
}
$script:StatePath = $StatePath
$PhoneUrl = 'https://copyshae.github.io/hello-world/directory/apps/teacher-desk/'

$Levels = @('未標', '跟上', '略落後', '明顯落後', '需補先備')
$Sends  = @('未發', '已發', '待回', '已回')
$SendChMap = [ordered]@{
  line_group = 'LINE 班級群組'
  classroom  = 'Classroom'
  cloud      = '雲端資料夾'
  print      = '無裝置列印'
}
$RetChMap = [ordered]@{
  line_dm   = 'LINE 個別傳老師'
  classroom = 'Classroom'
  cloud     = '雲端回傳夾'
}

function Get-DefaultState {
  [ordered]@{
    classLabel     = '本班數學'
    seatCount      = 30
    deadline       = '今晚 21:00'
    sendChannel    = 'line_group'
    returnChannel  = 'line_dm'
    seats          = @{}
  }
}

function Ensure-Seats($state) {
  $n = 30
  try { $n = [int]$state.seatCount } catch { $n = 30 }
  if ($n -lt 1) { $n = 1 }
  if ($n -gt 60) { $n = 60 }
  $state.seatCount = $n
  if ($null -eq $state.seats) { $state.seats = @{} }
  # 若從 JSON 來是 PSCustomObject，改成 Hashtable
  if ($state.seats -isnot [hashtable]) {
    $state.seats = ConvertTo-SeatHashtable $state.seats
  }
  if (-not $state.sendChannel) { $state.sendChannel = 'line_group' }
  if (-not $state.returnChannel) { $state.returnChannel = 'line_dm' }
  for ($i = 1; $i -le $n; $i++) {
    $id = '{0:D2}' -f $i
    if (-not $state.seats.ContainsKey($id)) {
      $state.seats[$id] = @{ level = '未標'; send = '未發'; note = '' }
    } else {
      $seat = $state.seats[$id]
      if ($seat -is [hashtable]) {
        if (-not $seat.ContainsKey('note')) { $seat['note'] = '' }
        if (-not $seat.ContainsKey('level')) { $seat['level'] = '未標' }
        if (-not $seat.ContainsKey('send')) { $seat['send'] = '未發' }
      } else {
        $state.seats[$id] = @{
          level = $(if ($seat.level) { [string]$seat.level } else { '未標' })
          send  = $(if ($seat.send) { [string]$seat.send } else { '未發' })
          note  = $(if ($seat.note) { [string]$seat.note } else { '' })
        }
      }
    }
  }
  foreach ($k in @($state.seats.Keys)) {
    $num = 0
    if (-not [int]::TryParse($k, [ref]$num) -or $num -lt 1 -or $num -gt $n) {
      $state.seats.Remove($k)
    }
  }
  return $state
}

function ConvertTo-SeatHashtable($obj) {
  $h = @{}
  if (-not $obj) { return $h }
  foreach ($p in $obj.PSObject.Properties) {
    $h[$p.Name] = @{
      level = [string]$p.Value.level
      send  = [string]$p.Value.send
      note  = $(if ($null -ne $p.Value.note) { [string]$p.Value.note } else { '' })
    }
  }
  return $h
}

function Import-StateFromObject($obj) {
  $state = [ordered]@{
    classLabel    = $(if ($obj.classLabel) { [string]$obj.classLabel } else { '本班數學' })
    seatCount     = $(if ($obj.seatCount) { [int]$obj.seatCount } else { 30 })
    deadline      = $(if ($obj.deadline) { [string]$obj.deadline } else { '今晚 21:00' })
    sendChannel   = $(if ($obj.sendChannel) { [string]$obj.sendChannel } else { 'line_group' })
    returnChannel = $(if ($obj.returnChannel) { [string]$obj.returnChannel } else { 'line_dm' })
    seats         = ConvertTo-SeatHashtable $obj.seats
  }
  return (Ensure-Seats $state)
}

function Load-State {
  $path = $script:StatePath
  if (-not (Test-Path -LiteralPath $path)) {
    $alt = Join-Path $WorkDir 'class-state.json'
    if (Test-Path -LiteralPath $alt) { $path = $alt; $script:StatePath = $alt }
  }
  if (Test-Path -LiteralPath $path) {
    try {
      $obj = (Get-Content -LiteralPath $path -Raw -Encoding UTF8) | ConvertFrom-Json
      return (Import-StateFromObject $obj)
    } catch {}
  }
  return (Ensure-Seats (Get-DefaultState))
}

function Save-State($state) {
  if (-not $script:StatePath) {
    $script:StatePath = Join-Path $WorkDir '班級狀態.json'
  }
  # 優先寫入繁中檔名
  if ($script:StatePath -like '*class-state.json') {
    $script:StatePath = Join-Path $WorkDir '班級狀態.json'
  }
  $seatsObj = [ordered]@{}
  foreach ($k in ($state.seats.Keys | Sort-Object)) { $seatsObj[$k] = $state.seats[$k] }
  $out = [ordered]@{
    classLabel    = $state.classLabel
    seatCount     = $state.seatCount
    deadline      = $state.deadline
    sendChannel   = $state.sendChannel
    returnChannel = $state.returnChannel
    seats         = $seatsObj
  }
  ($out | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $script:StatePath -Encoding UTF8
}

function Get-LevelColor([string]$level) {
  switch ($level) {
    '跟上'     { return [Drawing.Color]::FromArgb(220, 245, 230) }
    '略落後'   { return [Drawing.Color]::FromArgb(255, 248, 220) }
    '明顯落後' { return [Drawing.Color]::FromArgb(255, 235, 220) }
    '需補先備' { return [Drawing.Color]::FromArgb(255, 228, 228) }
    default    { return [Drawing.Color]::FromArgb(245, 248, 246) }
  }
}

$script:State = Load-State
$script:Filter = 'all'
$script:SelectedId = $null

function Test-SeatFilter($s) {
  switch ($script:Filter) {
    '未發' { return ($s.send -eq '未發') }
    '待回' { return ($s.send -eq '待回' -or $s.send -eq '已發') }
    '先備' { return ($s.level -eq '需補先備') }
    '關注' {
      return ($s.level -in @('略落後','明顯落後','需補先備') -or $s.send -in @('未發','待回'))
    }
    default { return $true }
  }
}

function Get-UnsentIds {
  $unsent = @()
  foreach ($k in ($script:State.seats.Keys | Sort-Object)) {
    if ($script:State.seats[$k].send -eq '未發') { $unsent += $k }
  }
  if ($unsent.Count -eq 0) {
    foreach ($k in ($script:State.seats.Keys | Sort-Object)) {
      $s = $script:State.seats[$k]
      if ($s.send -ne '已回' -and ($s.send -in @('已發','待回') -or $s.level -in @('略落後','明顯落後','需補先備'))) {
        $unsent += $k
      }
    }
  }
  return $unsent
}

function Build-SendMessage {
  $ids = @(Get-UnsentIds)
  $list = if ($ids.Count) { ($ids -join '、') } else { '（請先點座號標「未發」）' }
  @"
【$($script:State.classLabel)｜今日練習】
請座號：$list
1. 依老師發的檔／連結完成練習（含指導與影片）
2. 完成後請「個別傳老師」，不要傳班級群組
3. 截止：$($script:State.deadline)
有問題先看指導；仍不懂再私訊老師。
"@
}

function Build-ReturnMessage {
  @"
【$($script:State.classLabel)｜回傳方式】
請用 LINE「個別傳老師」交練習圖／PDF。
檔名建議：座號-次數，例如 05-R01.jpg
不要傳進班級群組，方便老師對座號批改。
"@
}

# —— UI ——
$form = New-Object Windows.Forms.Form
$form.Text = '習作台｜掌握與發送'
$form.Size = New-Object Drawing.Size(980, 700)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Microsoft JhengHei UI', 10)
$form.BackColor = [Drawing.Color]::FromArgb(232, 239, 230)
$form.MinimumSize = New-Object Drawing.Size(860, 600)

$top = New-Object Windows.Forms.Panel
$top.Dock = 'Top'; $top.Height = 88
$top.BackColor = [Drawing.Color]::FromArgb(45, 106, 79)
$form.Controls.Add($top)

$lblBrand = New-Object Windows.Forms.Label
$lblBrand.Text = '習作台'; $lblBrand.ForeColor = [Drawing.Color]::White
$lblBrand.Font = New-Object Drawing.Font('Microsoft JhengHei UI', 18, [Drawing.FontStyle]::Bold)
$lblBrand.Location = New-Object Drawing.Point(16, 10); $lblBrand.AutoSize = $true
$top.Controls.Add($lblBrand)

$lblSub = New-Object Windows.Forms.Label
$lblSub.Text = '繁體中文介面 · 與手機版同功能 · 班級資料可互通'
$lblSub.ForeColor = [Drawing.Color]::FromArgb(220, 240, 230)
$lblSub.Location = New-Object Drawing.Point(18, 50); $lblSub.AutoSize = $true
$top.Controls.Add($lblSub)

# settings row
$y = 100
function Add-Lbl($text, $x) {
  $l = New-Object Windows.Forms.Label
  $l.Text = $text; $l.Location = New-Object Drawing.Point($x, ($y + 4)); $l.AutoSize = $true
  $form.Controls.Add($l); return $l
}
[void](Add-Lbl '班級' 16)
$txtClass = New-Object Windows.Forms.TextBox
$txtClass.Text = $script:State.classLabel; $txtClass.Location = New-Object Drawing.Point(56, $y); $txtClass.Width = 120
$form.Controls.Add($txtClass)
[void](Add-Lbl '人數' 186)
$numSeats = New-Object Windows.Forms.NumericUpDown
$numSeats.Minimum = 1; $numSeats.Maximum = 60
$numSeats.Value = [Math]::Max(1, [Math]::Min(60, [decimal]$script:State.seatCount))
$numSeats.Location = New-Object Drawing.Point(226, $y); $numSeats.Width = 55
$form.Controls.Add($numSeats)
[void](Add-Lbl '截止' 290)
$txtDeadline = New-Object Windows.Forms.TextBox
$txtDeadline.Text = $script:State.deadline; $txtDeadline.Location = New-Object Drawing.Point(330, $y); $txtDeadline.Width = 110
$form.Controls.Add($txtDeadline)
[void](Add-Lbl '發放' 450)
$cmbSendCh = New-Object Windows.Forms.ComboBox
$cmbSendCh.DropDownStyle = 'DropDownList'; $cmbSendCh.Location = New-Object Drawing.Point(490, $y); $cmbSendCh.Width = 130
foreach ($k in $SendChMap.Keys) { [void]$cmbSendCh.Items.Add($SendChMap[$k]) }
$cmbSendCh.SelectedItem = $SendChMap[$script:State.sendChannel]
if (-not $cmbSendCh.SelectedItem) { $cmbSendCh.SelectedIndex = 0 }
$form.Controls.Add($cmbSendCh)
[void](Add-Lbl '回傳' 630)
$cmbRetCh = New-Object Windows.Forms.ComboBox
$cmbRetCh.DropDownStyle = 'DropDownList'; $cmbRetCh.Location = New-Object Drawing.Point(670, $y); $cmbRetCh.Width = 140
foreach ($k in $RetChMap.Keys) { [void]$cmbRetCh.Items.Add($RetChMap[$k]) }
$cmbRetCh.SelectedItem = $RetChMap[$script:State.returnChannel]
if (-not $cmbRetCh.SelectedItem) { $cmbRetCh.SelectedIndex = 0 }
$form.Controls.Add($cmbRetCh)

$btnApply = New-Object Windows.Forms.Button
$btnApply.Text = '套用'; $btnApply.Location = New-Object Drawing.Point(820, ($y - 2)); $btnApply.Width = 70
$form.Controls.Add($btnApply)

$lblSummary = New-Object Windows.Forms.Label
$lblSummary.Location = New-Object Drawing.Point(16, 136); $lblSummary.AutoSize = $true
$lblSummary.ForeColor = [Drawing.Color]::FromArgb(45, 106, 79)
$form.Controls.Add($lblSummary)

# filter chips
$filterPanel = New-Object Windows.Forms.FlowLayoutPanel
$filterPanel.Location = New-Object Drawing.Point(16, 160); $filterPanel.Size = New-Object Drawing.Size(540, 34)
$form.Controls.Add($filterPanel)
$script:FilterButtons = @{}
foreach ($f in @('all','未發','待回','關注','先備')) {
  $caption = if ($f -eq 'all') { '全部' } elseif ($f -eq '關注') { '需關注' } elseif ($f -eq '先備') { '需補先備' } else { $f }
  $fb = New-Object Windows.Forms.Button
  $fb.Text = $caption; $fb.Tag = $f; $fb.Width = 72; $fb.Height = 28; $fb.FlatStyle = 'Flat'
  $fb.Add_Click({
    param($sender, $e)
    $script:Filter = [string]$sender.Tag
    Refresh-Filters
    Refresh-Grid
  })
  $filterPanel.Controls.Add($fb)
  $script:FilterButtons[$f] = $fb
}

$gridHost = New-Object Windows.Forms.FlowLayoutPanel
$gridHost.Location = New-Object Drawing.Point(16, 198)
$gridHost.Size = New-Object Drawing.Size(540, 300)
$gridHost.Anchor = 'Top,Bottom,Left'
$gridHost.AutoScroll = $true; $gridHost.WrapContents = $true
$form.Controls.Add($gridHost)

$right = New-Object Windows.Forms.Panel
$right.Location = New-Object Drawing.Point(570, 160)
$right.Size = New-Object Drawing.Size(380, 340)
$right.Anchor = 'Top,Bottom,Right'
$form.Controls.Add($right)

$lblSid = New-Object Windows.Forms.Label
$lblSid.Text = '座號：—（點左側）'
$lblSid.Font = New-Object Drawing.Font('Microsoft JhengHei UI', 11, [Drawing.FontStyle]::Bold)
$lblSid.AutoSize = $true
$right.Controls.Add($lblSid)

$cmbLevel = New-Object Windows.Forms.ComboBox
$cmbLevel.DropDownStyle = 'DropDownList'; $cmbLevel.Location = New-Object Drawing.Point(0, 36); $cmbLevel.Width = 170
$Levels | ForEach-Object { [void]$cmbLevel.Items.Add($_) }; $cmbLevel.SelectedIndex = 0
$right.Controls.Add($cmbLevel)

$cmbSend = New-Object Windows.Forms.ComboBox
$cmbSend.DropDownStyle = 'DropDownList'; $cmbSend.Location = New-Object Drawing.Point(180, 36); $cmbSend.Width = 170
$Sends | ForEach-Object { [void]$cmbSend.Items.Add($_) }; $cmbSend.SelectedIndex = 0
$right.Controls.Add($cmbSend)

$txtNote = New-Object Windows.Forms.TextBox
$txtNote.Location = New-Object Drawing.Point(0, 72); $txtNote.Width = 350
$right.Controls.Add($txtNote)

$btnSaveSeat = New-Object Windows.Forms.Button
$btnSaveSeat.Text = '儲存此座號'; $btnSaveSeat.Location = New-Object Drawing.Point(0, 108)
$btnSaveSeat.Width = 350; $btnSaveSeat.Height = 34
$btnSaveSeat.BackColor = [Drawing.Color]::FromArgb(45, 106, 79)
$btnSaveSeat.ForeColor = [Drawing.Color]::White; $btnSaveSeat.FlatStyle = 'Flat'
$right.Controls.Add($btnSaveSeat)

$btnCopySend = New-Object Windows.Forms.Button
$btnCopySend.Text = '複製 LINE 群發文'; $btnCopySend.Location = New-Object Drawing.Point(0, 152)
$btnCopySend.Width = 350; $btnCopySend.Height = 36
$btnCopySend.BackColor = [Drawing.Color]::FromArgb(45, 106, 79)
$btnCopySend.ForeColor = [Drawing.Color]::White; $btnCopySend.FlatStyle = 'Flat'
$right.Controls.Add($btnCopySend)

$btnCopyRet = New-Object Windows.Forms.Button
$btnCopyRet.Text = '複製回傳說明'; $btnCopyRet.Location = New-Object Drawing.Point(0, 194)
$btnCopyRet.Width = 170; $btnCopyRet.Height = 32
$right.Controls.Add($btnCopyRet)

$btnMarkSent = New-Object Windows.Forms.Button
$btnMarkSent.Text = '未發→已發'; $btnMarkSent.Location = New-Object Drawing.Point(180, 194)
$btnMarkSent.Width = 170; $btnMarkSent.Height = 32
$right.Controls.Add($btnMarkSent)

$btnMarkPending = New-Object Windows.Forms.Button
$btnMarkPending.Text = '已發→待回'; $btnMarkPending.Location = New-Object Drawing.Point(0, 232)
$btnMarkPending.Width = 170; $btnMarkPending.Height = 32
$right.Controls.Add($btnMarkPending)

$btnExport = New-Object Windows.Forms.Button
$btnExport.Text = '匯出班級資料'; $btnExport.Location = New-Object Drawing.Point(180, 232)
$btnExport.Width = 170; $btnExport.Height = 32
$right.Controls.Add($btnExport)

$btnImport = New-Object Windows.Forms.Button
$btnImport.Text = '匯入班級資料'; $btnImport.Location = New-Object Drawing.Point(0, 270)
$btnImport.Width = 170; $btnImport.Height = 32
$right.Controls.Add($btnImport)

$btnPhone = New-Object Windows.Forms.Button
$btnPhone.Text = '開啟手機版'; $btnPhone.Location = New-Object Drawing.Point(180, 270)
$btnPhone.Width = 170; $btnPhone.Height = 32
$right.Controls.Add($btnPhone)

$btnFolder = New-Object Windows.Forms.Button
$btnFolder.Text = '開啟工作夾'; $btnFolder.Location = New-Object Drawing.Point(0, 308)
$btnFolder.Width = 170; $btnFolder.Height = 28
$right.Controls.Add($btnFolder)

$btnScanFolder = New-Object Windows.Forms.Button
$btnScanFolder.Text = '掃描匯入夾'; $btnScanFolder.Location = New-Object Drawing.Point(180, 308)
$btnScanFolder.Width = 170; $btnScanFolder.Height = 28
$right.Controls.Add($btnScanFolder)

$txtPreview = New-Object Windows.Forms.TextBox
$txtPreview.Multiline = $true; $txtPreview.ScrollBars = 'Vertical'; $txtPreview.ReadOnly = $true
$txtPreview.Location = New-Object Drawing.Point(16, 510)
$txtPreview.Size = New-Object Drawing.Size(934, 130)
$txtPreview.Anchor = 'Left,Right,Bottom'
$txtPreview.Font = New-Object Drawing.Font('Microsoft JhengHei UI', 9.5)
$form.Controls.Add($txtPreview)

function Get-SendChannelKey {
  foreach ($k in $SendChMap.Keys) {
    if ($SendChMap[$k] -eq [string]$cmbSendCh.SelectedItem) { return $k }
  }
  return 'line_group'
}
function Get-RetChannelKey {
  foreach ($k in $RetChMap.Keys) {
    if ($RetChMap[$k] -eq [string]$cmbRetCh.SelectedItem) { return $k }
  }
  return 'line_dm'
}

function Persist-Header {
  $script:State.classLabel = $txtClass.Text.Trim()
  if (-not $script:State.classLabel) { $script:State.classLabel = '本班數學' }
  $script:State.deadline = $txtDeadline.Text.Trim()
  if (-not $script:State.deadline) { $script:State.deadline = '今晚 21:00' }
  $script:State.seatCount = [int]$numSeats.Value
  $script:State.sendChannel = Get-SendChannelKey
  $script:State.returnChannel = Get-RetChannelKey
  $script:State = Ensure-Seats $script:State
  Save-State $script:State
}

function Update-Summary {
  $c = @{ '跟上'=0; '略落後'=0; '明顯落後'=0; '需補先備'=0; '未發'=0; '待回'=0 }
  foreach ($k in $script:State.seats.Keys) {
    $s = $script:State.seats[$k]
    if ($c.ContainsKey($s.level)) { $c[$s.level]++ }
    if ($s.send -eq '未發') { $c['未發']++ }
    if ($s.send -in @('待回','已發')) { $c['待回']++ }
  }
  $lblSummary.Text = ("跟上{0} 略落後{1} 明顯{2} 先備{3}｜未發{4} 待回{5}　發={6}／回={7}" -f `
    $c['跟上'], $c['略落後'], $c['明顯落後'], $c['需補先備'], $c['未發'], $c['待回'], `
    $SendChMap[$script:State.sendChannel], $RetChMap[$script:State.returnChannel])
}

function Refresh-Filters {
  foreach ($k in $script:FilterButtons.Keys) {
    $b = $script:FilterButtons[$k]
    if ($k -eq $script:Filter) {
      $b.BackColor = [Drawing.Color]::FromArgb(45, 106, 79)
      $b.ForeColor = [Drawing.Color]::White
    } else {
      $b.BackColor = [Drawing.Color]::White
      $b.ForeColor = [Drawing.Color]::FromArgb(45, 106, 79)
    }
  }
}

function Refresh-Preview { $txtPreview.Text = Build-SendMessage }

function Refresh-Grid {
  $gridHost.SuspendLayout()
  $gridHost.Controls.Clear()
  foreach ($k in ($script:State.seats.Keys | Sort-Object)) {
    $s = $script:State.seats[$k]
    $b = New-Object Windows.Forms.Button
    $b.Size = New-Object Drawing.Size(70, 50)
    $b.Margin = New-Object Windows.Forms.Padding(3)
    $b.FlatStyle = 'Flat'
    $b.Text = "$k`n$($s.send)"
    $b.BackColor = Get-LevelColor $s.level
    $b.Tag = $k
    if (-not (Test-SeatFilter $s)) { $b.Enabled = $false }
    $b.Add_Click({
      param($sender, $e)
      $id = [string]$sender.Tag
      $script:SelectedId = $id
      $seat = $script:State.seats[$id]
      $lblSid.Text = "座號：$id"
      $cmbLevel.SelectedItem = $seat.level
      $cmbSend.SelectedItem = $seat.send
      $txtNote.Text = $seat.note
    })
    $gridHost.Controls.Add($b)
  }
  $gridHost.ResumeLayout()
  Update-Summary
  Refresh-Preview
}

function Sync-FormFromState {
  $txtClass.Text = $script:State.classLabel
  $numSeats.Value = [Math]::Max(1, [Math]::Min(60, [decimal]$script:State.seatCount))
  $txtDeadline.Text = $script:State.deadline
  $cmbSendCh.SelectedItem = $SendChMap[$script:State.sendChannel]
  if (-not $cmbSendCh.SelectedItem) { $cmbSendCh.SelectedIndex = 0 }
  $cmbRetCh.SelectedItem = $RetChMap[$script:State.returnChannel]
  if (-not $cmbRetCh.SelectedItem) { $cmbRetCh.SelectedIndex = 0 }
}

$btnApply.Add_Click({ Persist-Header; Refresh-Grid; $txtPreview.Text = "已套用。`n`n" + (Build-SendMessage) })
$btnSaveSeat.Add_Click({
  if (-not $script:SelectedId) {
    [Windows.Forms.MessageBox]::Show('請先點左側座號。', '習作台') | Out-Null; return
  }
  Persist-Header
  $id = $script:SelectedId
  $script:State.seats[$id].level = [string]$cmbLevel.SelectedItem
  $script:State.seats[$id].send = [string]$cmbSend.SelectedItem
  $script:State.seats[$id].note = $txtNote.Text.Trim()
  Save-State $script:State
  Refresh-Grid
})
$btnCopySend.Add_Click({
  Persist-Header
  $msg = Build-SendMessage
  [Windows.Forms.Clipboard]::SetText($msg)
  $txtPreview.Text = $msg
  [Windows.Forms.MessageBox]::Show('已複製，請貼到 LINE 班級群。', '習作台') | Out-Null
})
$btnCopyRet.Add_Click({
  Persist-Header
  $msg = Build-ReturnMessage
  [Windows.Forms.Clipboard]::SetText($msg)
  $txtPreview.Text = $msg
})
$btnMarkSent.Add_Click({
  Persist-Header
  foreach ($k in @($script:State.seats.Keys)) {
    if ($script:State.seats[$k].send -eq '未發') { $script:State.seats[$k].send = '已發' }
  }
  Save-State $script:State; Refresh-Grid
})
$btnMarkPending.Add_Click({
  Persist-Header
  foreach ($k in @($script:State.seats.Keys)) {
    if ($script:State.seats[$k].send -eq '已發') { $script:State.seats[$k].send = '待回' }
  }
  Save-State $script:State; Refresh-Grid
})
$btnExport.Add_Click({
  Persist-Header
  $dlg = New-Object Windows.Forms.SaveFileDialog
  $dlg.Title = '匯出班級資料'
  $dlg.Filter = '班級資料檔 (*.json)|*.json|所有檔案 (*.*)|*.*'
  $dlg.FileName = '班級狀態.json'
  $dlg.InitialDirectory = (Join-Path $WorkDir '匯出給手機')
  if ($dlg.ShowDialog() -eq 'OK') {
    Copy-Item -LiteralPath $script:StatePath -Destination $dlg.FileName -Force
    [Windows.Forms.MessageBox]::Show("已匯出：`n$($dlg.FileName)`n可傳到手機習作台匯入。", '習作台') | Out-Null
  }
})
$btnImport.Add_Click({
  $dlg = New-Object Windows.Forms.OpenFileDialog
  $dlg.Title = '匯入班級資料'
  $dlg.Filter = '班級資料檔 (*.json)|*.json|所有檔案 (*.*)|*.*'
  $dlg.InitialDirectory = $WorkDir
  if ($dlg.ShowDialog() -eq 'OK') {
    try {
      $obj = (Get-Content -LiteralPath $dlg.FileName -Raw -Encoding UTF8) | ConvertFrom-Json
      $script:State = Import-StateFromObject $obj
      $script:StatePath = Join-Path $WorkDir '班級狀態.json'
      Save-State $script:State
      Sync-FormFromState
      $script:SelectedId = $null
      $lblSid.Text = '座號：—'
      Refresh-Grid
      [Windows.Forms.MessageBox]::Show('已匯入並覆蓋目前班級資料。', '習作台') | Out-Null
    } catch {
      [Windows.Forms.MessageBox]::Show('匯入失敗，請確認檔案是習作台匯出的班級資料。', '習作台') | Out-Null
    }
  }
})
$btnPhone.Add_Click({
  [Windows.Forms.Clipboard]::SetText($PhoneUrl)
  Start-Process $PhoneUrl
})
$btnFolder.Add_Click({ Start-Process explorer.exe $WorkDir })
$btnScanFolder.Add_Click({
  $scan = Join-Path $WorkDir '掃描匯入'
  New-Item -ItemType Directory -Force -Path $scan | Out-Null
  Start-Process explorer.exe $scan
})
$form.Add_FormClosing({
  try {
    Persist-Header
    if ($script:SelectedId -and $cmbLevel.SelectedItem) {
      $script:State.seats[$script:SelectedId].level = [string]$cmbLevel.SelectedItem
      $script:State.seats[$script:SelectedId].send = [string]$cmbSend.SelectedItem
      $script:State.seats[$script:SelectedId].note = $txtNote.Text.Trim()
    }
    Save-State $script:State
  } catch {}
})

Refresh-Filters
Refresh-Grid
[void]$form.ShowDialog()
} catch {
  $msg = "習作台啟動失敗：`n$($_.Exception.Message)`n`n$($_.ScriptStackTrace)"
  try {
    [void][System.Windows.Forms.MessageBox]::Show($msg, '習作台錯誤')
  } catch {
    Write-Host $msg
  }
  exit 1
}
