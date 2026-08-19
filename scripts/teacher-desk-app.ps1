#Requires -Version 5.1
# 習作台｜電腦完整版（繁體中文）
# 掌握程度／發送、篩選、管道、LINE 文案、匯入匯出、掃描夾
param([string]$WorkDir = "")

$ErrorActionPreference = 'Stop'
$desk = [Environment]::GetFolderPath('Desktop')
$logPath = Join-Path $desk '習作台錯誤.txt'
$PhoneUrl = 'https://copyshae.github.io/hello-world/directory/apps/teacher-desk/'

function Write-LaunchLog([string]$text) {
  try {
    $enc = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($logPath, $text, $enc)
  } catch {}
}

function Show-Fail([string]$text) {
  Write-LaunchLog $text
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [void][System.Windows.Forms.MessageBox]::Show($text, '習作台錯誤')
  } catch { Write-Host $text }
}

function New-UiFont([double]$size, [System.Drawing.FontStyle]$style = [System.Drawing.FontStyle]::Regular) {
  foreach ($name in @('Microsoft JhengHei UI', 'Microsoft JhengHei', 'Segoe UI', 'Tahoma')) {
    try { return New-Object System.Drawing.Font($name, $size, $style) } catch {}
  }
  return [System.Drawing.SystemFonts]::DefaultFont
}

try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()

  if ([string]::IsNullOrWhiteSpace($WorkDir)) {
    $cand = Join-Path $desk '習作台資料'
    $legacy = Join-Path $desk 'TeacherDesk'
    if (Test-Path -LiteralPath $cand) { $WorkDir = $cand }
    elseif (Test-Path -LiteralPath $legacy) { $WorkDir = $legacy }
    else { $WorkDir = $cand }
  }
  New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
  foreach ($sub in @('掃描匯入', '練習回傳', '匯出給手機')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir $sub) | Out-Null
  }

  $Levels = @('未標', '跟上', '略落後', '明顯落後', '需補先備')
  $Sends = @('未發', '已發', '待回', '已回')
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
    $seats = @{}
    $seats['00'] = @{ level = '未標'; send = '未發'; note = '試發' }
    for ($i = 1; $i -le 35; $i++) {
      $id = '{0:D2}' -f $i
      $seats[$id] = @{ level = '未標'; send = '未發'; note = '' }
    }
    return @{
      classLabel    = '本班數學'
      seatCount     = 35
      deadline      = '今晚 21:00'
      sendChannel   = 'line_group'
      returnChannel = 'line_dm'
      seats         = $seats
    }
  }

  function Ensure-State($st) {
    if ($null -eq $st) { return (Get-DefaultState) }
    $n = 35
    try { $n = [int]$st.seatCount } catch { $n = 35 }
    if ($n -lt 1) { $n = 1 }
    if ($n -gt 60) { $n = 60 }
    $st.seatCount = $n
    if (-not $st.classLabel) { $st.classLabel = '本班數學' }
    if (-not $st.deadline) { $st.deadline = '今晚 21:00' }
    if (-not $st.sendChannel) { $st.sendChannel = 'line_group' }
    if (-not $st.returnChannel) { $st.returnChannel = 'line_dm' }

    $seats = @{}
    if ($st.seats -is [hashtable]) {
      foreach ($k in @($st.seats.Keys)) { $seats[$k] = $st.seats[$k] }
    } elseif ($st.seats) {
      foreach ($p in $st.seats.PSObject.Properties) {
        $v = $p.Value
        $seats[$p.Name] = @{
          level = $(if ($v.level) { [string]$v.level } else { '未標' })
          send  = $(if ($v.send) { [string]$v.send } else { '未發' })
          note  = $(if ($v.note) { [string]$v.note } else { '' })
        }
      }
    }
    # 試發座號 00（固定保留）
    if (-not $seats.ContainsKey('00')) {
      $seats['00'] = @{ level = '未標'; send = '未發'; note = '試發' }
    } else {
      $t0 = $seats['00']
      if ($t0 -isnot [hashtable]) {
        $seats['00'] = @{
          level = $(if ($t0.level) { [string]$t0.level } else { '未標' })
          send  = $(if ($t0.send) { [string]$t0.send } else { '未發' })
          note  = $(if ($t0.note) { [string]$t0.note } else { '試發' })
        }
      } else {
        if (-not $t0.ContainsKey('note') -or -not $t0.note) { $t0['note'] = '試發' }
        if (-not $t0.ContainsKey('level') -or -not $t0.level) { $t0['level'] = '未標' }
        if (-not $t0.ContainsKey('send') -or -not $t0.send) { $t0['send'] = '未發' }
      }
    }
    for ($i = 1; $i -le $n; $i++) {
      $id = '{0:D2}' -f $i
      if (-not $seats.ContainsKey($id)) {
        $seats[$id] = @{ level = '未標'; send = '未發'; note = '' }
      } else {
        $s = $seats[$id]
        if ($s -isnot [hashtable]) {
          $seats[$id] = @{
            level = $(if ($s.level) { [string]$s.level } else { '未標' })
            send  = $(if ($s.send) { [string]$s.send } else { '未發' })
            note  = $(if ($s.note) { [string]$s.note } else { '' })
          }
        } else {
          if (-not $s.ContainsKey('level') -or -not $s.level) { $s['level'] = '未標' }
          if (-not $s.ContainsKey('send') -or -not $s.send) { $s['send'] = '未發' }
          if (-not $s.ContainsKey('note')) { $s['note'] = '' }
        }
      }
    }
    foreach ($k in @($seats.Keys)) {
      if ($k -eq '00') { continue }
      $num = 0
      if (-not [int]::TryParse($k, [ref]$num) -or $num -lt 1 -or $num -gt $n) { $seats.Remove($k) }
    }
    $st.seats = $seats
    return $st
  }

  function Save-StateFile($st, $path) {
    $obj = [ordered]@{
      classLabel    = $st.classLabel
      seatCount     = $st.seatCount
      deadline      = $st.deadline
      sendChannel   = $st.sendChannel
      returnChannel = $st.returnChannel
      seats         = [ordered]@{}
    }
    foreach ($k in ($st.seats.Keys | Sort-Object)) { $obj.seats[$k] = $st.seats[$k] }
    $json = $obj | ConvertTo-Json -Depth 6
    $enc = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($path, $json, $enc)
  }

  function Load-StateFile($path) {
    if (-not (Test-Path -LiteralPath $path)) { return (Ensure-State (Get-DefaultState)) }
    try {
      $obj = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
      $st = @{
        classLabel    = [string]$obj.classLabel
        seatCount     = [int]$obj.seatCount
        deadline      = [string]$obj.deadline
        sendChannel   = [string]$obj.sendChannel
        returnChannel = [string]$obj.returnChannel
        seats         = $obj.seats
      }
      return (Ensure-State $st)
    } catch {
      return (Ensure-State (Get-DefaultState))
    }
  }

  function Get-LevelColor([string]$level) {
    switch ($level) {
      '跟上'     { return [System.Drawing.Color]::FromArgb(220, 245, 230) }
      '略落後'   { return [System.Drawing.Color]::FromArgb(255, 248, 220) }
      '明顯落後' { return [System.Drawing.Color]::FromArgb(255, 235, 220) }
      '需補先備' { return [System.Drawing.Color]::FromArgb(255, 228, 228) }
      default    { return [System.Drawing.Color]::FromArgb(245, 248, 246) }
    }
  }

  function Get-SeatRoundFromName([string]$fileName) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $seat = ''
    $round = 1
    $m = [regex]::Match($base, '(\d{1,2})\s*[-_ ]\s*[RrＲｒ]\s*0*(\d{1,2})\b')
    if ($m.Success) {
      $seat = '{0:D2}' -f [int]$m.Groups[1].Value
      $round = [Math]::Max(1, [int]$m.Groups[2].Value)
      return @{ SeatId = $seat; Round = $round }
    }
    $m = [regex]::Match($base, '^(\d{1,2})$')
    if ($m.Success) {
      $seat = '{0:D2}' -f [int]$m.Groups[1].Value
      return @{ SeatId = $seat; Round = $round }
    }
    $m = [regex]::Match($base, '(?:座號|座)\s*(\d{1,2})\b')
    if ($m.Success) {
      $seat = '{0:D2}' -f [int]$m.Groups[1].Value
      return @{ SeatId = $seat; Round = $round }
    }
    return @{ SeatId = $seat; Round = $round }
  }

  function Get-SuggestedScanName([string]$seatId, [int]$round, [string]$fileName) {
    $sid = if ($seatId) { $seatId } else { '00' }
    $ext = [System.IO.Path]::GetExtension($fileName)
    if ([string]::IsNullOrWhiteSpace($ext)) { $ext = '.pdf' }
    return ('{0}-R{1:D2}{2}' -f $sid, $round, $ext.ToLowerInvariant())
  }

  function Test-SeatFilter($s) {
    switch ($script:Filter) {
      '未發' { return ($s.send -eq '未發') }
      '待回' { return ($s.send -eq '待回' -or $s.send -eq '已發') }
      '先備' { return ($s.level -eq '需補先備') }
      '關注' {
        return ($s.level -in @('略落後', '明顯落後', '需補先備') -or $s.send -in @('未發', '待回'))
      }
      default { return $true }
    }
  }

  function Get-UnsentIds {
    $ids = @()
    foreach ($k in ($script:State.seats.Keys | Sort-Object)) {
      if ($script:State.seats[$k].send -eq '未發') { $ids += $k }
    }
    if ($ids.Count -eq 0) {
      foreach ($k in ($script:State.seats.Keys | Sort-Object)) {
        $s = $script:State.seats[$k]
        if ($s.send -ne '已回' -and ($s.send -in @('已發', '待回') -or $s.level -in @('略落後', '明顯落後', '需補先備'))) {
          $ids += $k
        }
      }
    }
    return ,$ids
  }

  function Build-SendMessage {
    $ids = @(Get-UnsentIds)
    $list = if ($ids.Count) { ($ids -join '、') } else { '（請先把要發的座號標成未發）' }
    return @"
【$($script:State.classLabel)｜今日練習】
請座號：$list
1. 依老師發的檔／連結完成練習（含指導與影片）
2. 完成後請「個別傳老師」，不要傳班級群組
3. 截止：$($script:State.deadline)
有問題先看指導；仍不懂再私訊老師。
"@
  }

  function Build-ReturnMessage {
    return @"
【$($script:State.classLabel)｜回傳方式】
請用 LINE「個別傳老師」交練習圖／PDF。
檔名建議：座號-次數，例如 05-R01.jpg
不要傳進班級群組，方便老師對座號批改。
"@
  }

  $statePath = Join-Path $WorkDir '班級狀態.json'
  $legacyPath = Join-Path $WorkDir 'class-state.json'
  if (-not (Test-Path -LiteralPath $statePath) -and (Test-Path -LiteralPath $legacyPath)) {
    $statePath = $legacyPath
  }
  $script:StatePath = Join-Path $WorkDir '班級狀態.json'
  $script:State = Load-StateFile $statePath
  $script:SelectedId = $null
  $script:Filter = 'all'
  $script:FilterButtons = @{}

  $uiFont = New-UiFont 10
  $form = New-Object System.Windows.Forms.Form
  $form.Text = '習作台｜電腦完整版'
  $form.Size = New-Object System.Drawing.Size(980, 720)
  $form.StartPosition = 'CenterScreen'
  $form.Font = $uiFont
  $form.BackColor = [System.Drawing.Color]::FromArgb(232, 239, 230)
  $form.MinimumSize = New-Object System.Drawing.Size(860, 580)

  $top = New-Object System.Windows.Forms.Panel
  $top.Dock = 'Top'; $top.Height = 78
  $top.BackColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
  $form.Controls.Add($top)

  $lblBrand = New-Object System.Windows.Forms.Label
  $lblBrand.Text = '習作台'
  $lblBrand.ForeColor = [System.Drawing.Color]::White
  $lblBrand.Font = New-UiFont 16 ([System.Drawing.FontStyle]::Bold)
  $lblBrand.Location = New-Object System.Drawing.Point(14, 8); $lblBrand.AutoSize = $true
  $top.Controls.Add($lblBrand)

  $lblSub = New-Object System.Windows.Forms.Label
  $lblSub.Text = '電腦完整版 · 掌握／發送／篩選／管道／與手機資料互通'
  $lblSub.ForeColor = [System.Drawing.Color]::FromArgb(220, 240, 230)
  $lblSub.Location = New-Object System.Drawing.Point(16, 44); $lblSub.AutoSize = $true
  $top.Controls.Add($lblSub)

  $y = 92
  $lblClass = New-Object System.Windows.Forms.Label
  $lblClass.Text = '班級'; $lblClass.Location = New-Object System.Drawing.Point(16, ($y + 4)); $lblClass.AutoSize = $true
  $form.Controls.Add($lblClass)
  $txtClass = New-Object System.Windows.Forms.TextBox
  $txtClass.Text = $script:State.classLabel
  $txtClass.Location = New-Object System.Drawing.Point(56, $y); $txtClass.Width = 110
  $form.Controls.Add($txtClass)

  $lblCount = New-Object System.Windows.Forms.Label
  $lblCount.Text = '人數'; $lblCount.Location = New-Object System.Drawing.Point(178, ($y + 4)); $lblCount.AutoSize = $true
  $form.Controls.Add($lblCount)
  $numSeats = New-Object System.Windows.Forms.NumericUpDown
  $numSeats.Minimum = 1; $numSeats.Maximum = 60
  $numSeats.Value = [Math]::Max(1, [Math]::Min(60, [decimal]$script:State.seatCount))
  $numSeats.Location = New-Object System.Drawing.Point(218, $y); $numSeats.Width = 50
  $form.Controls.Add($numSeats)

  $lblDl = New-Object System.Windows.Forms.Label
  $lblDl.Text = '截止'; $lblDl.Location = New-Object System.Drawing.Point(280, ($y + 4)); $lblDl.AutoSize = $true
  $form.Controls.Add($lblDl)
  $txtDeadline = New-Object System.Windows.Forms.TextBox
  $txtDeadline.Text = $script:State.deadline
  $txtDeadline.Location = New-Object System.Drawing.Point(320, $y); $txtDeadline.Width = 100
  $form.Controls.Add($txtDeadline)

  $lblSendCh = New-Object System.Windows.Forms.Label
  $lblSendCh.Text = '發放'; $lblSendCh.Location = New-Object System.Drawing.Point(432, ($y + 4)); $lblSendCh.AutoSize = $true
  $form.Controls.Add($lblSendCh)
  $cmbSendCh = New-Object System.Windows.Forms.ComboBox
  $cmbSendCh.DropDownStyle = 'DropDownList'
  $cmbSendCh.Location = New-Object System.Drawing.Point(472, $y); $cmbSendCh.Width = 120
  foreach ($k in $SendChMap.Keys) { [void]$cmbSendCh.Items.Add($SendChMap[$k]) }
  $cmbSendCh.SelectedItem = $SendChMap[$script:State.sendChannel]
  if (-not $cmbSendCh.SelectedItem) { $cmbSendCh.SelectedIndex = 0 }
  $form.Controls.Add($cmbSendCh)

  $lblRetCh = New-Object System.Windows.Forms.Label
  $lblRetCh.Text = '回傳'; $lblRetCh.Location = New-Object System.Drawing.Point(602, ($y + 4)); $lblRetCh.AutoSize = $true
  $form.Controls.Add($lblRetCh)
  $cmbRetCh = New-Object System.Windows.Forms.ComboBox
  $cmbRetCh.DropDownStyle = 'DropDownList'
  $cmbRetCh.Location = New-Object System.Drawing.Point(642, $y); $cmbRetCh.Width = 130
  foreach ($k in $RetChMap.Keys) { [void]$cmbRetCh.Items.Add($RetChMap[$k]) }
  $cmbRetCh.SelectedItem = $RetChMap[$script:State.returnChannel]
  if (-not $cmbRetCh.SelectedItem) { $cmbRetCh.SelectedIndex = 0 }
  $form.Controls.Add($cmbRetCh)

  $btnApply = New-Object System.Windows.Forms.Button
  $btnApply.Text = '套用'; $btnApply.Location = New-Object System.Drawing.Point(786, ($y - 2)); $btnApply.Width = 70
  $form.Controls.Add($btnApply)

  $lblSummary = New-Object System.Windows.Forms.Label
  $lblSummary.Location = New-Object System.Drawing.Point(16, 128); $lblSummary.AutoSize = $true
  $lblSummary.ForeColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
  $form.Controls.Add($lblSummary)

  $filterPanel = New-Object System.Windows.Forms.FlowLayoutPanel
  $filterPanel.Location = New-Object System.Drawing.Point(16, 152)
  $filterPanel.Size = New-Object System.Drawing.Size(540, 34)
  $form.Controls.Add($filterPanel)

  $gridHost = New-Object System.Windows.Forms.FlowLayoutPanel
  $gridHost.Location = New-Object System.Drawing.Point(16, 190)
  $gridHost.Size = New-Object System.Drawing.Size(540, 300)
  $gridHost.AutoScroll = $true; $gridHost.WrapContents = $true
  $gridHost.Anchor = 'Top,Bottom,Left'
  $form.Controls.Add($gridHost)

  $right = New-Object System.Windows.Forms.Panel
  $right.Location = New-Object System.Drawing.Point(570, 152)
  $right.Size = New-Object System.Drawing.Size(380, 340)
  $right.Anchor = 'Top,Bottom,Right'
  $form.Controls.Add($right)

  $lblSid = New-Object System.Windows.Forms.Label
  $lblSid.Text = '座號：—（點左側）'
  $lblSid.Font = New-UiFont 11 ([System.Drawing.FontStyle]::Bold)
  $lblSid.AutoSize = $true
  $right.Controls.Add($lblSid)

  $cmbLevel = New-Object System.Windows.Forms.ComboBox
  $cmbLevel.DropDownStyle = 'DropDownList'
  $cmbLevel.Location = New-Object System.Drawing.Point(0, 34); $cmbLevel.Width = 170
  $Levels | ForEach-Object { [void]$cmbLevel.Items.Add($_) }; $cmbLevel.SelectedIndex = 0
  $right.Controls.Add($cmbLevel)

  $cmbSend = New-Object System.Windows.Forms.ComboBox
  $cmbSend.DropDownStyle = 'DropDownList'
  $cmbSend.Location = New-Object System.Drawing.Point(180, 34); $cmbSend.Width = 170
  $Sends | ForEach-Object { [void]$cmbSend.Items.Add($_) }; $cmbSend.SelectedIndex = 0
  $right.Controls.Add($cmbSend)

  $txtNote = New-Object System.Windows.Forms.TextBox
  $txtNote.Location = New-Object System.Drawing.Point(0, 70); $txtNote.Width = 350
  $right.Controls.Add($txtNote)

  $btnSaveSeat = New-Object System.Windows.Forms.Button
  $btnSaveSeat.Text = '儲存此座號'
  $btnSaveSeat.Location = New-Object System.Drawing.Point(0, 106)
  $btnSaveSeat.Size = New-Object System.Drawing.Size(350, 34)
  $btnSaveSeat.BackColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
  $btnSaveSeat.ForeColor = [System.Drawing.Color]::White
  $btnSaveSeat.FlatStyle = 'Flat'
  $right.Controls.Add($btnSaveSeat)

  $btnCopySend = New-Object System.Windows.Forms.Button
  $btnCopySend.Text = '複製 LINE 群發文'
  $btnCopySend.Location = New-Object System.Drawing.Point(0, 150)
  $btnCopySend.Size = New-Object System.Drawing.Size(350, 34)
  $btnCopySend.BackColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
  $btnCopySend.ForeColor = [System.Drawing.Color]::White
  $btnCopySend.FlatStyle = 'Flat'
  $right.Controls.Add($btnCopySend)

  $btnCopyRet = New-Object System.Windows.Forms.Button
  $btnCopyRet.Text = '複製回傳說明'
  $btnCopyRet.Location = New-Object System.Drawing.Point(0, 192)
  $btnCopyRet.Size = New-Object System.Drawing.Size(170, 30)
  $right.Controls.Add($btnCopyRet)

  $btnMarkSent = New-Object System.Windows.Forms.Button
  $btnMarkSent.Text = '未發→已發'
  $btnMarkSent.Location = New-Object System.Drawing.Point(180, 192)
  $btnMarkSent.Size = New-Object System.Drawing.Size(170, 30)
  $right.Controls.Add($btnMarkSent)

  $btnMarkPending = New-Object System.Windows.Forms.Button
  $btnMarkPending.Text = '已發→待回'
  $btnMarkPending.Location = New-Object System.Drawing.Point(0, 230)
  $btnMarkPending.Size = New-Object System.Drawing.Size(170, 30)
  $right.Controls.Add($btnMarkPending)

  $btnExport = New-Object System.Windows.Forms.Button
  $btnExport.Text = '匯出班級資料'
  $btnExport.Location = New-Object System.Drawing.Point(180, 230)
  $btnExport.Size = New-Object System.Drawing.Size(170, 30)
  $right.Controls.Add($btnExport)

  $btnImport = New-Object System.Windows.Forms.Button
  $btnImport.Text = '匯入班級資料'
  $btnImport.Location = New-Object System.Drawing.Point(0, 268)
  $btnImport.Size = New-Object System.Drawing.Size(170, 30)
  $right.Controls.Add($btnImport)

  $btnPhone = New-Object System.Windows.Forms.Button
  $btnPhone.Text = '開啟手機版'
  $btnPhone.Location = New-Object System.Drawing.Point(180, 268)
  $btnPhone.Size = New-Object System.Drawing.Size(170, 30)
  $right.Controls.Add($btnPhone)

  $btnFolder = New-Object System.Windows.Forms.Button
  $btnFolder.Text = '開啟工作夾'
  $btnFolder.Location = New-Object System.Drawing.Point(0, 306)
  $btnFolder.Size = New-Object System.Drawing.Size(170, 28)
  $right.Controls.Add($btnFolder)

  $btnScanFolder = New-Object System.Windows.Forms.Button
  $btnScanFolder.Text = '掃描匯入夾'
  $btnScanFolder.Location = New-Object System.Drawing.Point(180, 306)
  $btnScanFolder.Size = New-Object System.Drawing.Size(170, 28)
  $right.Controls.Add($btnScanFolder)

  $btnProcessScan = New-Object System.Windows.Forms.Button
  $btnProcessScan.Text = '處理掃描匯入'
  $btnProcessScan.Location = New-Object System.Drawing.Point(0, 340)
  $btnProcessScan.Size = New-Object System.Drawing.Size(350, 30)
  $btnProcessScan.BackColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
  $btnProcessScan.ForeColor = [System.Drawing.Color]::White
  $btnProcessScan.FlatStyle = 'Flat'
  $right.Controls.Add($btnProcessScan)

  $txtPreview = New-Object System.Windows.Forms.TextBox
  $txtPreview.Multiline = $true; $txtPreview.ScrollBars = 'Vertical'; $txtPreview.ReadOnly = $true
  $txtPreview.Location = New-Object System.Drawing.Point(16, 504)
  $txtPreview.Size = New-Object System.Drawing.Size(934, 120)
  $txtPreview.Anchor = 'Left,Right,Bottom'
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
    $script:State = Ensure-State $script:State
    Save-StateFile $script:State $script:StatePath
  }

  function Update-Summary {
    $c = @{ '跟上' = 0; '略落後' = 0; '明顯落後' = 0; '需補先備' = 0; '未發' = 0; '待回' = 0 }
    foreach ($k in $script:State.seats.Keys) {
      $s = $script:State.seats[$k]
      if ($c.ContainsKey([string]$s.level)) { $c[[string]$s.level]++ }
      if ($s.send -eq '未發') { $c['未發']++ }
      if ($s.send -in @('待回', '已發')) { $c['待回']++ }
    }
    $lblSummary.Text = ("跟上{0} 略落後{1} 明顯{2} 先備{3}｜未發{4} 待回{5}　發={6}／回={7}" -f `
      $c['跟上'], $c['略落後'], $c['明顯落後'], $c['需補先備'], $c['未發'], $c['待回'], `
      $SendChMap[$script:State.sendChannel], $RetChMap[$script:State.returnChannel])
  }

  function Refresh-Filters {
    foreach ($k in $script:FilterButtons.Keys) {
      $b = $script:FilterButtons[$k]
      if ($k -eq $script:Filter) {
        $b.BackColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
        $b.ForeColor = [System.Drawing.Color]::White
      } else {
        $b.BackColor = [System.Drawing.Color]::White
        $b.ForeColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
      }
    }
  }

  function Refresh-Grid {
    $gridHost.SuspendLayout()
    $gridHost.Controls.Clear()
    foreach ($k in ($script:State.seats.Keys | Sort-Object)) {
      $s = $script:State.seats[$k]
      $b = New-Object System.Windows.Forms.Button
      $b.Size = New-Object System.Drawing.Size(68, 48)
      $b.Margin = New-Object System.Windows.Forms.Padding(3)
      $b.FlatStyle = 'Flat'
      $b.Text = if ($k -eq '00') { "00試發`n$($s.send)" } else { ($k + "`n" + $s.send) }
      $b.BackColor = Get-LevelColor ([string]$s.level)
      $b.Tag = $k
      if (-not (Test-SeatFilter $s)) { $b.Enabled = $false }
      $b.Add_Click({
        param($sender, $e)
        $id = [string]$sender.Tag
        $script:SelectedId = $id
        $seat = $script:State.seats[$id]
        $lblSid.Text = "座號：$id"
        $cmbLevel.SelectedItem = [string]$seat.level
        $cmbSend.SelectedItem = [string]$seat.send
        $txtNote.Text = [string]$seat.note
      })
      [void]$gridHost.Controls.Add($b)
    }
    $gridHost.ResumeLayout()
    Update-Summary
    $txtPreview.Text = Build-SendMessage
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

  foreach ($f in @('all', '未發', '待回', '關注', '先備')) {
    $caption = switch ($f) {
      'all' { '全部' }
      '關注' { '需關注' }
      '先備' { '需補先備' }
      default { $f }
    }
    $fb = New-Object System.Windows.Forms.Button
    $fb.Text = $caption; $fb.Tag = $f; $fb.Width = 78; $fb.Height = 28; $fb.FlatStyle = 'Flat'
    $fb.Add_Click({
      param($sender, $e)
      $script:Filter = [string]$sender.Tag
      Refresh-Filters
      Refresh-Grid
    })
    [void]$filterPanel.Controls.Add($fb)
    $script:FilterButtons[$f] = $fb
  }

  $btnApply.Add_Click({ Persist-Header; Refresh-Grid })
  $btnSaveSeat.Add_Click({
    if (-not $script:SelectedId) {
      [void][System.Windows.Forms.MessageBox]::Show('請先點左側座號。', '習作台'); return
    }
    Persist-Header
    $id = $script:SelectedId
    $script:State.seats[$id].level = [string]$cmbLevel.SelectedItem
    $script:State.seats[$id].send = [string]$cmbSend.SelectedItem
    $script:State.seats[$id].note = $txtNote.Text.Trim()
    Save-StateFile $script:State $script:StatePath
    Refresh-Grid
  })
  $btnCopySend.Add_Click({
    Persist-Header
    $msg = Build-SendMessage
    [System.Windows.Forms.Clipboard]::SetText($msg)
    $txtPreview.Text = $msg
    [void][System.Windows.Forms.MessageBox]::Show('已複製，請貼到 LINE 班級群。', '習作台')
  })
  $btnCopyRet.Add_Click({
    Persist-Header
    $msg = Build-ReturnMessage
    [System.Windows.Forms.Clipboard]::SetText($msg)
    $txtPreview.Text = $msg
  })
  $btnMarkSent.Add_Click({
    Persist-Header
    foreach ($k in @($script:State.seats.Keys)) {
      if ($script:State.seats[$k].send -eq '未發') { $script:State.seats[$k].send = '已發' }
    }
    Save-StateFile $script:State $script:StatePath; Refresh-Grid
  })
  $btnMarkPending.Add_Click({
    Persist-Header
    foreach ($k in @($script:State.seats.Keys)) {
      if ($script:State.seats[$k].send -eq '已發') { $script:State.seats[$k].send = '待回' }
    }
    Save-StateFile $script:State $script:StatePath; Refresh-Grid
  })
  $btnExport.Add_Click({
    Persist-Header
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Title = '匯出班級資料'
    $dlg.Filter = '班級資料檔 (*.json)|*.json|所有檔案 (*.*)|*.*'
    $dlg.FileName = '班級狀態.json'
    $dlg.InitialDirectory = (Join-Path $WorkDir '匯出給手機')
    if ($dlg.ShowDialog() -eq 'OK') {
      Copy-Item -LiteralPath $script:StatePath -Destination $dlg.FileName -Force
      [void][System.Windows.Forms.MessageBox]::Show("已匯出：`n$($dlg.FileName)", '習作台')
    }
  })
  $btnImport.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = '匯入班級資料'
    $dlg.Filter = '班級資料檔 (*.json)|*.json|所有檔案 (*.*)|*.*'
    $dlg.InitialDirectory = $WorkDir
    if ($dlg.ShowDialog() -eq 'OK') {
      try {
        $obj = Get-Content -LiteralPath $dlg.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
        $st = @{
          classLabel = [string]$obj.classLabel; seatCount = [int]$obj.seatCount
          deadline = [string]$obj.deadline; sendChannel = [string]$obj.sendChannel
          returnChannel = [string]$obj.returnChannel; seats = $obj.seats
        }
        $script:State = Ensure-State $st
        $script:StatePath = Join-Path $WorkDir '班級狀態.json'
        Save-StateFile $script:State $script:StatePath
        Sync-FormFromState
        $script:SelectedId = $null
        $lblSid.Text = '座號：—'
        Refresh-Grid
        [void][System.Windows.Forms.MessageBox]::Show('已匯入並覆蓋。', '習作台')
      } catch {
        [void][System.Windows.Forms.MessageBox]::Show('匯入失敗，請確認是習作台匯出的班級資料。', '習作台')
      }
    }
  })
  $btnPhone.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText($PhoneUrl)
    Start-Process $PhoneUrl
  })
  $btnFolder.Add_Click({ Start-Process explorer.exe $WorkDir })
  $btnScanFolder.Add_Click({
    $scan = Join-Path $WorkDir '掃描匯入'
    New-Item -ItemType Directory -Force -Path $scan | Out-Null
    Start-Process explorer.exe $scan
  })
  $btnProcessScan.Add_Click({
    Persist-Header
    $scanDir = Join-Path $WorkDir '掃描匯入'
    $outDir = Join-Path $WorkDir '練習回傳'
    New-Item -ItemType Directory -Force -Path $scanDir, $outDir | Out-Null
    $files = @(Get-ChildItem -LiteralPath $scanDir -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -match '\.(pdf|png|jpe?g|gif|webp|heic|heif)$' })
    if ($files.Count -eq 0) {
      [void][System.Windows.Forms.MessageBox]::Show("掃描匯入夾沒有 PDF／圖片檔。`r`n請把手機下載的 05-R01.pdf 放到：`r`n$scanDir", '習作台')
      return
    }
    $done = 0
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($f in $files) {
      $g = Get-SeatRoundFromName $f.Name
      $sid = $g.SeatId
      if (-not $sid -or -not $script:State.seats.ContainsKey($sid)) {
        $lines.Add(("略過 {0}（無法對應座號）" -f $f.Name))
        continue
      }
      $round = [int]$g.Round
      if ($round -lt 1) { $round = 1 }
      $outName = Get-SuggestedScanName $sid $round $f.Name
      $dest = Join-Path $outDir $outName
      Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
      $script:State.seats[$sid].send = '待回'
      if (-not $script:State.seats[$sid].note) {
        $script:State.seats[$sid].note = ('掃描回傳 R{0:D2}' -f $round)
      }
      $done++
      $lines.Add(("$($f.Name) → $outName（座號 $sid 標待回）"))
    }
    Save-StateFile $script:State $script:StatePath
    Refresh-Grid
    $msg = "已處理 $done 個檔，輸出到：`r`n$outDir`r`n`r`n" + ($lines -join "`r`n")
    [void][System.Windows.Forms.MessageBox]::Show($msg, '習作台｜掃描匯入')
  })
  $form.Add_FormClosing({
    try {
      Persist-Header
      if ($script:SelectedId) {
        $script:State.seats[$script:SelectedId].level = [string]$cmbLevel.SelectedItem
        $script:State.seats[$script:SelectedId].send = [string]$cmbSend.SelectedItem
        $script:State.seats[$script:SelectedId].note = $txtNote.Text.Trim()
        Save-StateFile $script:State $script:StatePath
      }
    } catch {}
  })

  Refresh-Filters
  Refresh-Grid
  if (Test-Path -LiteralPath $logPath) {
    Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
  }
  [void]$form.ShowDialog()
}
catch {
  $msg = "習作台啟動失敗（已寫入桌面「習作台錯誤.txt」）`r`n`r`n$($_.Exception.Message)`r`n`r`n$($_.ScriptStackTrace)"
  Show-Fail $msg
  exit 1
}
