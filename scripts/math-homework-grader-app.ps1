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
    [switch]$MergeOriginal,
    [switch]$ClassReport
  )
  $py = Find-Python
  if (-not $py) {
    [void][System.Windows.Forms.MessageBox]::Show('找不到 python。請先安裝 Python，並 pip install pypdf reportlab', 'PDF')
    return $false
  }
  if (-not (Test-Path -LiteralPath $script:PyMakePdf)) {
    $localPy = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'math_grade_make_note_pdf.py'
    if (Test-Path -LiteralPath $localPy) { $script:PyMakePdf = $localPy }
  }
  if (-not (Test-Path -LiteralPath $script:PyMakePdf)) {
    [void][System.Windows.Forms.MessageBox]::Show("找不到 math_grade_make_note_pdf.py`n請放到與批改程式相同資料夾", 'PDF')
    return $false
  }
  $argList = @($script:PyMakePdf, '--work-dir', $Root)
  if ($MergeOriginal) { $argList += '--merge-original' }
  if ($Student) { $argList += @('--student', $Student) }
  if ($UnclearList) { $argList += '--unclear-list' }
  if ($ApplyClarifications) { $argList += '--apply-clarifications' }
  if ($ClassReport) { $argList += '--class-report' }
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
      level = '待判定'
      summary = ''
      diagnosis = ''
      advice = ''
      practice = ''
      itemsText = ''
    }
  }
  $raw = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
  $o = [pscustomobject]@{
    studentId = ''
    sourceFile = ''
    overall = '未批'
    level = '待判定'
    summary = ''
    diagnosis = ''
    advice = ''
    practice = ''
    itemsText = ''
  }
  if ($raw -match '(?m)^- 座號[：:]\s*(.+)$') { $o.studentId = $Matches[1].Trim() }
  if ($raw -match '(?m)^- 來源檔[：:]\s*(.+)$') { $o.sourceFile = $Matches[1].Trim() }
  if ($raw -match '(?m)^- 總評[：:]\s*(.+)$') { $o.overall = $Matches[1].Trim() }
  if ($raw -match '(?m)^- 程度[：:]\s*(.+)$') { $o.level = $Matches[1].Trim() }
  if ($raw -match '(?s)## 對錯摘要\s*(.*?)(?=##|$)') { $o.summary = $Matches[1].Trim() }
  if ($raw -match '(?s)## 個別診斷結果\s*(.*?)(?=##|$)') { $o.diagnosis = $Matches[1].Trim() }
  elseif ($raw -match '(?s)## 個別建議\s*(.*?)(?=##|$)') { $o.advice = $Matches[1].Trim() }
  if ($raw -match '(?s)## 個別建議\s*(.*?)(?=##|$)') { $o.advice = $Matches[1].Trim() }
  if ($raw -match '(?s)## 依程度自學／補救練習\s*(.*?)(?=##|$)') { $o.practice = $Matches[1].Trim() }
  elseif ($raw -match '(?s)## 需再練習\s*(.*?)(?=##|$)') { $o.practice = $Matches[1].Trim() }
  if ($raw -match '(?s)## 題號註記\s*(.*?)(?=##|$)') { $o.itemsText = $Matches[1].Trim() }
  return $o
}

function Get-PracticeTemplate([string]$level) {
  switch -Regex ($level) {
    '跟上' {
      return @"
### 程度：跟上｜目標：再提升（少重複、多挑戰）
說明：已掌握本單元。A 只練 1～2 題把步驟寫穩；重心放在 B、C，讓好的學生真的再進步。禁止整份都是原卷簡單題改數字。

#### 練習題（先做完再看解答）
【A 鞏固｜少而精】步驟寫完整即可（勿佔大半）
1. （本單元典型題，略改數字／條件）

【B 靈活｜換條件仍會】
2. （逆向思考／已知結果求條件）
3. （兩步驟以上綜合，或圖表＋算式）

【C 再提升｜必做挑戰】比原卷難一階
4. （生活情境應用／多條件取捨）
5. （一題多解，或需說明「為什麼這樣做」）
6. （易錯陷阱題：似對實錯，要驗算或反例）

【D 超前伸展｜選做】銜接下單元或更深一層
7. （延伸觀念一小步；做不出也沒關係，寫卡住的地方）

---
#### 解答（全部題目完成後再看）
1. …
2. …
3. …
4. …
5. …
6. …
7. …
提升小提示：挑戰題做完，用一句話寫「我多學到什麼」；選做題寫「還想學什麼」。
"@
    }
    '略落後' {
      return @"
### 程度：略落後｜目標：跟上本單元
先復習：________（本單元核心觀念）

#### 練習題（先做完再看解答）
【A 關鍵基本】
1. （基本題）
2. （基本題）
3. （基本題）

【B 對應錯題類型】
4. （原卷錯題變形）
5. （原卷錯題變形）

---
#### 解答（全部題目完成後再看）
1. …
2. …
3. …
4. …
5. …
"@
    }
    '明顯落後' {
      return @"
### 程度：明顯落後｜目標：先補洞再銜接（少而精）
先備缺口：________
本週只練 1～2 個點：________

#### 練習題（先做完再看解答）
【A 先備極短題】
1. …
2. …

【B 銜接本單元最簡題】
3. …

---
#### 解答（全部題目完成後再看｜逐步寫）
1. …
2. …
3. …
說明：先求做對建立信心；暫不强追全班進度與難題。
"@
    }
    '需補先備' {
      return @"
### 程度：需補先備｜目標：回到可學習的起點
建議先備單元：________

#### 練習題（先做完再看解答）
1. （先備題）
2. （先備題）
3. （先備題）

---
#### 解答（全部題目完成後再看）
1. …
2. …
3. …
建議：與導師／補救協調；避免只重複整份考卷難題。
"@
    }
    default {
      return @"
#### 練習題（先做完再看解答）
1. …
2. …

---
#### 解答（全部題目完成後再看）
1. …
2. …
"@
    }
  }
}

function Save-Note {
  param(
    [string]$Root,
    [string]$StudentId,
    [string]$SourceFile,
    [string]$Overall,
    [string]$Level,
    [string]$ItemsText,
    [string]$Summary,
    [string]$Diagnosis,
    [string]$Advice,
    [string]$Practice
  )
  $path = Get-NotePath $Root $StudentId
  if ([string]::IsNullOrWhiteSpace($Practice)) {
    $Practice = Get-PracticeTemplate $Level
  }
  $lines = @(
    "# 批閱註記｜座號 $StudentId"
    ''
    '- 座號：' + $StudentId
    '- 來源檔：' + $SourceFile
    '- 總評：' + $Overall
    '- 程度：' + $Level
    '- 批改時間：' + (Get-Date -Format 'yyyy-MM-dd HH:mm')
    '- 原則：接受其他合理等價解法；存疑項請人工終核'
    ''
    '## 題號註記'
    $(if ($ItemsText) { $ItemsText } else { '（尚未填題號；格式例：1 ✓｜2 ✗ 計算錯｜3 ? 潦草）' })
    ''
    '## 對錯摘要'
    $(if ($Summary) { $Summary } else { '（初核摘要）' })
    ''
    '## 個別診斷結果'
    $(if ($Diagnosis) { $Diagnosis } else { '（弱點類型：計算／觀念／審題／先備不足／粗心…；是否跟得上進度）' })
    ''
    '## 個別建議'
    $(if ($Advice) { $Advice } else { '（給學生／家長的短建議）' })
    ''
    '## 依程度自學／補救練習'
    $Practice
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
  $rows += '座號,來源檔,總評,程度,註記檔,批改時間'
  Get-ChildItem -LiteralPath $outDir -Filter '*-註記.md' -File -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object {
      $n = Load-Note $_.FullName
      $id = Get-StudentId $_.Name.Replace('-註記', '')
      if (-not $n.studentId) { $n.studentId = $id }
      $rows += ('{0},{1},{2},{3},{4},{5}' -f $n.studentId, ($n.sourceFile -replace ',', '，'), ($n.overall -replace ',', '，'), ($n.level -replace ',', '，'), $_.Name, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    }
  $utf8Bom = New-Object System.Text.UTF8Encoding $true
  [IO.File]::WriteAllText($csv, ($rows -join "`r`n"), $utf8Bom)
  return $csv
}

function Get-AnswerFiles([string]$root) {
  $dir = Join-Path $root '標準答案'
  if (-not (Test-Path -LiteralPath $dir)) { return @() }
  Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '\.(pdf|png|jpe?g|tif{1,2}|bmp|txt|md)$' } |
    Sort-Object Name
}

function Get-SettingsPath([string]$root) {
  Join-Path $root 'settings.json'
}

function Load-Settings([string]$root) {
  $p = Get-SettingsPath $root
  if (Test-Path -LiteralPath $p) {
    try { return (Get-Content -LiteralPath $p -Encoding UTF8 -Raw | ConvertFrom-Json) } catch {}
  }
  return [pscustomobject]@{ mode = 'manual'; answerHint = '' }
}

function Save-Settings([string]$root, $settings) {
  ($settings | ConvertTo-Json) | Set-Content -LiteralPath (Get-SettingsPath $root) -Encoding UTF8
}

function Build-CursorPrompt([string]$root) {
  $inputs = @(Get-InputFiles $root)
  $ansDir = Join-Path $root '標準答案'
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('請初核下列數學習作（加速人工打勾；非最終成績）。')
  [void]$sb.AppendLine('規則：有標準答案時以答案為準；接受其他合理等價解法；潦草／不確定標「存疑」。')
  [void]$sb.AppendLine('每位學生輸出一份註記，寫入對應「輸出\座號-註記.md」格式：題號註記、對錯摘要、個別診斷、程度、個別建議、依程度練習（題目與解答分段）。')
  [void]$sb.AppendLine('跟上者：少鞏固、多再提升挑戰（比原卷難一階）；好的學生要能再進步，勿只出簡單重複題。')
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

function Build-CursorPromptOne([string]$root, $studentFile) {
  $id = Get-StudentId $studentFile.Name
  $ansFiles = @(Get-AnswerFiles $root)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('請直接批閱這一位學生的數學試卷（一人一檔）。')
  [void]$sb.AppendLine('規則：以我提供的正確答案為準；接受合理等價解法；看不懂標 ? 存疑（供我人工確認／重謄）。')
  [void]$sb.AppendLine('請務必輸出：')
  [void]$sb.AppendLine('1) 題號註記（✓／✗／?）')
  [void]$sb.AppendLine('2) 對錯摘要')
  [void]$sb.AppendLine('3) 個別診斷結果（弱點類型、是否跟得上進度）')
  [void]$sb.AppendLine('4) 程度分級：跟上／略落後／明顯落後／需補先備')
  [void]$sb.AppendLine('5) 個別建議（短）')
  [void]$sb.AppendLine('6) 依程度自學／補救練習：先列出全部練習題；解答全部放在題目之後（另段「解答」）。')
  [void]$sb.AppendLine('   - 跟上：少鞏固、多靈活＋再提升挑戰（比原卷難一階）＋可選超前伸展；禁止只改數字的簡單重複題。好的學生要能再提升。')
  [void]$sb.AppendLine('   - 略落後：對應錯題類型；明顯落後／需補先備：降階、少而精。')
  [void]$sb.AppendLine('格式方便我貼回批改程式／存成 輸出\' + $id + '-註記.md')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('座號：' + $id)
  [void]$sb.AppendLine('學生試卷：' + $studentFile.FullName)
  [void]$sb.AppendLine('正確答案檔：')
  if ($ansFiles.Count -eq 0) {
    [void]$sb.AppendLine(' （尚未放入標準答案，請老師一併上傳答案）')
  } else {
    foreach ($a in $ansFiles) { [void]$sb.AppendLine(' - ' + $a.FullName) }
  }
  return $sb.ToString()
}

# ----- UI -----
if ([string]::IsNullOrWhiteSpace($WorkDir)) { $WorkDir = Get-DefaultWorkDir }
Ensure-WorkTree $WorkDir
$script:WorkDir = $WorkDir
$script:settings = Load-Settings $WorkDir

$font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 12)
$fontBig = New-Object System.Drawing.Font('Microsoft JhengHei UI', 15, [System.Drawing.FontStyle]::Bold)

$form = New-Object System.Windows.Forms.Form
$form.Text = '數學習作批改（一人一檔｜先載入答案或請 Cursor 批）'
$form.Size = New-Object System.Drawing.Size(1000, 720)
$form.StartPosition = 'CenterScreen'
$form.Font = $font
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 248, 244)

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = '建議：先載入正確答案 → 再一檔一檔批（自己對照或請 Cursor）'
$lbl.Font = $fontBig
$lbl.ForeColor = [System.Drawing.Color]::FromArgb(20, 70, 50)
$lbl.Location = New-Object System.Drawing.Point(16, 10)
$lbl.Size = New-Object System.Drawing.Size(960, 28)

# --- 開始區：答案＋模式 ---
$grpStart = New-Object System.Windows.Forms.GroupBox
$grpStart.Text = '① 開始：正確答案與批閱方式'
$grpStart.Location = New-Object System.Drawing.Point(16, 42)
$grpStart.Size = New-Object System.Drawing.Size(950, 88)

$lblAns = New-Object System.Windows.Forms.Label
$lblAns.Location = New-Object System.Drawing.Point(12, 28)
$lblAns.Size = New-Object System.Drawing.Size(700, 22)
$grpStart.Controls.Add($lblAns)

$cmbMode = New-Object System.Windows.Forms.ComboBox
$cmbMode.DropDownStyle = 'DropDownList'
$cmbMode.Items.AddRange(@('自己對照批（開啟答案＋學生卷）', '請 Cursor 直接批閱（複製提示並開檔）'))
$cmbMode.Location = New-Object System.Drawing.Point(12, 52)
$cmbMode.Size = New-Object System.Drawing.Size(360, 28)
if ($script:settings.mode -eq 'cursor') { $cmbMode.SelectedIndex = 1 } else { $cmbMode.SelectedIndex = 0 }
$grpStart.Controls.Add($cmbMode)

function Refresh-AnswerLabel {
  $files = @(Get-AnswerFiles $script:WorkDir)
  if ($files.Count -eq 0) {
    $lblAns.Text = '正確答案：尚未載入（請先「載入正確答案」）'
    $lblAns.ForeColor = [System.Drawing.Color]::DarkRed
  } else {
    $names = ($files | ForEach-Object { $_.Name }) -join '、'
    $lblAns.Text = "正確答案：已載入 $($files.Count) 個｜$names"
    $lblAns.ForeColor = [System.Drawing.Color]::FromArgb(20, 70, 50)
  }
}

$btnLoadAns = New-Object System.Windows.Forms.Button
$btnLoadAns.Text = '載入正確答案'
$btnLoadAns.Location = New-Object System.Drawing.Point(390, 48)
$btnLoadAns.Size = New-Object System.Drawing.Size(130, 32)
$btnLoadAns.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Title = '選擇正確答案（可多選）'
    $ofd.Filter = '答案檔|*.pdf;*.png;*.jpg;*.jpeg;*.txt;*.md|所有檔|*.*'
    $ofd.Multiselect = $true
    if ($ofd.ShowDialog() -eq 'OK') {
      $dest = Join-Path $script:WorkDir '標準答案'
      foreach ($f in $ofd.FileNames) {
        Copy-Item -LiteralPath $f -Destination (Join-Path $dest ([IO.Path]::GetFileName($f))) -Force
      }
      Refresh-AnswerLabel
      $status.Text = '已載入正確答案，可開始一檔一檔批'
    }
  })
$grpStart.Controls.Add($btnLoadAns)

$btnOpenAns = New-Object System.Windows.Forms.Button
$btnOpenAns.Text = '開啟答案對照'
$btnOpenAns.Location = New-Object System.Drawing.Point(530, 48)
$btnOpenAns.Size = New-Object System.Drawing.Size(130, 32)
$btnOpenAns.Add_Click({
    $files = @(Get-AnswerFiles $script:WorkDir)
    if ($files.Count -eq 0) {
      [void][System.Windows.Forms.MessageBox]::Show('尚未載入正確答案', '提示')
      return
    }
    foreach ($f in $files) { Start-Process -FilePath $f.FullName }
  })
$grpStart.Controls.Add($btnOpenAns)

$btnOpenAnsFolder = New-Object System.Windows.Forms.Button
$btnOpenAnsFolder.Text = '答案資料夾'
$btnOpenAnsFolder.Location = New-Object System.Drawing.Point(670, 48)
$btnOpenAnsFolder.Size = New-Object System.Drawing.Size(110, 32)
$btnOpenAnsFolder.Add_Click({ Start-Process explorer.exe (Join-Path $script:WorkDir '標準答案') })
$grpStart.Controls.Add($btnOpenAnsFolder)

$cmbMode.Add_SelectedIndexChanged({
    $script:settings = [pscustomobject]@{
      mode = $(if ($cmbMode.SelectedIndex -eq 1) { 'cursor' } else { 'manual' })
      answerHint = [string]$lblAns.Text
    }
    Save-Settings $script:WorkDir $script:settings
  })

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Location = New-Object System.Drawing.Point(16, 136)
$lblPath.Size = New-Object System.Drawing.Size(960, 22)

$list = New-Object System.Windows.Forms.ListBox
$list.Location = New-Object System.Drawing.Point(16, 164)
$list.Size = New-Object System.Drawing.Size(300, 340)
$list.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 13)

$grp = New-Object System.Windows.Forms.GroupBox
$grp.Text = '② 目前學生註記'
$grp.Location = New-Object System.Drawing.Point(336, 164)
$grp.Size = New-Object System.Drawing.Size(630, 340)

function Add-L([int]$y, [string]$t) {
  $l = New-Object System.Windows.Forms.Label
  $l.Text = $t
  $l.Location = New-Object System.Drawing.Point(16, $y)
  $l.Size = New-Object System.Drawing.Size(100, 28)
  $grp.Controls.Add($l)
}

Add-L 24 '總評'
$cmbOverall = New-Object System.Windows.Forms.ComboBox
$cmbOverall.DropDownStyle = 'DropDownList'
$cmbOverall.Items.AddRange(@('未批', '大致正確', '部分錯誤', '需補救', '存疑多'))
$cmbOverall.SelectedIndex = 0
$cmbOverall.Location = New-Object System.Drawing.Point(120, 24)
$cmbOverall.Size = New-Object System.Drawing.Size(150, 28)
$grp.Controls.Add($cmbOverall)

$lbLevel = New-Object System.Windows.Forms.Label
$lbLevel.Text = '程度'
$lbLevel.Location = New-Object System.Drawing.Point(280, 24)
$lbLevel.Size = New-Object System.Drawing.Size(50, 28)
$grp.Controls.Add($lbLevel)
$cmbLevel = New-Object System.Windows.Forms.ComboBox
$cmbLevel.DropDownStyle = 'DropDownList'
$cmbLevel.Items.AddRange(@('待判定', '跟上', '略落後', '明顯落後', '需補先備'))
$cmbLevel.SelectedIndex = 0
$cmbLevel.Location = New-Object System.Drawing.Point(330, 24)
$cmbLevel.Size = New-Object System.Drawing.Size(140, 28)
$grp.Controls.Add($cmbLevel)

$btnFillPractice = New-Object System.Windows.Forms.Button
$btnFillPractice.Text = '依程度給練習'
$btnFillPractice.Location = New-Object System.Drawing.Point(480, 22)
$btnFillPractice.Size = New-Object System.Drawing.Size(130, 30)
$btnFillPractice.Add_Click({
    $txtPractice.Text = Get-PracticeTemplate ([string]$cmbLevel.SelectedItem)
  })
$grp.Controls.Add($btnFillPractice)
$cmbLevel.Add_SelectedIndexChanged({
    # 換程度時自動帶入對應練習架構（跟上＝再提升；落後＝補救）
    $lv = [string]$cmbLevel.SelectedItem
    if ($lv -and $lv -ne '待判定') {
      $txtPractice.Text = Get-PracticeTemplate $lv
    }
  })

Add-L 58 '題號註記'
$txtItems = New-Object System.Windows.Forms.TextBox
$txtItems.Multiline = $true
$txtItems.ScrollBars = 'Vertical'
$txtItems.Location = New-Object System.Drawing.Point(120, 58)
$txtItems.Size = New-Object System.Drawing.Size(490, 48)
$txtItems.Text = "1 ✓`r`n2 ✗`r`n3 ?"
$grp.Controls.Add($txtItems)

Add-L 112 '對錯摘要'
$txtSummary = New-Object System.Windows.Forms.TextBox
$txtSummary.Multiline = $true
$txtSummary.ScrollBars = 'Vertical'
$txtSummary.Location = New-Object System.Drawing.Point(120, 112)
$txtSummary.Size = New-Object System.Drawing.Size(490, 36)
$grp.Controls.Add($txtSummary)

Add-L 154 '診斷結果'
$txtDiagnosis = New-Object System.Windows.Forms.TextBox
$txtDiagnosis.Multiline = $true
$txtDiagnosis.ScrollBars = 'Vertical'
$txtDiagnosis.Location = New-Object System.Drawing.Point(120, 154)
$txtDiagnosis.Size = New-Object System.Drawing.Size(490, 48)
$txtDiagnosis.Text = '弱點：`r`n是否跟上：'
$grp.Controls.Add($txtDiagnosis)

Add-L 208 '個別建議'
$txtAdvice = New-Object System.Windows.Forms.TextBox
$txtAdvice.Multiline = $true
$txtAdvice.ScrollBars = 'Vertical'
$txtAdvice.Location = New-Object System.Drawing.Point(120, 208)
$txtAdvice.Size = New-Object System.Drawing.Size(490, 36)
$grp.Controls.Add($txtAdvice)

Add-L 250 '自學練習'
$txtPractice = New-Object System.Windows.Forms.TextBox
$txtPractice.Multiline = $true
$txtPractice.ScrollBars = 'Vertical'
$txtPractice.Location = New-Object System.Drawing.Point(120, 250)
$txtPractice.Size = New-Object System.Drawing.Size(490, 70)
$txtPractice.Text = '（先寫全部練習題；解答另段「解答」，做完再看）'
$grp.Controls.Add($txtPractice)

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(16, 640)
$status.Size = New-Object System.Drawing.Size(950, 28)
$status.Text = '請先「載入正確答案」，再選批閱方式'

$script:files = @()
$script:current = $null

function Refresh-PathLabel {
  $lblPath.Text = '工作資料夾：' + $script:WorkDir + '　　（輸入＝學生卷｜輸出＝註記PDF）'
}

function Ensure-AnswerOrWarn {
  $files = @(Get-AnswerFiles $script:WorkDir)
  if ($files.Count -eq 0) {
    $r = [System.Windows.Forms.MessageBox]::Show(
      "尚未載入正確答案。`n建議先載入以便比對。`n仍要繼續嗎？",
      '正確答案',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    return ($r -eq 'Yes')
  }
  return $true
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
  if ($n.overall -and $cmbOverall.Items.Contains($n.overall)) {
    $cmbOverall.SelectedItem = $n.overall
  } else { $cmbOverall.SelectedIndex = 0 }
  if ($n.level -and $cmbLevel.Items.Contains($n.level)) {
    $cmbLevel.SelectedItem = $n.level
  } else { $cmbLevel.SelectedIndex = 0 }
  $txtItems.Text = $(if ($n.itemsText) { $n.itemsText } else { "1 ✓`r`n2 ✗`r`n3 ?" })
  $txtSummary.Text = [string]$n.summary
  $txtDiagnosis.Text = $(if ($n.diagnosis) { [string]$n.diagnosis } else { "弱點：`r`n是否跟上：" })
  $txtAdvice.Text = [string]$n.advice
  $txtPractice.Text = $(if ($n.practice) { [string]$n.practice } else { '（題目＋解答；可按「依程度帶入練習架構」）' })
  $status.Text = '目前：座號 ' + $id + '｜' + $f.Name
}

$list.Add_SelectedIndexChanged({ Load-Selected })

function Start-GradeCurrent {
  if (-not $script:current) {
    [void][System.Windows.Forms.MessageBox]::Show('請先選左側一位學生', '提示')
    return
  }
  if (-not (Ensure-AnswerOrWarn)) { return }

  if ($cmbMode.SelectedIndex -eq 1) {
    # Cursor 直接批閱
    $p = Build-CursorPromptOne $script:WorkDir $script:current
    [System.Windows.Forms.Clipboard]::SetText($p)
    Start-Process -FilePath $script:current.FullName
    $ans = @(Get-AnswerFiles $script:WorkDir)
    foreach ($a in $ans) { Start-Process -FilePath $a.FullName }
    $status.Text = '已複製 Cursor 提示，並開啟學生卷＋答案；請到 Cursor 貼上並附檔'
    [void][System.Windows.Forms.MessageBox]::Show(
      "已複製「請 Cursor 直接批閱」提示到剪貼簿。`n並已開啟此生試卷與正確答案。`n`n請到 Cursor 貼上並附檔。`n請 Cursor 一併給：診斷結果、程度、自學／補救練習（含解答）。`n貼回右側後按「輸出此生PDF」。",
      '請 Cursor 批閱'
    )
  } else {
    # 自己對照
    Start-Process -FilePath $script:current.FullName
    $ans = @(Get-AnswerFiles $script:WorkDir)
    foreach ($a in $ans) { Start-Process -FilePath $a.FullName }
    $status.Text = '已開啟答案＋此生試卷，請對照後填註記'
  }
}

function Save-Current {
  if (-not $script:current) {
    [void][System.Windows.Forms.MessageBox]::Show('請先選左側一位學生', '提示')
    return $null
  }
  $id = Get-StudentId $script:current.Name
  $path = Save-Note -Root $script:WorkDir -StudentId $id -SourceFile $script:current.Name `
    -Overall ([string]$cmbOverall.SelectedItem) -Level ([string]$cmbLevel.SelectedItem) `
    -ItemsText $txtItems.Text -Summary $txtSummary.Text `
    -Diagnosis $txtDiagnosis.Text -Advice $txtAdvice.Text -Practice $txtPractice.Text
  [void](Invoke-MakePdf -Root $script:WorkDir -Student $id -MergeOriginal)
  Refresh-List
  for ($i = 0; $i -lt $list.Items.Count; $i++) {
    if ($list.Items[$i].ToString().StartsWith($id + ' ')) { $list.SelectedIndex = $i; break }
  }
  $pdf1 = Join-Path (Join-Path $script:WorkDir '輸出') ($id + '-批閱註記.pdf')
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
      Start-GradeCurrent
      $status.Text = "下一位未批：座號 $id"
      return
    }
  }
  [void][System.Windows.Forms.MessageBox]::Show("全員都有註記了。`n可按「產生全班存疑清單」處理看不懂的地方。", '完成')
}

$y1 = 520
$btnWork = New-Object System.Windows.Forms.Button
$btnWork.Text = '選工作資料夾'
$btnWork.Location = New-Object System.Drawing.Point(16, $y1)
$btnWork.Size = New-Object System.Drawing.Size(130, 36)
$btnWork.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.SelectedPath = $script:WorkDir
    if ($d.ShowDialog() -eq 'OK') {
      $script:WorkDir = $d.SelectedPath
      Ensure-WorkTree $script:WorkDir
      $script:settings = Load-Settings $script:WorkDir
      if ($script:settings.mode -eq 'cursor') { $cmbMode.SelectedIndex = 1 } else { $cmbMode.SelectedIndex = 0 }
      Refresh-PathLabel
      Refresh-AnswerLabel
      Refresh-List
    }
  })

$btnOpenIn = New-Object System.Windows.Forms.Button
$btnOpenIn.Text = '輸入夾'
$btnOpenIn.Location = New-Object System.Drawing.Point(156, $y1)
$btnOpenIn.Size = New-Object System.Drawing.Size(90, 36)
$btnOpenIn.Add_Click({ Start-Process explorer.exe (Join-Path $script:WorkDir '輸入') })

$btnOpenOut = New-Object System.Windows.Forms.Button
$btnOpenOut.Text = '輸出夾'
$btnOpenOut.Location = New-Object System.Drawing.Point(256, $y1)
$btnOpenOut.Size = New-Object System.Drawing.Size(90, 36)
$btnOpenOut.Add_Click({ Start-Process explorer.exe (Join-Path $script:WorkDir '輸出') })

$btnGrade = New-Object System.Windows.Forms.Button
$btnGrade.Text = '開始批此生'
$btnGrade.Location = New-Object System.Drawing.Point(356, $y1)
$btnGrade.Size = New-Object System.Drawing.Size(120, 36)
$btnGrade.BackColor = [System.Drawing.Color]::FromArgb(40, 90, 140)
$btnGrade.ForeColor = [System.Drawing.Color]::White
$btnGrade.FlatStyle = 'Flat'
$btnGrade.Add_Click({ Start-GradeCurrent })

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = '輸出此生PDF'
$btnSave.Location = New-Object System.Drawing.Point(486, $y1)
$btnSave.Size = New-Object System.Drawing.Size(130, 36)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 70)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = 'Flat'
$btnSave.Add_Click({ [void](Save-Current) })

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = '下一位未批'
$btnNext.Location = New-Object System.Drawing.Point(626, $y1)
$btnNext.Size = New-Object System.Drawing.Size(120, 36)
$btnNext.Add_Click({ Select-NextUngraded })

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = '重新整理'
$btnRefresh.Location = New-Object System.Drawing.Point(756, $y1)
$btnRefresh.Size = New-Object System.Drawing.Size(100, 36)
$btnRefresh.Add_Click({ Refresh-List; Refresh-AnswerLabel })

$y2 = 566
$btnCsv = New-Object System.Windows.Forms.Button
$btnCsv.Text = '全班學習總表'
$btnCsv.Location = New-Object System.Drawing.Point(16, $y2)
$btnCsv.Size = New-Object System.Drawing.Size(130, 28)
$btnCsv.BackColor = [System.Drawing.Color]::FromArgb(120, 70, 20)
$btnCsv.ForeColor = [System.Drawing.Color]::White
$btnCsv.FlatStyle = 'Flat'
$btnCsv.Add_Click({
    $csv = Export-ClassCsv $script:WorkDir
    if (Invoke-MakePdf -Root $script:WorkDir -ClassReport) {
      $rep = Join-Path (Join-Path $script:WorkDir '輸出') '全班學習狀況總表.pdf'
      $status.Text = "已產出導師／家長用總表：$rep ｜ $csv"
      if (Test-Path -LiteralPath $rep) { Start-Process -FilePath $rep }
      [void][System.Windows.Forms.MessageBox]::Show(
        "已產出全班學習狀況總表（導師／家長用）：`n$rep`n`n另有 .md / .csv。`n建議在全班逐一經 Cursor＋老師確認後再產。",
        '全班總表'
      )
    } else {
      $status.Text = '已匯出簡易 CSV：' + $csv
    }
  })

$btnUnclear = New-Object System.Windows.Forms.Button
$btnUnclear.Text = '產生全班存疑清單'
$btnUnclear.Location = New-Object System.Drawing.Point(156, $y2)
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
$btnClarify.Location = New-Object System.Drawing.Point(300, $y2)
$btnClarify.Size = New-Object System.Drawing.Size(200, 28)
$btnClarify.Add_Click({
    if (Invoke-MakePdf -Root $script:WorkDir -ApplyClarifications -UnclearList -MergeOriginal) {
      $status.Text = '已套用認知／重謄並重產 PDF'
      [void][System.Windows.Forms.MessageBox]::Show("已讀取「認知輸入」「重謄補充」並重產輸出 PDF。", '完成')
    }
  })

$btnOpenCog = New-Object System.Windows.Forms.Button
$btnOpenCog.Text = '認知／重謄夾'
$btnOpenCog.Location = New-Object System.Drawing.Point(512, $y2)
$btnOpenCog.Size = New-Object System.Drawing.Size(120, 28)
$btnOpenCog.Add_Click({
    Start-Process explorer.exe (Join-Path $script:WorkDir '認知輸入')
  })

$form.Controls.AddRange(@(
    $lbl, $grpStart, $lblPath, $list, $grp, $status,
    $btnWork, $btnOpenIn, $btnOpenOut, $btnGrade, $btnSave, $btnNext, $btnRefresh,
    $btnCsv, $btnUnclear, $btnClarify, $btnOpenCog
  ))

Refresh-PathLabel
Refresh-AnswerLabel
Refresh-List
if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }

[void]$form.ShowDialog()
