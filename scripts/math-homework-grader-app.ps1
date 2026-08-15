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
  foreach ($n in @('標準答案', '輸入', '輸出', '認知輸入', '重謄補充', '數位練習', '列印專用', '練習回傳', '練習歷程')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $n) | Out-Null
  }
  $printList = Join-Path (Join-Path $root '列印專用') '需列印座號.txt'
  if (-not (Test-Path -LiteralPath $printList)) {
    @(
      '# 沒有手機／平板等通訊裝置、需要紙本練習的座號'
      '# 一行一個，或用逗號分隔，例如：03  或  07, 12, 18'
      ''
    ) | Set-Content -LiteralPath $printList -Encoding UTF8
  }
  $readme = Join-Path $root '說明.txt'
  @(
    '全班試卷批改（一人一檔 → 個人 PDF 註記）'
    ''
    '1. 標準答案 →「標準答案」'
    '2. 每位學生試卷一個檔 →「輸入」（如 05.pdf）'
    '3. 批改後「輸出」會有：05-註記.md、05-批閱註記.pdf、05-試卷含批閱.pdf'
    '4. 練習題預設進「數位練習」（手機可開）；有裝置用 LINE／雲端發放'
    '5. 學生回傳 PDF／圖 →「練習回傳」（檔名 05-R01.jpg）→ 按「練習回傳循環」批閱調題'
    '6. 歷程／分數進步在「練習歷程」；沒裝置才用「列印專用」'
    '7. 看不懂的標 ?；全班批完後開「全班存疑清單」'
    '8. 詳見「數位發放與回傳說明.txt」'
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
    [switch]$ClassReport,
    [switch]$DigitalPack,
    [switch]$PrintPack,
    [switch]$PendingReturns,
    [switch]$JunyiList,
    [switch]$ProgressHtml,
    [switch]$AppendAttempt,
    [string]$AttemptJson = ''
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
  if ($DigitalPack) { $argList += '--digital-pack' }
  if ($PrintPack) { $argList += '--print-pack' }
  if ($PendingReturns) { $argList += '--pending-returns' }
  if ($ProgressHtml) { $argList += '--progress-html' }
  if ($AppendAttempt) {
    $argList += '--append-attempt'
    if ($AttemptJson) { $argList += @('--attempt-json', $AttemptJson) }
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
### 程度：明顯落後｜目標：多次補齊、每次有成就（漸次跟上）
原則：不要一次補完。採「多次、小量」：每次只補 1 個小洞、題數 ≤ 3；做對就停，隔日／隔次再補下一個。
先備缺口清單（可分多次）：________
本次只補其中 1 點：________

#### 練習題（先做完再看解答｜總題數 ≤ 3）
【A 本次小洞｜求做對有成就】
1. …
2. …

【B 極簡銜接｜選做】
3. …

---
#### 解答（全部題目完成後再看｜逐步寫）
1. …
2. …
3. …
說明：本次成功＝有成就；未補完的點下次再補，不追全班、不多輪連催。
（可選）均一對應技能／任務：________（線上練；紙本回傳仍交老師）
"@
    }
    '需補先備' {
      return @"
### 程度：需補先備｜目標：分次回到起點（多次補齊）
原則：舊單元也拆成多次；每次 1 個觀念、≤3 題；成功後隔幾天再下一次，讓她有成就再漸次跟上。
建議先備單元：________
本次只補：________（1 個觀念）
尚未補、下次再補：________
（可選）均一先備技能／影片：________

#### 練習題（先做完再看解答｜總題數 ≤ 3）
1. （先備極短題）
2. （先備極短題）
3. （極簡銜接｜選做）

---
#### 解答（全部題目完成後再看）
1. …
2. …
3. …
建議：與導師／補救協調；家長說明「多次小補、不趕一次補完」。線上可用均一練同技能，手寫過程仍可回傳本程式。
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
  $defaults = [pscustomobject]@{
    mode = 'manual'
    answerHint = ''
    preferredSend = '未指定（日後再選）'
    preferredReturn = '未指定（日後再選）'
    tools = [pscustomobject]@{
      line_group = $true
      line_dm    = $true
      classroom  = $true
      drive      = $true
      lms        = $true
      junyi      = $true
      print      = $true
      loop       = $true
    }
  }
  if (Test-Path -LiteralPath $p) {
    try {
      $s = Get-Content -LiteralPath $p -Encoding UTF8 -Raw | ConvertFrom-Json
      if (-not $s.tools) { $s | Add-Member -NotePropertyName tools -NotePropertyValue $defaults.tools -Force }
      if (-not $s.preferredSend) { $s | Add-Member -NotePropertyName preferredSend -NotePropertyValue $defaults.preferredSend -Force }
      if (-not $s.preferredReturn) { $s | Add-Member -NotePropertyName preferredReturn -NotePropertyValue $defaults.preferredReturn -Force }
      return $s
    } catch {}
  }
  return $defaults
}

function Save-Settings([string]$root, $settings) {
  ($settings | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath (Get-SettingsPath $root) -Encoding UTF8
}

function Get-ToolCatalog {
  return @(
    [pscustomobject]@{ Id = 'line_group'; Title = 'LINE 班級群組'; Role = '偏發放'; Tip = '發練習連結／公告最方便；不建議全班回傳圖塞群組（難對座號、洗版）' }
    [pscustomobject]@{ Id = 'line_dm';    Title = 'LINE 個別傳老師'; Role = '偏回傳'; Tip = '學生／家長私訊傳 PDF／圖 → 老師另存「練習回傳\\05-R01.jpg」' }
    [pscustomobject]@{ Id = 'classroom';  Title = 'Google Classroom'; Role = '發＋回'; Tip = '發作業＋繳交最整齊；下載後丟「練習回傳」即可批' }
    [pscustomobject]@{ Id = 'drive';      Title = 'Google雲端／OneDrive'; Role = '發＋回'; Tip = '共用「發放」「回傳」兩夾；檔名 05-R01.jpg' }
    [pscustomobject]@{ Id = 'lms';        Title = '學校LMS／email'; Role = '發＋回'; Tip = '校內平台或信箱收件，最後匯入「練習回傳」' }
    [pscustomobject]@{ Id = 'junyi';      Title = '均一教育平台'; Role = '線上練'; Tip = '依問題點指派均一技能／影片；分析報告看熟練度；紙本回傳仍用本程式批' }
    [pscustomobject]@{ Id = 'print';      Title = '無裝置列印'; Role = '發'; Tip = '只印「需列印座號」；有裝置仍走數位' }
    [pscustomobject]@{ Id = 'loop';       Title = '練習回傳循環'; Role = '批＋調題'; Tip = '回饋→調題→分數進步→達標為止（與上面發放管道並用）' }
  )
}

function Show-ToolPickerDialog {
  $dlg = New-Object System.Windows.Forms.Form
  $dlg.Text = '發放／回傳工具（可複選，日後再抉擇）'
  $dlg.Size = New-Object System.Drawing.Size(760, 580)
  $dlg.StartPosition = 'CenterParent'
  $dlg.Font = $font

  $hint = New-Object System.Windows.Forms.Label
  $hint.Text = "怎麼選？`n• 只想快：發＝LINE班級群組；回＝LINE個別傳老師（別把全班圖塞群組）`n• 想整齊長期用：Classroom 或 雲端兩夾`n勾選＝常用；偏好可日後再改，按鈕都還在。"
  $hint.Location = New-Object System.Drawing.Point(12, 8)
  $hint.Size = New-Object System.Drawing.Size(720, 58)
  $dlg.Controls.Add($hint)

  $checks = @{}
  $y = 72
  foreach ($t in Get-ToolCatalog) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = "[$($t.Role)] $($t.Title)  —  $($t.Tip)"
    $cb.Location = New-Object System.Drawing.Point(16, $y)
    $cb.Size = New-Object System.Drawing.Size(710, 34)
    $on = $true
    try { $on = [bool]$script:settings.tools.($t.Id) } catch { $on = $true }
    $cb.Checked = $on
    $dlg.Controls.Add($cb)
    $checks[$t.Id] = $cb
    $y += 36
  }

  $lblSend = New-Object System.Windows.Forms.Label
  $lblSend.Text = '偏好發放'
  $lblSend.Location = New-Object System.Drawing.Point(16, $y + 8)
  $lblSend.Size = New-Object System.Drawing.Size(90, 24)
  $dlg.Controls.Add($lblSend)

  $cmbSend = New-Object System.Windows.Forms.ComboBox
  $cmbSend.DropDownStyle = 'DropDownList'
  $cmbSend.Items.AddRange(@(
      '未指定（日後再選）',
      'LINE 班級群組',
      '均一教育平台（線上練）',
      'Google Classroom',
      'Google雲端／OneDrive',
      '學校LMS／email',
      '無裝置列印'
    ))
  $cmbSend.Location = New-Object System.Drawing.Point(110, $y + 4)
  $cmbSend.Size = New-Object System.Drawing.Size(240, 28)
  $idxS = $cmbSend.Items.IndexOf([string]$script:settings.preferredSend)
  $cmbSend.SelectedIndex = $(if ($idxS -ge 0) { $idxS } else { 0 })
  $dlg.Controls.Add($cmbSend)

  $lblRet = New-Object System.Windows.Forms.Label
  $lblRet.Text = '偏好回傳'
  $lblRet.Location = New-Object System.Drawing.Point(370, $y + 8)
  $lblRet.Size = New-Object System.Drawing.Size(90, 24)
  $dlg.Controls.Add($lblRet)

  $cmbRet = New-Object System.Windows.Forms.ComboBox
  $cmbRet.DropDownStyle = 'DropDownList'
  $cmbRet.Items.AddRange(@(
      '未指定（日後再選）',
      'LINE 個別傳老師',
      'Google Classroom',
      'Google雲端／OneDrive',
      '學校LMS／email'
    ))
  $cmbRet.Location = New-Object System.Drawing.Point(460, $y + 4)
  $cmbRet.Size = New-Object System.Drawing.Size(240, 28)
  $idxR = $cmbRet.Items.IndexOf([string]$script:settings.preferredReturn)
  $cmbRet.SelectedIndex = $(if ($idxR -ge 0) { $idxR } else { 0 })
  $dlg.Controls.Add($cmbRet)

  $btnOk = New-Object System.Windows.Forms.Button
  $btnOk.Text = '儲存選擇'
  $btnOk.Location = New-Object System.Drawing.Point(460, $y + 44)
  $btnOk.Size = New-Object System.Drawing.Size(100, 32)
  $btnOk.Add_Click({
      $tools = [pscustomobject]@{}
      foreach ($k in $checks.Keys) {
        $tools | Add-Member -NotePropertyName $k -NotePropertyValue ([bool]$checks[$k].Checked) -Force
      }
      $script:settings | Add-Member -NotePropertyName tools -NotePropertyValue $tools -Force
      $script:settings | Add-Member -NotePropertyName preferredSend -NotePropertyValue ([string]$cmbSend.SelectedItem) -Force
      $script:settings | Add-Member -NotePropertyName preferredReturn -NotePropertyValue ([string]$cmbRet.SelectedItem) -Force
      Save-Settings $script:WorkDir $script:settings
      $lines = @(
        '我的發放／回傳工具選擇（可隨時改）'
        '================================'
        ('偏好發放：' + $script:settings.preferredSend)
        ('偏好回傳：' + $script:settings.preferredReturn)
        ''
        '建議組合：'
        '・快又省事 → 發：LINE班級群組　回：LINE個別傳老師'
        '・線上練技能 → 均一指派（依問題點）；紙本／手寫回傳仍用本程式'
        '・要長期整齊 → 發＋回都用 Classroom 或 雲端兩夾'
        '・群組只公告，不要當作業回收桶'
        ''
        '已勾選常用工具：'
      )
      foreach ($t in Get-ToolCatalog) {
        $flag = if ($checks[$t.Id].Checked) { '☑' } else { '☐' }
        $lines += ("$flag $($t.Title)｜$($t.Tip)")
      }
      $out = Join-Path $script:WorkDir '我的工具選擇.txt'
      $utf8Bom = New-Object System.Text.UTF8Encoding $true
      [IO.File]::WriteAllText($out, ($lines -join "`r`n"), $utf8Bom)
      $status.Text = '已儲存工具選擇：' + $out
      $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
      $dlg.Close()
    })
  $dlg.Controls.Add($btnOk)

  $btnGuide = New-Object System.Windows.Forms.Button
  $btnGuide.Text = '開說明'
  $btnGuide.Location = New-Object System.Drawing.Point(570, $y + 44)
  $btnGuide.Size = New-Object System.Drawing.Size(90, 32)
  $btnGuide.Add_Click({
      [void](Invoke-MakePdf -Root $script:WorkDir -PendingReturns)
      $g = Join-Path $script:WorkDir '數位發放與回傳說明.txt'
      if (Test-Path -LiteralPath $g) { Start-Process notepad.exe $g }
    })
  $dlg.Controls.Add($btnGuide)

  $btnQuick = New-Object System.Windows.Forms.Button
  $btnQuick.Text = '一鍵：LINE群發＋個別回'
  $btnQuick.Location = New-Object System.Drawing.Point(16, $y + 44)
  $btnQuick.Size = New-Object System.Drawing.Size(220, 32)
  $btnQuick.BackColor = [System.Drawing.Color]::FromArgb(30, 110, 90)
  $btnQuick.ForeColor = [System.Drawing.Color]::White
  $btnQuick.FlatStyle = 'Flat'
  $btnQuick.Add_Click({
      $cmbSend.SelectedItem = 'LINE 班級群組'
      $cmbRet.SelectedItem = 'LINE 個別傳老師'
      foreach ($k in @('line_group', 'line_dm', 'loop', 'print')) {
        if ($checks.ContainsKey($k)) { $checks[$k].Checked = $true }
      }
      [void][System.Windows.Forms.MessageBox]::Show(
        "已選好常用組合：`n發放 → LINE 班級群組`n回傳 → LINE 個別傳老師`n`n再按「儲存選擇」即可。`n（有 Classroom／雲端也可再勾，日後換用）",
        'LINE 組合'
      )
    })
  $dlg.Controls.Add($btnQuick)

  [void]$dlg.ShowDialog($form)
}

function Get-LatestReturnFile([string]$root, [string]$sid) {
  $dir = Join-Path $root '練習回傳'
  if (-not (Test-Path -LiteralPath $dir)) { return $null }
  $hits = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match ('^' + $sid) -and $_.Extension -match '\.(pdf|png|jpe?g|tif{1,2}|bmp|webp)$' } |
    Sort-Object LastWriteTime -Descending)
  if ($hits.Count -gt 0) { return $hits[0] }
  return $null
}

function Get-StudentLevelFromNote([string]$root, [string]$sid) {
  $p = Get-NotePath $root $sid
  if (-not (Test-Path -LiteralPath $p)) { return '待判定' }
  $n = Load-Note $p
  if ($n.level) { return [string]$n.level }
  return '待判定'
}

function Test-IsBehindLevel([string]$level) {
  return ($level -match '明顯落後|需補先備')
}

function Build-ReturnCursorPrompt([string]$root, [string]$sid, $returnFile, [int]$round) {
  $histPath = Join-Path (Join-Path $root '練習歷程') ($sid + '-歷程.json')
  $histTxt = ''
  if (Test-Path -LiteralPath $histPath) {
    $histTxt = Get-Content -LiteralPath $histPath -Raw -Encoding UTF8
  }
  $level = Get-StudentLevelFromNote $root $sid
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('請批閱這位學生「練習回傳」第 ' + $round + ' 次（PDF／圖檔）。')
  [void]$sb.AppendLine('程度：' + $level)
  [void]$sb.AppendLine('每次回饋都要含：分數、問題點說明、與前次比較的進步、下一輪題目（題目與解答分段）。')
  if (Test-IsBehindLevel $level) {
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('【落後生｜多次補齊 → 有成就 → 漸次跟上】')
    [void]$sb.AppendLine('- 回饋先寫做對／進步之處，再寫「下一次要補的那一小點」。')
    [void]$sb.AppendLine('- 一次只補 1 個洞、題數 ≤ 3；下一題只難一點點。')
    [void]$sb.AppendLine('- 「多次」是分日／分次小補，不是同一週連催很多輪；兩次之間宜隔開，保住成就感。')
    [void]$sb.AppendLine('- 階段小目標（約 60～70%）做對＝本次成功；未補完的點列入下次，不要求一次跟上全班。')
    [void]$sb.AppendLine('- 禁止：一次補太多、整卷難題、暗示「一直練到追上為止」。')
  } else {
    [void]$sb.AppendLine('目標：針對問題點給適切回饋；未達標可調下一輪，但略落後也建議本單元 ≤ 3 輪。')
  }
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('請輸出可直接貼回批改程式的欄位：')
  [void]$sb.AppendLine('1) 分數：得分/滿分（例 7/10）')
  [void]$sb.AppendLine('2) 問題點：本輪真正卡住處（具體、可再練）')
  [void]$sb.AppendLine('3) 回饋說明：對準問題點、短而可執行（落後生要鼓勵＋小步）')
  [void]$sb.AppendLine('4) 是否達標：是／否（可採階段小目標）')
  [void]$sb.AppendLine('5) 下一輪／下一次補齊：只接 1 個新小洞或鞏固本次成功；若需休息則寫「隔日再補＋1～2 題」')
  [void]$sb.AppendLine('6) 分數進步一句話＋本次成就一句話')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('座號：' + $sid)
  [void]$sb.AppendLine('本輪回傳檔：' + $(if ($returnFile) { $returnFile.FullName } else { '（尚未放入練習回傳）' }))
  [void]$sb.AppendLine('建議回傳檔名格式：' + $sid + '-R' + ('{0:D2}' -f $round) + '.jpg 或 .pdf')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('既有歷程 JSON（若有）：')
  if ($histTxt) { [void]$sb.AppendLine($histTxt) } else { [void]$sb.AppendLine('（尚無，此為第 1 次）') }
  return $sb.ToString()
}

function Show-PracticeLoopDialog {
  if (-not $script:current) {
    [void][System.Windows.Forms.MessageBox]::Show('請先在主畫面選左側一位學生', '提示')
    return
  }
  $sid = Get-StudentId $script:current.Name
  Ensure-WorkTree $script:WorkDir
  $level = Get-StudentLevelFromNote $script:WorkDir $sid
  $behind = Test-IsBehindLevel $level

  $dlg = New-Object System.Windows.Forms.Form
  $dlg.Text = "練習回傳循環｜座號 $sid｜$level"
  $dlg.Size = New-Object System.Drawing.Size(780, 680)
  $dlg.StartPosition = 'CenterParent'
  $dlg.Font = $font

  $ret = Get-LatestReturnFile $script:WorkDir $sid
  $roundGuess = 1
  $histPath = Join-Path (Join-Path $script:WorkDir '練習歷程') ($sid + '-歷程.json')
  if (Test-Path -LiteralPath $histPath) {
    try {
      $h = Get-Content -LiteralPath $histPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($h.attempts) { $roundGuess = @($h.attempts).Count + 1 }
    } catch {}
  }
  if ($ret -and $ret.BaseName -match '[Rr]0*(\d+)') { $roundGuess = [int]$Matches[1] }
  elseif ($ret -and $ret.BaseName -match '第\s*(\d+)\s*次') { $roundGuess = [int]$Matches[1] }

  $paceNote = if ($behind) {
    '落後生：多次補齊（每次 1 點、≤3 題）→ 有成就再下次；勿一次補完、勿連催多輪。'
  } else {
    '可依問題點調下一輪；略落後也建議分次、少題。'
  }
  $lblInfo = New-Object System.Windows.Forms.Label
  $lblInfo.Text = $(if ($ret) { "最新回傳：$($ret.Name)`n$paceNote" } else { "尚無回傳檔 → 請放到「練習回傳」夾`n$paceNote" })
  $lblInfo.Location = New-Object System.Drawing.Point(12, 8)
  $lblInfo.Size = New-Object System.Drawing.Size(740, 42)
  $dlg.Controls.Add($lblInfo)

  function Add-DlgLabel([int]$yy, [string]$text) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point(12, $yy)
    $l.Size = New-Object System.Drawing.Size(120, 24)
    $dlg.Controls.Add($l)
  }

  Add-DlgLabel 56 '次數 R'
  $numRound = New-Object System.Windows.Forms.NumericUpDown
  $numRound.Location = New-Object System.Drawing.Point(140, 54)
  $numRound.Size = New-Object System.Drawing.Size(70, 28)
  $numRound.Minimum = 1; $numRound.Maximum = 99; $numRound.Value = [Math]::Max(1, [Math]::Min(99, $roundGuess))
  $dlg.Controls.Add($numRound)

  Add-DlgLabel 56 '分數'
  $txtScore = New-Object System.Windows.Forms.TextBox
  $txtScore.Location = New-Object System.Drawing.Point(280, 54)
  $txtScore.Size = New-Object System.Drawing.Size(60, 28)
  $txtScore.Text = '0'
  $dlg.Controls.Add($txtScore)

  $lblSlash = New-Object System.Windows.Forms.Label
  $lblSlash.Text = '/'
  $lblSlash.Location = New-Object System.Drawing.Point(345, 56)
  $lblSlash.Size = New-Object System.Drawing.Size(20, 24)
  $dlg.Controls.Add($lblSlash)

  $txtMax = New-Object System.Windows.Forms.TextBox
  $txtMax.Location = New-Object System.Drawing.Point(365, 54)
  $txtMax.Size = New-Object System.Drawing.Size(60, 28)
  $txtMax.Text = '100'
  $dlg.Controls.Add($txtMax)

  Add-DlgLabel 56 '目標%'
  $txtTarget = New-Object System.Windows.Forms.TextBox
  $txtTarget.Location = New-Object System.Drawing.Point(520, 54)
  $txtTarget.Size = New-Object System.Drawing.Size(60, 28)
  $txtTarget.Text = $(if ($behind) { '65' } else { '80' })
  $dlg.Controls.Add($txtTarget)

  $chkMet = New-Object System.Windows.Forms.CheckBox
  $chkMet.Text = '階段成功'
  $chkMet.Location = New-Object System.Drawing.Point(600, 56)
  $chkMet.Size = New-Object System.Drawing.Size(120, 24)
  $dlg.Controls.Add($chkMet)

  Add-DlgLabel 94 '學習目標'
  $txtGoal = New-Object System.Windows.Forms.TextBox
  $txtGoal.Location = New-Object System.Drawing.Point(140, 92)
  $txtGoal.Size = New-Object System.Drawing.Size(600, 28)
  $txtGoal.Text = $(if ($behind) {
      '多次補齊：本次只穩 1 點並讓她有成就；其餘下次再補，漸次跟上'
    } else {
      '針對問題點練到穩定掌握'
    })
  $dlg.Controls.Add($txtGoal)

  Add-DlgLabel 130 '問題點'
  $txtPP = New-Object System.Windows.Forms.TextBox
  $txtPP.Multiline = $true; $txtPP.ScrollBars = 'Vertical'
  $txtPP.Location = New-Object System.Drawing.Point(140, 128)
  $txtPP.Size = New-Object System.Drawing.Size(600, 64)
  $dlg.Controls.Add($txtPP)

  Add-DlgLabel 200 '回饋說明'
  $txtFb = New-Object System.Windows.Forms.TextBox
  $txtFb.Multiline = $true; $txtFb.ScrollBars = 'Vertical'
  $txtFb.Location = New-Object System.Drawing.Point(140, 198)
  $txtFb.Size = New-Object System.Drawing.Size(600, 80)
  $txtFb.Text = $(if ($behind) { '（先寫她做對了什麼 → 再寫下一步一小步；語氣要有成就感）' } else { '' })
  $dlg.Controls.Add($txtFb)

  Add-DlgLabel 288 '下一輪練習'
  $txtNext = New-Object System.Windows.Forms.TextBox
  $txtNext.Multiline = $true; $txtNext.ScrollBars = 'Vertical'
  $txtNext.Location = New-Object System.Drawing.Point(140, 286)
  $txtNext.Size = New-Object System.Drawing.Size(600, 150)
  if ($behind) {
    $txtNext.Text = @"
#### 練習題（本次補齊｜≤3題｜先延續成就）
【成就延續】剛做對的類型再穩一次
1. …

【下一次要補的一小點】（只難一點點；會做就停）
2. …
3. （選做）

---
#### 解答（全部題目完成後再看）
1. …
2. …
3. …
備註：未補完的洞下次再補＝多次補齊；中間可隔日，不要連催。
"@
  } else {
    $txtNext.Text = "#### 練習題（先做完再看解答）`r`n1. …`r`n`r`n---`r`n#### 解答（全部題目完成後再看）`r`n1. …"
  }
  $dlg.Controls.Add($txtNext)

  $btnOpenRet = New-Object System.Windows.Forms.Button
  $btnOpenRet.Text = '開回傳檔／夾'
  $btnOpenRet.Location = New-Object System.Drawing.Point(12, 460)
  $btnOpenRet.Size = New-Object System.Drawing.Size(130, 32)
  $btnOpenRet.Add_Click({
      Start-Process explorer.exe (Join-Path $script:WorkDir '練習回傳')
      if ($ret) { Start-Process -FilePath $ret.FullName }
    })
  $dlg.Controls.Add($btnOpenRet)

  $btnPrompt = New-Object System.Windows.Forms.Button
  $btnPrompt.Text = '複製Cursor批回傳'
  $btnPrompt.Location = New-Object System.Drawing.Point(150, 460)
  $btnPrompt.Size = New-Object System.Drawing.Size(150, 32)
  $btnPrompt.Add_Click({
      $p = Build-ReturnCursorPrompt $script:WorkDir $sid $ret ([int]$numRound.Value)
      [System.Windows.Forms.Clipboard]::SetText($p)
      if ($ret) { Start-Process -FilePath $ret.FullName }
      [void][System.Windows.Forms.MessageBox]::Show('已複製「批閱回傳」提示。請到 Cursor 貼上並附回傳檔，再把分數／問題點／回饋／下一輪練習貼回本視窗。', 'Cursor')
    })
  $dlg.Controls.Add($btnPrompt)

  $btnSave = New-Object System.Windows.Forms.Button
  $btnSave.Text = '儲存本輪＋下一輪數位練習'
  $btnSave.Location = New-Object System.Drawing.Point(310, 460)
  $btnSave.Size = New-Object System.Drawing.Size(240, 32)
  $btnSave.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 70)
  $btnSave.ForeColor = [System.Drawing.Color]::White
  $btnSave.FlatStyle = 'Flat'
  $btnSave.Add_Click({
      $score = 0.0; $max = 100.0; $target = 80.0
      [void][double]::TryParse($txtScore.Text, [ref]$score)
      [void][double]::TryParse($txtMax.Text, [ref]$max)
      [void][double]::TryParse($txtTarget.Text, [ref]$target)
      if ($max -le 0) { $max = 100 }
      $payload = [ordered]@{
        studentId     = $sid
        round         = [int]$numRound.Value
        sourceFile    = $(if ($ret) { $ret.Name } else { '' })
        score         = $score
        maxScore      = $max
        targetScore   = $target
        goal          = $txtGoal.Text
        problemPoints = $txtPP.Text
        feedback      = $txtFb.Text
        nextPractice  = $txtNext.Text
        goalMet       = [bool]$chkMet.Checked
      }
      # auto goalMet from score if unchecked but score high
      if (-not $chkMet.Checked -and $max -gt 0 -and (100.0 * $score / $max) -ge $target) {
        $payload.goalMet = $true
      }
      $jsonPath = Join-Path (Join-Path $script:WorkDir '練習歷程') ($sid + '-attempt-tmp.json')
      $utf8Bom = New-Object System.Text.UTF8Encoding $true
      [IO.File]::WriteAllText($jsonPath, ($payload | ConvertTo-Json -Depth 5), $utf8Bom)
      if (Invoke-MakePdf -Root $script:WorkDir -AppendAttempt -AttemptJson $jsonPath) {
        $status.Text = "已儲存座號 $sid 第 $($numRound.Value) 次回饋／歷程"
        $prog = Join-Path (Join-Path $script:WorkDir '練習歷程') ($sid + '-歷程.html')
        if (Test-Path -LiteralPath $prog) { Start-Process -FilePath $prog }
        [void][System.Windows.Forms.MessageBox]::Show(
          "已寫入練習歷程（含分數進步）。`n未達標者已更新「數位練習」下一輪題目。`n可再依你偏好的發放工具傳給學生。",
          '完成'
        )
      }
    })
  $dlg.Controls.Add($btnSave)

  $btnHist = New-Object System.Windows.Forms.Button
  $btnHist.Text = '開歷程'
  $btnHist.Location = New-Object System.Drawing.Point(560, 460)
  $btnHist.Size = New-Object System.Drawing.Size(90, 32)
  $btnHist.Add_Click({
      [void](Invoke-MakePdf -Root $script:WorkDir -Student $sid -ProgressHtml)
      $prog = Join-Path (Join-Path $script:WorkDir '練習歷程') ($sid + '-歷程.html')
      if (Test-Path -LiteralPath $prog) { Start-Process -FilePath $prog }
      else { Start-Process explorer.exe (Join-Path $script:WorkDir '練習歷程') }
    })
  $dlg.Controls.Add($btnHist)

  $btnPending = New-Object System.Windows.Forms.Button
  $btnPending.Text = '待批清單'
  $btnPending.Location = New-Object System.Drawing.Point(660, 460)
  $btnPending.Size = New-Object System.Drawing.Size(90, 32)
  $btnPending.Add_Click({
      if (Invoke-MakePdf -Root $script:WorkDir -PendingReturns) {
        $p = Join-Path (Join-Path $script:WorkDir '練習歷程') '待批閱回傳清單.md'
        if (Test-Path -LiteralPath $p) { Start-Process -FilePath $p }
      }
    })
  $dlg.Controls.Add($btnPending)

  $foot = New-Object System.Windows.Forms.Label
  $foot.Text = '落後生＝多次補齊（每次有成就）→ 漸次跟上。發放用群組公告、回傳走個別；工具可在「工具選擇」改。'
  $foot.Location = New-Object System.Drawing.Point(12, 520)
  $foot.Size = New-Object System.Drawing.Size(740, 40)
  $dlg.Controls.Add($foot)
  $foot.Location = New-Object System.Drawing.Point(12, 505)
  $foot.Size = New-Object System.Drawing.Size(740, 40)
  $dlg.Controls.Add($foot)

  [void]$dlg.ShowDialog($form)
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
  [void]$sb.AppendLine('   - 略落後：對應錯題類型，少而精。')
  [void]$sb.AppendLine('   - 明顯落後／需補先備：多次補齊（每次 1 點、≤3 題），先讓她做對有成就，再漸次跟上；勿一次補完、勿連催多輪。')
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
$form.Size = New-Object System.Drawing.Size(1000, 780)
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
$status.Location = New-Object System.Drawing.Point(16, 648)
$status.Size = New-Object System.Drawing.Size(950, 40)
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
  $dig = Join-Path (Join-Path $script:WorkDir '數位練習') ($id + '-練習題.html')
  $status.Text = "已輸出：$path ｜ PDF：$pdf1 ｜ 數位練習：$dig"
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
    Start-Process explorer.exe (Join-Path $script:WorkDir '重謄補充')
  })

$y3 = 600
$btnDigital = New-Object System.Windows.Forms.Button
$btnDigital.Text = '數位練習包（手機）'
$btnDigital.Location = New-Object System.Drawing.Point(16, $y3)
$btnDigital.Size = New-Object System.Drawing.Size(170, 32)
$btnDigital.BackColor = [System.Drawing.Color]::FromArgb(30, 110, 90)
$btnDigital.ForeColor = [System.Drawing.Color]::White
$btnDigital.FlatStyle = 'Flat'
$btnDigital.Add_Click({
    if (Invoke-MakePdf -Root $script:WorkDir -DigitalPack) {
      $dir = Join-Path $script:WorkDir '數位練習'
      $status.Text = "已產出數位練習包：$dir"
      Start-Process explorer.exe $dir
      $idx = Join-Path $dir 'index.html'
      if (Test-Path -LiteralPath $idx) { Start-Process -FilePath $idx }
      [void][System.Windows.Forms.MessageBox]::Show(
        "已產出「數位練習」資料夾（手機／平板可開）。`n`n建議：`n1. 整夾放到 Google 雲端／OneDrive 分享連結`n2. 或用 LINE 傳「座號-練習題.html」（做完再傳解答）`n3. 也可複製「LINE發放文案.txt」`n`n沒有裝置的學生：填「列印專用\需列印座號.txt」後按「無裝置列印包」。",
        '數位發放'
      )
    }
  })

$btnCopyLine = New-Object System.Windows.Forms.Button
$btnCopyLine.Text = '複製此生LINE訊息'
$btnCopyLine.Location = New-Object System.Drawing.Point(196, $y3)
$btnCopyLine.Size = New-Object System.Drawing.Size(160, 32)
$btnCopyLine.Add_Click({
    if (-not $script:current) {
      [void][System.Windows.Forms.MessageBox]::Show('請先選左側一位學生', '提示')
      return
    }
    $id = Get-StudentId $script:current.Name
    [void](Invoke-MakePdf -Root $script:WorkDir -Student $id -DigitalPack)
    $msgPath = Join-Path (Join-Path $script:WorkDir '數位練習') ($id + '-LINE訊息.txt')
    if (-not (Test-Path -LiteralPath $msgPath)) {
      [void][System.Windows.Forms.MessageBox]::Show("尚未有座號 $id 的練習內容。請先輸出此生註記／練習。", '提示')
      return
    }
    $msg = Get-Content -LiteralPath $msgPath -Raw -Encoding UTF8
    [System.Windows.Forms.Clipboard]::SetText($msg.Trim())
    $status.Text = "已複製座號 $id 的 LINE 發放訊息"
    [void][System.Windows.Forms.MessageBox]::Show("已複製到剪貼簿，可貼到 LINE／班級群組。`n`n$($msg.Trim())", 'LINE 訊息')
  })

$btnPrintPack = New-Object System.Windows.Forms.Button
$btnPrintPack.Text = '無裝置列印包'
$btnPrintPack.Location = New-Object System.Drawing.Point(366, $y3)
$btnPrintPack.Size = New-Object System.Drawing.Size(140, 32)
$btnPrintPack.BackColor = [System.Drawing.Color]::FromArgb(140, 90, 40)
$btnPrintPack.ForeColor = [System.Drawing.Color]::White
$btnPrintPack.FlatStyle = 'Flat'
$btnPrintPack.Add_Click({
    Ensure-WorkTree $script:WorkDir
    $listPath = Join-Path (Join-Path $script:WorkDir '列印專用') '需列印座號.txt'
    Start-Process notepad.exe $listPath
    $r = [System.Windows.Forms.MessageBox]::Show(
      "請在「需列印座號.txt」填入沒有通訊裝置的座號並存檔。`n`n存好後按「是」產出紙本 PDF（只印這些人）。",
      '無裝置列印包',
      [System.Windows.Forms.MessageBoxButtons]::YesNo
    )
    if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    if (Invoke-MakePdf -Root $script:WorkDir -PrintPack) {
      $dir = Join-Path $script:WorkDir '列印專用'
      $status.Text = "已產出列印包：$dir"
      Start-Process explorer.exe $dir
      [void][System.Windows.Forms.MessageBox]::Show(
        "已依「需列印座號.txt」產出練習題／解答 PDF。`n只印這些座號即可，其餘用數位發放。`n`n$dir",
        '列印包'
      )
    }
  })

$btnOpenDigital = New-Object System.Windows.Forms.Button
$btnOpenDigital.Text = '數位／列印夾'
$btnOpenDigital.Location = New-Object System.Drawing.Point(516, $y3)
$btnOpenDigital.Size = New-Object System.Drawing.Size(120, 32)
$btnOpenDigital.Add_Click({
    Start-Process explorer.exe (Join-Path $script:WorkDir '數位練習')
    Start-Process explorer.exe (Join-Path $script:WorkDir '列印專用')
  })

$y4 = 640
$btnTools = New-Object System.Windows.Forms.Button
$btnTools.Text = '工具選擇（LINE群／個別…）'
$btnTools.Location = New-Object System.Drawing.Point(16, $y4)
$btnTools.Size = New-Object System.Drawing.Size(220, 32)
$btnTools.BackColor = [System.Drawing.Color]::FromArgb(50, 80, 120)
$btnTools.ForeColor = [System.Drawing.Color]::White
$btnTools.FlatStyle = 'Flat'
$btnTools.Add_Click({ Show-ToolPickerDialog })

$btnLoop = New-Object System.Windows.Forms.Button
$btnLoop.Text = '練習回傳循環'
$btnLoop.Location = New-Object System.Drawing.Point(246, $y4)
$btnLoop.Size = New-Object System.Drawing.Size(140, 32)
$btnLoop.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 70)
$btnLoop.ForeColor = [System.Drawing.Color]::White
$btnLoop.FlatStyle = 'Flat'
$btnLoop.Add_Click({ Show-PracticeLoopDialog })

$btnRetFolder = New-Object System.Windows.Forms.Button
$btnRetFolder.Text = '練習回傳夾'
$btnRetFolder.Location = New-Object System.Drawing.Point(396, $y4)
$btnRetFolder.Size = New-Object System.Drawing.Size(110, 32)
$btnRetFolder.Add_Click({
    Ensure-WorkTree $script:WorkDir
    Start-Process explorer.exe (Join-Path $script:WorkDir '練習回傳')
  })

$form.Size = New-Object System.Drawing.Size(1000, 820)
$status.Location = New-Object System.Drawing.Point(16, 688)
$status.Size = New-Object System.Drawing.Size(950, 40)

$form.Controls.AddRange(@(
    $lbl, $grpStart, $lblPath, $list, $grp, $status,
    $btnWork, $btnOpenIn, $btnOpenOut, $btnGrade, $btnSave, $btnNext, $btnRefresh,
    $btnCsv, $btnUnclear, $btnClarify, $btnOpenCog,
    $btnDigital, $btnCopyLine, $btnPrintPack, $btnOpenDigital,
    $btnTools, $btnLoop, $btnRetFolder
  ))

Refresh-PathLabel
Refresh-AnswerLabel
Refresh-List
if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }

[void]$form.ShowDialog()
