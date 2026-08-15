#Requires -Version 5.1
<#
.SYNOPSIS
  數學習作批改視窗：每人一檔輸入 → 批改後輸出每人註記檔。

.DESCRIPTION
  資料夾結構：
    工作資料夾\
      標準答案\   （放答案 PDF／圖）
      輸入\       （每位學生一個 PDF 或圖檔，檔名建議座號）
      輸出\       （自動產生：座號-註記.md、全班總表.csv）

  原則：接受等價合理解法；標「正確／錯誤／存疑」；存疑留給人工終核。
#>
param(
  [string]$WorkDir = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Get-DefaultWorkDir {
  $desk = [Environment]::GetFolderPath('Desktop')
  return (Join-Path $desk 'MathGrading')
}

function Ensure-WorkTree([string]$root) {
  foreach ($n in @('標準答案', '輸入', '輸出')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $n) | Out-Null
  }
  $readme = Join-Path $root '說明.txt'
  if (-not (Test-Path -LiteralPath $readme)) {
    @(
      '數學習作批改資料夾'
      ''
      '1. 把標準答案放到「標準答案」'
      '2. 每位學生一個檔放到「輸入」（PDF 或 JPG/PNG），檔名用座號，例如 05.pdf'
      '3. 開啟本程式批改；每人結果寫入「輸出\座號-註記.md」'
      '4. 可再匯出「輸出\全班總表.csv」'
    ) | Set-Content -LiteralPath $readme -Encoding UTF8
  }
}

function Get-StudentId([string]$fileName) {
  $base = [IO.Path]::GetFileNameWithoutExtension($fileName)
  if ($base -match '^(\d{1,3})') { return $Matches[1].PadLeft(2, '0') }
  return $base
}

function Get-InputFiles([string]$root) {
  $dir = Join-Path $root '輸入'
  if (-not (Test-Path -LiteralPath $dir)) { return @() }
  Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '\.(pdf|png|jpe?g|tif{1,2}|bmp)$' } |
    Sort-Object Name
}

function Get-NotePath([string]$root, [string]$studentId) {
  return (Join-Path (Join-Path $root '輸出') ($studentId + '-註記.md'))
}

function Load-Note([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) {
    return [pscustomobject]@{
      studentId = ''
      sourceFile = ''
      overall = '未批'
      summary = ''
      advice = ''
      practice = ''
      items = @()
    }
  }
  $raw = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
  # simple fields
  $o = [pscustomobject]@{
    studentId = ''
    sourceFile = ''
    overall = '未批'
    summary = ''
    advice = ''
    practice = ''
    itemsText = ''
  }
  if ($raw -match '(?m)^- 座號[：:]\s*(.+)$') { $o.studentId = $Matches[1].Trim() }
  if ($raw -match '(?m)^- 來源檔[：:]\s*(.+)$') { $o.sourceFile = $Matches[1].Trim() }
  if ($raw -match '(?m)^- 總評[：:]\s*(.+)$') { $o.overall = $Matches[1].Trim() }
  if ($raw -match '(?s)## 對錯摘要\s*(.*?)(?=##|$)') { $o.summary = $Matches[1].Trim() }
  if ($raw -match '(?s)## 個別建議\s*(.*?)(?=##|$)') { $o.advice = $Matches[1].Trim() }
  if ($raw -match '(?s)## 需再練習\s*(.*?)(?=##|$)') { $o.practice = $Matches[1].Trim() }
  if ($raw -match '(?s)## 題號註記\s*(.*?)(?=##|$)') { $o.itemsText = $Matches[1].Trim() }
  return $o
}

function Save-Note {
  param(
    [string]$Root,
    [string]$StudentId,
    [string]$SourceFile,
    [string]$Overall,
    [string]$ItemsText,
    [string]$Summary,
    [string]$Advice,
    [string]$Practice
  )
  $path = Get-NotePath $Root $StudentId
  $lines = @(
    "# 批閱註記｜座號 $StudentId"
    ''
    '- 座號：' + $StudentId
    '- 來源檔：' + $SourceFile
    '- 總評：' + $Overall
    '- 批改時間：' + (Get-Date -Format 'yyyy-MM-dd HH:mm')
    '- 原則：接受其他合理等價解法；存疑項請人工終核'
    ''
    '## 題號註記'
    $(if ($ItemsText) { $ItemsText } else { '（尚未填題號；格式例：1 ✓｜2 ✗ 計算錯｜3 ? 潦草）' })
    ''
    '## 對錯摘要'
    $(if ($Summary) { $Summary } else { '（初核摘要）' })
    ''
    '## 個別建議'
    $(if ($Advice) { $Advice } else { '（針對該生）' })
    ''
    '## 需再練習'
    $(if ($Practice) { $Practice } else { '（可後補練習題與解答）' })
    ''
  )
  $utf8Bom = New-Object System.Text.UTF8Encoding $true
  [IO.File]::WriteAllText($path, ($lines -join "`r`n"), $utf8Bom)
  return $path
}

function Export-ClassCsv([string]$root) {
  $outDir = Join-Path $root '輸出'
  $csv = Join-Path $outDir '全班總表.csv'
  $rows = @()
  $rows += '座號,來源檔,總評,註記檔,批改時間'
  Get-ChildItem -LiteralPath $outDir -Filter '*-註記.md' -File -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object {
      $n = Load-Note $_.FullName
      $id = Get-StudentId $_.Name.Replace('-註記', '')
      if (-not $n.studentId) { $n.studentId = $id }
      $rows += ('{0},{1},{2},{3},{4}' -f $n.studentId, ($n.sourceFile -replace ',', '，'), ($n.overall -replace ',', '，'), $_.Name, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    }
  $utf8Bom = New-Object System.Text.UTF8Encoding $true
  [IO.File]::WriteAllText($csv, ($rows -join "`r`n"), $utf8Bom)
  return $csv
}

function Build-CursorPrompt([string]$root) {
  $inputs = @(Get-InputFiles $root)
  $ansDir = Join-Path $root '標準答案'
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('請初核下列數學習作（加速人工打勾；非最終成績）。')
  [void]$sb.AppendLine('規則：有標準答案時以答案為準；接受其他合理等價解法；潦草／不確定標「存疑」。')
  [void]$sb.AppendLine('每位學生輸出一份註記，寫入對應「輸出\座號-註記.md」格式：題號註記、對錯摘要、個別建議、需再練習（可附練習題＋解答）。')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('工作資料夾：' + $root)
  [void]$sb.AppendLine('標準答案資料夾：' + $ansDir)
  [void]$sb.AppendLine('輸入檔：')
  foreach ($f in $inputs) {
    [void]$sb.AppendLine(' - ' + $f.FullName)
  }
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('請依檔名座號逐人批閱；正確題標 ✓ 供我快速打勾，存疑標 ?。')
  return $sb.ToString()
}

# ----- UI -----
if ([string]::IsNullOrWhiteSpace($WorkDir)) { $WorkDir = Get-DefaultWorkDir }
Ensure-WorkTree $WorkDir
$script:WorkDir = $WorkDir

$font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 12)
$fontBig = New-Object System.Drawing.Font('Microsoft JhengHei UI', 16, [System.Drawing.FontStyle]::Bold)

$form = New-Object System.Windows.Forms.Form
$form.Text = '數學習作批改（一人一檔 → 一人一註記）'
$form.Size = New-Object System.Drawing.Size(980, 680)
$form.StartPosition = 'CenterScreen'
$form.Font = $font
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 248, 244)

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = '每人一個輸入檔；批完輸出到「輸出」資料夾'
$lbl.Font = $fontBig
$lbl.ForeColor = [System.Drawing.Color]::FromArgb(20, 70, 50)
$lbl.Location = New-Object System.Drawing.Point(16, 12)
$lbl.Size = New-Object System.Drawing.Size(700, 32)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Location = New-Object System.Drawing.Point(16, 48)
$lblPath.Size = New-Object System.Drawing.Size(920, 24)

$list = New-Object System.Windows.Forms.ListBox
$list.Location = New-Object System.Drawing.Point(16, 84)
$list.Size = New-Object System.Drawing.Size(300, 420)
$list.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 13)

$grp = New-Object System.Windows.Forms.GroupBox
$grp.Text = '目前學生註記'
$grp.Location = New-Object System.Drawing.Point(336, 84)
$grp.Size = New-Object System.Drawing.Size(610, 420)

function Add-L([int]$y, [string]$t) {
  $l = New-Object System.Windows.Forms.Label
  $l.Text = $t
  $l.Location = New-Object System.Drawing.Point(16, $y)
  $l.Size = New-Object System.Drawing.Size(100, 28)
  $grp.Controls.Add($l)
}

Add-L 28 '總評'
$cmbOverall = New-Object System.Windows.Forms.ComboBox
$cmbOverall.DropDownStyle = 'DropDownList'
$cmbOverall.Items.AddRange(@('未批', '大致正確', '部分錯誤', '需補救', '存疑多'))
$cmbOverall.SelectedIndex = 0
$cmbOverall.Location = New-Object System.Drawing.Point(120, 28)
$cmbOverall.Size = New-Object System.Drawing.Size(200, 28)
$grp.Controls.Add($cmbOverall)

Add-L 68 '題號註記'
$txtItems = New-Object System.Windows.Forms.TextBox
$txtItems.Multiline = $true
$txtItems.ScrollBars = 'Vertical'
$txtItems.Location = New-Object System.Drawing.Point(120, 68)
$txtItems.Size = New-Object System.Drawing.Size(470, 90)
$txtItems.Text = "1 ✓`r`n2 ✗`r`n3 ?"
$grp.Controls.Add($txtItems)

Add-L 168 '對錯摘要'
$txtSummary = New-Object System.Windows.Forms.TextBox
$txtSummary.Multiline = $true
$txtSummary.ScrollBars = 'Vertical'
$txtSummary.Location = New-Object System.Drawing.Point(120, 168)
$txtSummary.Size = New-Object System.Drawing.Size(470, 60)
$grp.Controls.Add($txtSummary)

Add-L 240 '個別建議'
$txtAdvice = New-Object System.Windows.Forms.TextBox
$txtAdvice.Multiline = $true
$txtAdvice.ScrollBars = 'Vertical'
$txtAdvice.Location = New-Object System.Drawing.Point(120, 240)
$txtAdvice.Size = New-Object System.Drawing.Size(470, 60)
$grp.Controls.Add($txtAdvice)

Add-L 312 '再練習'
$txtPractice = New-Object System.Windows.Forms.TextBox
$txtPractice.Multiline = $true
$txtPractice.ScrollBars = 'Vertical'
$txtPractice.Location = New-Object System.Drawing.Point(120, 312)
$txtPractice.Size = New-Object System.Drawing.Size(470, 80)
$grp.Controls.Add($txtPractice)

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(16, 600)
$status.Size = New-Object System.Drawing.Size(930, 28)
$status.Text = '先選工作資料夾，把全班 PDF／圖檔放入「輸入」'

$script:files = @()
$script:current = $null

function Refresh-PathLabel {
  $lblPath.Text = '工作資料夾：' + $script:WorkDir
}

function Refresh-List {
  $list.Items.Clear()
  $script:files = @(Get-InputFiles $script:WorkDir)
  foreach ($f in $script:files) {
    $id = Get-StudentId $f.Name
    $note = Get-NotePath $script:WorkDir $id
    $mark = if (Test-Path -LiteralPath $note) { '〔已有註記〕' } else { '〔未批〕' }
    [void]$list.Items.Add("$id  $($f.Name)  $mark")
  }
  $status.Text = ('輸入 {0} 人｜工作夾 {1}' -f $script:files.Count, $script:WorkDir)
}

function Load-Selected {
  if ($list.SelectedIndex -lt 0) { return }
  $f = $script:files[$list.SelectedIndex]
  $script:current = $f
  $id = Get-StudentId $f.Name
  $n = Load-Note (Get-NotePath $script:WorkDir $id)
  $idx = [Math]::Max(0, $cmbOverall.Items.IndexOf([string]$n.overall))
  if ($n.overall -and $cmbOverall.Items.Contains($n.overall)) {
    $cmbOverall.SelectedItem = $n.overall
  } else { $cmbOverall.SelectedIndex = 0 }
  $txtItems.Text = $(if ($n.itemsText) { $n.itemsText } else { "1 ✓`r`n2 ✗`r`n3 ?" })
  $txtSummary.Text = [string]$n.summary
  $txtAdvice.Text = [string]$n.advice
  $txtPractice.Text = [string]$n.practice
  $status.Text = '目前：座號 ' + $id + '｜' + $f.Name
}

$list.Add_SelectedIndexChanged({ Load-Selected })

function Save-Current {
  if (-not $script:current) {
    [void][System.Windows.Forms.MessageBox]::Show('請先選左側一位學生', '提示')
    return $null
  }
  $id = Get-StudentId $script:current.Name
  $path = Save-Note -Root $script:WorkDir -StudentId $id -SourceFile $script:current.Name `
    -Overall ([string]$cmbOverall.SelectedItem) -ItemsText $txtItems.Text `
    -Summary $txtSummary.Text -Advice $txtAdvice.Text -Practice $txtPractice.Text
  Refresh-List
  # reselect
  for ($i = 0; $i -lt $list.Items.Count; $i++) {
    if ($list.Items[$i].ToString().StartsWith($id + ' ')) { $list.SelectedIndex = $i; break }
  }
  $status.Text = '已輸出：' + $path
  return $path
}

$btnWork = New-Object System.Windows.Forms.Button
$btnWork.Text = '選工作資料夾'
$btnWork.Location = New-Object System.Drawing.Point(16, 520)
$btnWork.Size = New-Object System.Drawing.Size(140, 40)
$btnWork.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.SelectedPath = $script:WorkDir
    if ($d.ShowDialog() -eq 'OK') {
      $script:WorkDir = $d.SelectedPath
      Ensure-WorkTree $script:WorkDir
      Refresh-PathLabel
      Refresh-List
    }
  })

$btnOpenIn = New-Object System.Windows.Forms.Button
$btnOpenIn.Text = '開啟輸入夾'
$btnOpenIn.Location = New-Object System.Drawing.Point(168, 520)
$btnOpenIn.Size = New-Object System.Drawing.Size(120, 40)
$btnOpenIn.Add_Click({ Start-Process explorer.exe (Join-Path $script:WorkDir '輸入') })

$btnOpenOut = New-Object System.Windows.Forms.Button
$btnOpenOut.Text = '開啟輸出夾'
$btnOpenOut.Location = New-Object System.Drawing.Point(300, 520)
$btnOpenOut.Size = New-Object System.Drawing.Size(120, 40)
$btnOpenOut.Add_Click({ Start-Process explorer.exe (Join-Path $script:WorkDir '輸出') })

$btnOpenFile = New-Object System.Windows.Forms.Button
$btnOpenFile.Text = '開啟此生檔案'
$btnOpenFile.Location = New-Object System.Drawing.Point(432, 520)
$btnOpenFile.Size = New-Object System.Drawing.Size(140, 40)
$btnOpenFile.Add_Click({
    if ($script:current) { Start-Process -FilePath $script:current.FullName }
    else { [void][System.Windows.Forms.MessageBox]::Show('請先選學生', '提示') }
  })

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = '輸出此生註記'
$btnSave.Location = New-Object System.Drawing.Point(584, 520)
$btnSave.Size = New-Object System.Drawing.Size(140, 40)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 70)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = 'Flat'
$btnSave.Add_Click({ [void](Save-Current) })

$btnCsv = New-Object System.Windows.Forms.Button
$btnCsv.Text = '匯出全班總表'
$btnCsv.Location = New-Object System.Drawing.Point(736, 520)
$btnCsv.Size = New-Object System.Drawing.Size(130, 40)
$btnCsv.Add_Click({
    $csv = Export-ClassCsv $script:WorkDir
    $status.Text = '已匯出：' + $csv
    [void][System.Windows.Forms.MessageBox]::Show("已匯出：`n$csv", '全班總表')
  })

$btnPrompt = New-Object System.Windows.Forms.Button
$btnPrompt.Text = '複製給 Cursor 初核提示'
$btnPrompt.Location = New-Object System.Drawing.Point(16, 568)
$btnPrompt.Size = New-Object System.Drawing.Size(220, 28)
$btnPrompt.Add_Click({
    $p = Build-CursorPrompt $script:WorkDir
    [System.Windows.Forms.Clipboard]::SetText($p)
    $status.Text = '已複製初核提示，到 Cursor 貼上並附上標準答案／掃描檔'
    [void][System.Windows.Forms.MessageBox]::Show('已複製到剪貼簿。到 Cursor 貼上，並上傳標準答案與學生檔（或說明路徑）。', 'Cursor 初核')
  })

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = '重新整理名單'
$btnRefresh.Location = New-Object System.Drawing.Point(250, 568)
$btnRefresh.Size = New-Object System.Drawing.Size(140, 28)
$btnRefresh.Add_Click({ Refresh-List })

$form.Controls.AddRange(@(
    $lbl, $lblPath, $list, $grp, $status,
    $btnWork, $btnOpenIn, $btnOpenOut, $btnOpenFile, $btnSave, $btnCsv, $btnPrompt, $btnRefresh
  ))

Refresh-PathLabel
Refresh-List

[void]$form.ShowDialog()
