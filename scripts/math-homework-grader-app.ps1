#Requires -Version 5.1
<#
.SYNOPSIS
  數學習作批改視窗：每人一檔輸入 → 批改後輸出每人註記檔。

.DESCRIPTION
  資料夾結構：
    工作資料夾\
      標準答案\   （放答案 PDF／圖）
      輸入\       （每位學生一個試卷 PDF／圖檔）
      輸出\       （座號-註記.md、座號-批閱註記.pdf、座號-試卷含批閱.pdf、全班存疑清單）
      認知輸入\   （老師看懂後：05-Q3.txt）
      重謄補充\   （看不懂處重謄掃描：05-Q3.pdf）

  流程：全班各自批閱 → 輸出 PDF 註記 → 彙整存疑 → 老師補認知／重謄 → 再產 PDF。
  原則：接受等價合理解法；✓ 可快速打勾；? 存疑待人工。
#>
param(
  [string]$WorkDir = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:PyMakePdf = Join-Path $script:ScriptDir 'math_grade_make_note_pdf.py'
# also check beside installed copy
if (-not (Test-Path -LiteralPath $script:PyMakePdf)) {
  $alt = Join-Path (Split-Path -Parent $script:ScriptDir) 'scripts\math_grade_make_note_pdf.py'
  if (Test-Path -LiteralPath $alt) { $script:PyMakePdf = $alt }
}

function Get-DefaultWorkDir {
  $desk = [Environment]::GetFolderPath('Desktop')
  return (Join-Path $desk 'MathGrading')
}

function Ensure-WorkTree([string]$root) {
  foreach ($n in @('標準答案', '輸入', '輸出', '認知輸入', '重謄補充')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $n) | Out-Null
  }
  $readme = Join-Path $root '說明.txt'
  @(
    '全班試卷批改（一人一檔 → 個人 PDF 註記）'
    ''
    '1. 標準答案 →「標準答案」'
    '2. 每位學生試卷一個檔 →「輸入」（如 05.pdf）'
    '3. 批改後「輸出」會有：05-註記.md、05-批閱註記.pdf、05-試卷含批閱.pdf'
    '4. 看不懂的標 ?；全班批完後開「全班存疑清單」'
    '5. 老師辨認後寫入「認知輸入\05-Q3.txt」，或重謄掃描放「重謄補充\05-Q3.pdf」'
    '6. 按「套用認知／重謄並重產PDF」'
  ) | Set-Content -LiteralPath $readme -Encoding UTF8
}

function Find-Python {
  foreach ($c in @('python', 'python3', 'py')) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }
  return $null
}

function Invoke-MakePdf {
  param(
    [string]$Root,
    [string]$Student = '',
    [switch]$UnclearList,
    [switch]$ApplyClarifications,
    [switch]$MergeOriginal
  )
  $py = Find-Python
  if (-not $py) {
    [void][System.Windows.Forms.MessageBox]::Show('找不到 python。請先安裝 Python，並 pip install pypdf reportlab', 'PDF')
    return $false
  }
  if (-not (Test-Path -LiteralPath $script:PyMakePdf)) {
    # fallback: copy next to work app if shipped together
    $localPy = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'math_grade_make_note_pdf.py'
    if (Test-Path -LiteralPath $localPy) { $script:PyMakePdf = $localPy }
  }
  if (-not (Test-Path -LiteralPath $script:PyMakePdf)) {
    [void][System.Windows.Forms.MessageBox]::Show("找不到 math_grade_make_note_pdf.py`n請放到與批改程式相同資料夾", 'PDF')
    return $false
  }
  $argList = @($script:PyMakePdf, '--work-dir', $Root, '--merge-original')
  if ($Student) { $argList += @('--student', $Student) }
  if ($UnclearList) { $argList += '--unclear-list' }
  if ($ApplyClarifications) { $argList += '--apply-clarifications' }
  if (-not $MergeOriginal) {
    # still pass merge for deliverable combined PDF
    $null = $MergeOriginal
  }
  $p = Start-Process -FilePath $py -ArgumentList $argList -Wait -PassThru -NoNewWindow
  return ($p.ExitCode -eq 0)
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
$lbl.Text = '一人一檔、一檔一檔批：選人 → 開啟 → 註記 → 輸出PDF → 下一位'
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
  # 同時產此生 PDF 註記（一人一檔）
  [void](Invoke-MakePdf -Root $script:WorkDir -Student $id -MergeOriginal)
  Refresh-List
  for ($i = 0; $i -lt $list.Items.Count; $i++) {
    if ($list.Items[$i].ToString().StartsWith($id + ' ')) { $list.SelectedIndex = $i; break }
  }
  $pdf1 = Join-Path (Join-Path $script:WorkDir '輸出') ($id + '-批閱註記.pdf')
  $pdf2 = Join-Path (Join-Path $script:WorkDir '輸出') ($id + '-試卷含批閱.pdf')
  $status.Text = "已輸出：$path ｜ PDF：$pdf1"
  return $path
}

function Select-NextUngraded {
  Refresh-List
  for ($i = 0; $i -lt $script:files.Count; $i++) {
    $id = Get-StudentId $script:files[$i].Name
    $note = Get-NotePath $script:WorkDir $id
    if (-not (Test-Path -LiteralPath $note)) {
      $list.SelectedIndex = $i
      Load-Selected
      if ($script:current) { Start-Process -FilePath $script:current.FullName }
      $status.Text = "下一位未批：座號 $id"
      return
    }
  }
  [void][System.Windows.Forms.MessageBox]::Show("全員都有註記了。`n可按「產生全班存疑清單」處理看不懂的地方。", '完成')
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
$btnSave.Text = '輸出此生PDF'
$btnSave.Location = New-Object System.Drawing.Point(584, 520)
$btnSave.Size = New-Object System.Drawing.Size(140, 40)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 70)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = 'Flat'
$btnSave.Add_Click({ [void](Save-Current) })

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = '下一位未批'
$btnNext.Location = New-Object System.Drawing.Point(736, 520)
$btnNext.Size = New-Object System.Drawing.Size(130, 40)
$btnNext.Add_Click({ Select-NextUngraded })

$btnCsv = New-Object System.Windows.Forms.Button
$btnCsv.Text = '全班總表'
$btnCsv.Location = New-Object System.Drawing.Point(16, 568)
$btnCsv.Size = New-Object System.Drawing.Size(100, 28)
$btnCsv.Add_Click({
    $csv = Export-ClassCsv $script:WorkDir
    $status.Text = '已匯出：' + $csv
  })

$btnUnclear = New-Object System.Windows.Forms.Button
$btnUnclear.Text = '產生全班存疑清單'
$btnUnclear.Location = New-Object System.Drawing.Point(128, 568)
$btnUnclear.Size = New-Object System.Drawing.Size(160, 28)
$btnUnclear.Add_Click({
    if (Invoke-MakePdf -Root $script:WorkDir -UnclearList) {
      $p = Join-Path (Join-Path $script:WorkDir '輸出') '全班存疑清單.md'
      $status.Text = '存疑清單：' + $p
      if (Test-Path -LiteralPath $p) { Start-Process -FilePath $p }
    }
  })

$btnClarify = New-Object System.Windows.Forms.Button
$btnClarify.Text = '套用認知／重謄並重產PDF'
$btnClarify.Location = New-Object System.Drawing.Point(300, 568)
$btnClarify.Size = New-Object System.Drawing.Size(200, 28)
$btnClarify.Add_Click({
    if (Invoke-MakePdf -Root $script:WorkDir -ApplyClarifications -UnclearList -MergeOriginal) {
      $status.Text = '已套用認知／重謄並重產 PDF'
      [void][System.Windows.Forms.MessageBox]::Show("已讀取「認知輸入」「重謄補充」並重產輸出 PDF。", '完成')
    }
  })

$btnPrompt = New-Object System.Windows.Forms.Button
$btnPrompt.Text = '複製此生給Cursor'
$btnPrompt.Location = New-Object System.Drawing.Point(512, 568)
$btnPrompt.Size = New-Object System.Drawing.Size(150, 28)
$btnPrompt.Add_Click({
    if (-not $script:current) {
      [void][System.Windows.Forms.MessageBox]::Show('請先選一位學生（一檔一檔來）', '提示')
      return
    }
    $id = Get-StudentId $script:current.Name
    $ansDir = Join-Path $script:WorkDir '標準答案'
    $p = @"
請初核這一位學生的數學試卷（一人一檔）。
規則：以標準答案為準；接受合理等價解法；看不懂標 ? 存疑。
座號：$id
來源檔：$($script:current.FullName)
標準答案資料夾：$ansDir
請輸出可貼回批改程式的題號註記（✓／✗／?）、對錯摘要、個別建議、需再練習（可附題與解答）。
"@
    [System.Windows.Forms.Clipboard]::SetText($p)
    $status.Text = "已複製座號 $id 的初核提示"
  })

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = '重新整理'
$btnRefresh.Location = New-Object System.Drawing.Point(674, 568)
$btnRefresh.Size = New-Object System.Drawing.Size(100, 28)
$btnRefresh.Add_Click({ Refresh-List })

$btnOpenCog = New-Object System.Windows.Forms.Button
$btnOpenCog.Text = '認知／重謄夾'
$btnOpenCog.Location = New-Object System.Drawing.Point(786, 568)
$btnOpenCog.Size = New-Object System.Drawing.Size(110, 28)
$btnOpenCog.Add_Click({
    Start-Process explorer.exe (Join-Path $script:WorkDir '認知輸入')
  })

$form.Controls.AddRange(@(
    $lbl, $lblPath, $list, $grp, $status,
    $btnWork, $btnOpenIn, $btnOpenOut, $btnOpenFile, $btnSave, $btnNext,
    $btnCsv, $btnUnclear, $btnClarify, $btnPrompt, $btnRefresh, $btnOpenCog
  ))

Refresh-PathLabel
Refresh-List
if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }

[void]$form.ShowDialog()
