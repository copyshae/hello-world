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
  foreach ($n in @('標準答案', '輸入', '輸出', '認知輸入', '重謄補充', '數位練習', '列印專用', '練習回傳', '練習歷程', '手寫匯入')) {
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
  $tabletGuide = Join-Path $root '手寫板即時批閱說明.txt'
  if (-not (Test-Path -LiteralPath $tabletGuide)) {
    @(
      '手寫板 → 即時批閱'
      '================'
      ''
      '1. 手寫板／平板寫完後，把圖檔或 PDF 存到「手寫匯入」資料夾'
      '   （也可在程式裡改成你的 OneNote／繪圖軟體匯出資料夾）'
      '2. 左側選好座號，按「手寫板匯入並批」'
      '3. 檔案會改名複製到「練習回傳」（如 05-R02.jpg），並複製 Cursor 批閱提示'
      '4. 到 Cursor 貼上並附檔 → 把回饋貼回「練習回傳循環」→ 產下一輪練習'
      ''
      '提示：檔名若已是 05-R01.jpg 會直接沿用；否則依目前座號自動編次數。'
    ) | Set-Content -LiteralPath $tabletGuide -Encoding UTF8
  }
  $hwGuide = Join-Path $root '手寫辨識加強說明.txt'
  if (-not (Test-Path -LiteralPath $hwGuide)) {
    @(
      '手寫難辨時怎麼批'
      '================'
      ''
      '1. 檔名請改成座號，試發用 00.pdf／00.jpg（不要用 S__44097539 這種 LINE 檔名）'
      '2. 批閱方式選「請 Gemini 自動批閱（API）」＝真正自動；「網頁批閱」仍要手動貼'
      '3. 首次按「Gemini金鑰」到 aistudio.google.com/apikey 貼上 key'
      '4. AI 會先給「手寫轉譯稿」＋「認知輸入清單」；看不清處標 ?'
      '5. 你把看懂的字寫進「認知輸入」：例如 05-Q3.txt 內容寫該題正確轉譯'
      '6. 仍看不清 → 請學生重謄該題，放到「重謄補充」：05-Q3.pdf'
      '7. 按「套用認知／重謄並重產PDF」'
      ''
      '拍照技巧：光線均勻、避免陰影、一次一頁、手機橫拍對齊紙邊、必要時分題特寫。'
    ) | Set-Content -LiteralPath $hwGuide -Encoding UTF8
  }
  $cogSample = Join-Path (Join-Path $root '認知輸入') '範例-05-Q3.txt'
  if (-not (Test-Path -LiteralPath $cogSample)) {
    @(
      '（範例）座號 05 第 3 題手寫轉譯'
      '原式：2/3 + 1/6 = 5/6'
      '說明：個位的 5 原先掃描像 S，老師確認是 5。'
    ) | Set-Content -LiteralPath $cogSample -Encoding UTF8
  }
  $readme = Join-Path $root '說明.txt'
  @(
    '全班試卷批改（一人一檔 → 個人 PDF 註記）'
    ''
    '1. 標準答案 →「標準答案」'
    '2. 每位學生試卷一個檔 →「輸入」（試發用 00.pdf／00.jpg；勿用 LINE 亂碼檔名）'
    '3. 批改後「輸出」會有：05-註記.md、05-批閱註記.pdf、05-試卷含批閱.pdf'
    '4. 練習題由 Cursor 自產（指導＋題＋解答＋影片）→「數位練習」'
    '5. 手寫太差：選「手寫加強批閱」→ 見「手寫辨識加強說明.txt」'
    '6. 回傳／手寫板：圖檔進「練習回傳」或「手寫匯入」→「手寫板匯入並批」'
    '7. 歷程在「練習歷程」；沒裝置才用「列印專用」'
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
  if ($JunyiList) { $argList += '--junyi-list' }
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
  # 常見：座號-試卷、00-R01、掃描_05
  if ($base -match '(?:^|[^\d])(\d{1,3})(?:[^\d]|$)') { return $Matches[1].PadLeft(2, '0') }
  return $base
}

function Test-InputExtension([string]$ext) {
  if ([string]::IsNullOrWhiteSpace($ext)) { return $false }
  $e = $ext.TrimStart('.').ToLowerInvariant()
  return @('pdf','png','jpg','jpeg','tif','tiff','bmp','heic','heif','webp','gif') -contains $e
}

function Get-InputFiles([string]$root) {
  $dir = Join-Path $root '輸入'
  if (-not (Test-Path -LiteralPath $dir)) { return @() }
  Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
    Where-Object { Test-InputExtension $_.Extension } |
    Sort-Object Name
}

function Get-InputSkipped([string]$root) {
  $dir = Join-Path $root '輸入'
  if (-not (Test-Path -LiteralPath $dir)) { return @() }
  Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-InputExtension $_.Extension) } |
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
說明：已掌握本單元。A 少練；重心 B、C。禁止整份只改數字。不使用均一；練習／指導／影片由此產生。

#### 自學指導（先看再做）
- 重點觀念：________
- 解題步驟口訣：________
- 易錯提醒：________

#### 建議影片／學習連結（1～2 個）
- 搜尋關鍵詞：________
- 連結：https://www.youtube.com/results?search_query=________
- 備用關鍵詞：________

#### 練習題（先做完再看解答）
【A 鞏固｜少而精】
1. …
【B 靈活】
2. …
3. …
【C 再提升｜必做】
4. …
5. …
6. …
【D 超前伸展｜選做】
7. …

---
#### 解答（全部題目完成後再看）
1. …
2. …
3. …
4. …
5. …
6. …
7. …
提升小提示：挑戰題做完寫「我多學到什麼」。
"@
    }
    '略落後' {
      return @"
### 程度：略落後｜目標：跟上本單元
先復習：________（本單元核心觀念）
不使用均一；練習／指導／影片由此產生。

#### 自學指導（先看再做）
- 先搞懂：________
- 步驟：1) … 2) … 3) …
- 做完自問：________

#### 建議影片／學習連結
- 搜尋關鍵詞：________
- 連結：https://www.youtube.com/results?search_query=________

#### 練習題（先做完再看解答）
【A 關鍵基本】
1. …
2. …
3. …
【B 對應錯題類型】
4. …
5. …

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
原則：每次只補 1 個小洞、題數 ≤ 3；做對就停，隔日再補。
本次只補：________
不使用均一；練習／指導／影片由此自動產生。

#### 自學指導（短、好懂）
- 今天只要會：________
- 跟著做：第一步… → 第二步… → 第三步…
- 做對的樣子：（簡短示範）

#### 建議影片／學習連結（對準本次這 1 點）
- 搜尋關鍵詞：________（年級＋單元＋教學）
- 連結：https://www.youtube.com/results?search_query=________
- 看片重點：________（不必整部）

#### 練習題（≤3 題）
【A 本次小洞｜求做對有成就】
1. …
2. …
【B 極簡銜接｜選做】
3. …

---
#### 解答（逐步寫）
1. …
2. …
3. …
說明：本次成功＝有成就；其餘下次再補。
"@
    }
    '需補先備' {
      return @"
### 程度：需補先備｜目標：分次回到起點（多次補齊）
本次只補：________（1 個觀念）
尚未補、下次再補：________
不使用均一；練習／指導／影片由此產生。

#### 自學指導
- 先回到：________
- 超短步驟：________
- 不會就先看影片再做 1～2 題

#### 建議影片／學習連結（先備觀念）
- 搜尋關鍵詞：________
- 連結：https://www.youtube.com/results?search_query=________

#### 練習題（≤3 題）
1. …
2. …
3. （選做）

---
#### 解答
1. …
2. …
3. …
建議：與導師協調；家長說明「多次小補」。
"@
    }
    default {
      return @"
### 程度：待判定
#### 自學指導
- …
#### 建議影片／學習連結
- 搜尋關鍵詞：…
- 連結：https://www.youtube.com/results?search_query=…
#### 練習題（先做完再看解答）
1. …
---
#### 解答（全部題目完成後再看）
1. …
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

function Get-GeminiKeyPath([string]$root) {
  Join-Path $root 'gemini-api-key.txt'
}

function Normalize-GeminiApiKey([string]$key) {
  if ([string]::IsNullOrWhiteSpace($key)) { return '' }
  $k = $key.Trim()
  $k = $k -replace '[\u200B-\u200D\uFEFF]', ''
  $k = ($k -split "`r|`n")[0].Trim()
  if ($k -match '^(?i)Bearer\s+(.+)$') { $k = $Matches[1].Trim() }
  $k = $k.Trim('"', "'", ' ', "`t")
  return $k
}

function Get-GeminiApiKey([string]$root) {
  $p = Get-GeminiKeyPath $root
  if (-not (Test-Path -LiteralPath $p)) { return '' }
  try {
    $k = Normalize-GeminiApiKey ((Get-Content -LiteralPath $p -Encoding UTF8 -Raw))
    if ($k -match '^\s*#') { return '' }
    return $k
  } catch { return '' }
}

function Save-GeminiApiKey([string]$root, [string]$key) {
  $p = Get-GeminiKeyPath $root
  $k = Normalize-GeminiApiKey $key
  $utf8 = New-Object System.Text.UTF8Encoding $true
  [IO.File]::WriteAllText($p, ($k + "`r`n"), $utf8)
}

function Test-GeminiApiKey([string]$ApiKey) {
  $k = Normalize-GeminiApiKey $ApiKey
  if ([string]::IsNullOrWhiteSpace($k)) { throw '金鑰空白' }
  if ($k.Length -lt 20) { throw '金鑰太短，可能貼不完整。請重新從 aistudio.google.com/apikey 複製整串。' }
  if ($k -notmatch '^AIza') {
    throw '這不像 Google AI Studio 的 API 金鑰（通常以 AIza 開頭）。請勿貼 Gemini 網頁／訂閱相關文字。'
  }
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $uri = "https://generativelanguage.googleapis.com/v1beta/models?key=$k&pageSize=5"
  try {
    $resp = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 30
  } catch {
    $msg = [string]$_.Exception.Message
    try { if ($_.Exception.InnerException) { $msg += ' | ' + $_.Exception.InnerException.Message } } catch {}
    if ($msg -match '401|403|PERMISSION|API[_ ]?key|UNAUTHENTICATED|INVALID.*key|金鑰') {
      throw ("金鑰無效或未開通。請到 aistudio.google.com/apikey 新建一把，整串複製後再貼。`n原始：$msg")
    }
    if ($msg -match '503|429|Unavailable|無法使用') {
      throw ("Google 暫時忙碌（503／429）。金鑰格式可接受，請等 1～2 分鐘再測。`n原始：$msg")
    }
    throw ("測試金鑰失敗：$msg")
  }
  $names = @()
  try {
    foreach ($m in $resp.models) {
      if ($m.name) { $names += ([string]$m.name -replace '^models/', '') }
    }
  } catch {}
  if ($names.Count -eq 0) {
    throw '金鑰能連上，但列不出模型。請確認此 Google 帳號已開通 Gemini API。'
  }
  return [pscustomobject]@{
    Ok = $true
    ModelCount = $names.Count
    Sample = ($names | Select-Object -First 3) -join ', '
  }
}

function Get-FileMimeType([string]$path) {
  $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
  switch ($ext) {
    '.png' { return 'image/png' }
    '.jpg' { return 'image/jpeg' }
    '.jpeg' { return 'image/jpeg' }
    '.gif' { return 'image/gif' }
    '.webp' { return 'image/webp' }
    '.bmp' { return 'image/bmp' }
    '.tif' { return 'image/tiff' }
    '.tiff' { return 'image/tiff' }
    '.heic' { return 'image/heic' }
    '.heif' { return 'image/heif' }
    '.pdf' { return 'application/pdf' }
    '.txt' { return 'text/plain' }
    '.md' { return 'text/plain' }
    default { return 'application/octet-stream' }
  }
}

function New-GeminiInlinePart([string]$path) {
  $mime = Get-FileMimeType $path
  $bytes = [IO.File]::ReadAllBytes($path)
  if ($bytes.Length -gt 18MB) {
    throw "檔案太大（$([IO.Path]::GetFileName($path))），請先壓縮或改拍清晰照片（建議 < 15MB）"
  }
  if ($mime -eq 'text/plain') {
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    return @{ text = ("【檔案：$([IO.Path]::GetFileName($path))】`n" + $text) }
  }
  return @{
    inline_data = @{
      mime_type = $mime
      data = [Convert]::ToBase64String($bytes)
    }
  }
}

function Invoke-GeminiGenerateContent {
  param(
    [string]$ApiKey,
    [string]$Model,
    [string]$Prompt,
    [string[]]$FilePaths
  )
  if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw '尚未設定 Gemini API 金鑰' }
  # 預設務必用仍上線的模型（2.0-flash 已於 2026-06-01 下線 → 404）
  if ([string]::IsNullOrWhiteSpace($Model) -or $Model -match 'gemini-2\.0|gemini-1\.5') {
    $Model = 'gemini-2.5-flash'
  }

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $parts = New-Object System.Collections.ArrayList
  [void]$parts.Add(@{ text = $Prompt })
  foreach ($fp in $FilePaths) {
    if (-not (Test-Path -LiteralPath $fp)) { continue }
    [void]$parts.Add((New-GeminiInlinePart $fp))
  }

  $payload = @{
    contents = @(
      @{
        role = 'user'
        parts = @($parts.ToArray())
      }
    )
    generationConfig = @{
      temperature = 0.2
    }
  }

  Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
  $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
  $ser.MaxJsonLength = [int]::MaxValue
  $json = $ser.Serialize($payload)
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)

  # 依序嘗試；跳過已下線／404 的模型
  $models = @(
    $Model,
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
    'gemini-2.5-pro'
  ) | Where-Object { $_ -and $_ -notmatch 'gemini-2\.0' } | Select-Object -Unique
  $tried = New-Object System.Collections.ArrayList
  $lastErr = $null
  foreach ($m in $models) {
    [void]$tried.Add($m)
    $uri = "https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=$ApiKey"
    $attempt = 0
    $maxAttempt = 3
    while ($attempt -lt $maxAttempt) {
      $attempt++
      try {
        $resp = Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 180
        $text = ''
        try {
          foreach ($c in $resp.candidates) {
            foreach ($p in $c.content.parts) {
              if ($p.text) { $text += [string]$p.text }
            }
          }
        } catch {}
        if ([string]::IsNullOrWhiteSpace($text)) {
          throw ("Gemini 沒有回傳文字（model=$m）。原始：" + ($resp | ConvertTo-Json -Depth 6 -Compress))
        }
        return [pscustomobject]@{ Text = $text; Model = $m }
      } catch {
        $lastErr = $_
        $msg = [string]$_.Exception.Message
        try {
          if ($_.Exception.InnerException) { $msg += ' | ' + $_.Exception.InnerException.Message }
        } catch {}
        if ($msg -match '404|not found|NOT_FOUND|找不到|is not found|not supported|was not found') { break }
        if ($msg -match 'API[_ ]?key|PERMISSION|401|403|INVALID_ARGUMENT.*key|金鑰') {
          throw ("Gemini 金鑰無效或未開通。請按「Gemini金鑰」到 aistudio.google.com/apikey 重建。`n原始：" + $msg)
        }
        # 503／429／忙碌：同模型重試，再換下一個模型
        if ($msg -match '503|429|Unavailable|無法使用|RESOURCE_EXHAUSTED|quota|rate|過載|暫時') {
          if ($attempt -lt $maxAttempt) {
            Start-Sleep -Seconds (2 * $attempt)
            continue
          }
          break
        }
        if ($msg -match 'INVALID_ARGUMENT|unsupported|FAILED_PRECONDITION|400') { break }
        throw
      }
    }
  }
  $hint = "已嘗試模型：$([string]::Join(', ', $tried.ToArray()))`n若出現 503，多半是 Google 暫時忙碌，等 1～2 分鐘再按「Gemini自動批」。`n請用 gemini-2.5-flash（2.0-flash 已下線會 404）。"
  if ($lastErr) { throw (($lastErr.Exception.Message) + "`n`n" + $hint) }
  throw $hint
}

function Apply-GeminiReplyToForm([string]$text) {
  $txtDiagnosis.Text = $text
  $txtSummary.Text = '（Gemini 自動批閱完成，詳見診斷欄／輸出資料夾）'
  if ($text -match '(?m)^1\)[\s\S]*?(?=^2\)|\z)') {
    $txtItems.Text = $Matches[0].Trim()
  } elseif ($text -match '(?m)(^\d+\s*[✓✗?xX].*)$') {
    # keep default if no clear list
  }
  if ($text -match '程度[：:\s]*(跟上|略落後|明顯落後|需補先備|待判定)') {
    $lv = $Matches[1]
    $idx = $cmbLevel.Items.IndexOf($lv)
    if ($idx -ge 0) { $cmbLevel.SelectedIndex = $idx }
  }
  if ($text -match '總評[：:\s]*(全對|多對|混雜|多錯|看不懂為主)') {
    $ov = $Matches[1]
    $idx = $cmbOverall.Items.IndexOf($ov)
    if ($idx -ge 0) { $cmbOverall.SelectedIndex = $idx }
  } elseif ($text -match '完全正確|全對|100\s*分') {
    $idx = $cmbOverall.Items.IndexOf('全對')
    if ($idx -ge 0) { $cmbOverall.SelectedIndex = $idx }
    $idx2 = $cmbLevel.Items.IndexOf('跟上')
    if ($idx2 -ge 0) { $cmbLevel.SelectedIndex = $idx2 }
  }
  if ($text -match '(?s)6\)[\s\S]*') {
    $txtPractice.Text = $Matches[0].Trim()
  }
  if ($text -match '(?s)5\)[^\n]*\n([\s\S]*?)(?=6\)|\z)') {
    $txtAdvice.Text = $Matches[1].Trim()
  }
}

function Show-GeminiKeyDialog {
  $has = -not [string]::IsNullOrWhiteSpace((Get-GeminiApiKey $script:WorkDir))
  $dlg = New-Object System.Windows.Forms.Form
  $dlg.Text = '設定 Gemini API 金鑰'
  $dlg.Size = New-Object System.Drawing.Size(560, 300)
  $dlg.StartPosition = 'CenterParent'
  $dlg.Font = $font
  $lbl = New-Object System.Windows.Forms.Label
  $lbl.Location = New-Object System.Drawing.Point(12, 12)
  $lbl.Size = New-Object System.Drawing.Size(520, 88)
  $lbl.Text = "請到 https://aistudio.google.com/apikey 建立 API key（≠ Gemini 網頁訂閱）。`n整串複製後貼上（通常以 AIza 開頭）。存於本機 MathGrading\gemini-api-key.txt，不上傳 GitHub。`n換過金鑰後若批失敗：先按「測試金鑰」確認。`n目前：" + $(if ($has) { '已有金鑰（可覆蓋）' } else { '尚未設定' })
  $dlg.Controls.Add($lbl)
  $tb = New-Object System.Windows.Forms.TextBox
  $tb.Location = New-Object System.Drawing.Point(12, 108)
  $tb.Width = 520
  $tb.UseSystemPasswordChar = $true
  if ($has) { $tb.Text = Get-GeminiApiKey $script:WorkDir }
  $dlg.Controls.Add($tb)
  $btnTest = New-Object System.Windows.Forms.Button
  $btnTest.Text = '測試金鑰'
  $btnTest.Location = New-Object System.Drawing.Point(12, 150)
  $btnTest.Size = New-Object System.Drawing.Size(110, 32)
  $btnTest.Add_Click({
      try {
        $r = Test-GeminiApiKey $tb.Text
        [void][System.Windows.Forms.MessageBox]::Show(
          ("金鑰可用。`n可列出模型約 " + $r.ModelCount + " 個。`n例：" + $r.Sample),
          '測試成功'
        )
      } catch {
        [void][System.Windows.Forms.MessageBox]::Show([string]$_.Exception.Message, '測試失敗')
      }
    })
  $dlg.Controls.Add($btnTest)
  $btnOk = New-Object System.Windows.Forms.Button
  $btnOk.Text = '儲存'
  $btnOk.Location = New-Object System.Drawing.Point(320, 150)
  $btnOk.Size = New-Object System.Drawing.Size(100, 32)
  $btnOk.DialogResult = 'None'
  $btnOk.Add_Click({
      $k = Normalize-GeminiApiKey $tb.Text
      if ([string]::IsNullOrWhiteSpace($k)) {
        [void][System.Windows.Forms.MessageBox]::Show('金鑰空白，未儲存', '提示')
        return
      }
      try {
        $null = Test-GeminiApiKey $k
      } catch {
        $ask = [System.Windows.Forms.MessageBox]::Show(
          ("測試未通過：`n" + $_.Exception.Message + "`n`n仍要強制儲存嗎？（通常不建議）"),
          '金鑰測試',
          [System.Windows.Forms.MessageBoxButtons]::YesNo,
          [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($ask -ne [System.Windows.Forms.DialogResult]::Yes) { return }
      }
      Save-GeminiApiKey $script:WorkDir $k
      $script:settings | Add-Member -NotePropertyName geminiModel -NotePropertyValue 'gemini-2.5-flash' -Force
      Save-Settings $script:WorkDir $script:settings
      [void][System.Windows.Forms.MessageBox]::Show('已儲存 Gemini API 金鑰。可再按「Gemini自動批」。', '完成')
      $dlg.DialogResult = 'OK'
      $dlg.Close()
    })
  $dlg.Controls.Add($btnOk)
  $btnOpen = New-Object System.Windows.Forms.Button
  $btnOpen.Text = '開啟申請頁'
  $btnOpen.Location = New-Object System.Drawing.Point(140, 150)
  $btnOpen.Size = New-Object System.Drawing.Size(120, 32)
  $btnOpen.Add_Click({ Start-Process 'https://aistudio.google.com/apikey' })
  $dlg.Controls.Add($btnOpen)
  $btnCancel = New-Object System.Windows.Forms.Button
  $btnCancel.Text = '關閉'
  $btnCancel.Location = New-Object System.Drawing.Point(440, 150)
  $btnCancel.Size = New-Object System.Drawing.Size(90, 32)
  $btnCancel.DialogResult = 'Cancel'
  $dlg.Controls.Add($btnCancel)
  $dlg.CancelButton = $btnCancel
  return ($dlg.ShowDialog() -eq 'OK')
}

function Load-Settings([string]$root) {
  $p = Get-SettingsPath $root
  $defaults = [pscustomobject]@{
    mode = 'gemini_auto'
    answerHint = ''
    preferredSend = '未指定（日後再選）'
    preferredReturn = '未指定（日後再選）'
    tabletImportDir = ''
    geminiModel = 'gemini-2.5-flash'
    tools = [pscustomobject]@{
      line_group = $true
      line_dm    = $true
      classroom  = $true
      drive      = $true
      lms        = $true
      junyi      = $false
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
      if ($null -eq $s.PSObject.Properties['tabletImportDir']) {
        $s | Add-Member -NotePropertyName tabletImportDir -NotePropertyValue '' -Force
      }
      if ($null -eq $s.PSObject.Properties['geminiModel'] -or [string]::IsNullOrWhiteSpace([string]$s.geminiModel) -or [string]$s.geminiModel -match 'gemini-2\.0') {
        $s | Add-Member -NotePropertyName geminiModel -NotePropertyValue $defaults.geminiModel -Force
      }
      if ($null -eq $s.PSObject.Properties['mode'] -or [string]::IsNullOrWhiteSpace([string]$s.mode)) {
        $s | Add-Member -NotePropertyName mode -NotePropertyValue 'gemini_auto' -Force
      }
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
    [pscustomobject]@{ Id = 'junyi';      Title = '均一（可不用）'; Role = '選用'; Tip = '預設不用。改由 Cursor 自動產練習＋指導＋影片連結' }
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
        '・練習來源 → Cursor 自動產題＋指導＋影片連結（不用均一）'
        '・要長期整齊 → Classroom 或 雲端兩夾'
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

function Get-TabletImportDir([string]$root) {
  $custom = ''
  try { $custom = [string]$script:settings.tabletImportDir } catch {}
  if ($custom -and (Test-Path -LiteralPath $custom)) { return $custom }
  $def = Join-Path $root '手寫匯入'
  New-Item -ItemType Directory -Force -Path $def | Out-Null
  return $def
}

function Get-NextPracticeRound([string]$root, [string]$sid) {
  $used = New-Object 'System.Collections.Generic.HashSet[int]'
  $histPath = Join-Path (Join-Path $root '練習歷程') ($sid + '-歷程.json')
  if (Test-Path -LiteralPath $histPath) {
    try {
      $h = Get-Content -LiteralPath $histPath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($a in @($h.attempts)) {
        [void]$used.Add([int]$a.round)
      }
    } catch {}
  }
  $retDir = Join-Path $root '練習回傳'
  if (Test-Path -LiteralPath $retDir) {
    Get-ChildItem -LiteralPath $retDir -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match ('^' + $sid) } |
      ForEach-Object {
        if ($_.BaseName -match '[Rr]0*(\d+)') { [void]$used.Add([int]$Matches[1]) }
        elseif ($_.BaseName -match '第\s*(\d+)\s*次') { [void]$used.Add([int]$Matches[1]) }
      }
  }
  $n = 1
  while ($used.Contains($n)) { $n++ }
  return $n
}

function Import-TabletFileToReturn {
  param(
    [string]$Root,
    [string]$Sid,
    [System.IO.FileInfo]$SourceFile
  )
  $retDir = Join-Path $Root '練習回傳'
  New-Item -ItemType Directory -Force -Path $retDir | Out-Null
  $ext = $SourceFile.Extension.ToLowerInvariant()
  if ($ext -notmatch '\.(pdf|png|jpe?g|tif{1,2}|bmp|webp)$') {
    throw "不支援的檔案類型：$ext"
  }
  # If already named like 05-R01.jpg keep stem when seat matches
  $destName = $null
  if ($SourceFile.BaseName -match ('^' + $Sid + '([-_].*)?$')) {
    if ($SourceFile.BaseName -match '[Rr]0*\d+' -or $SourceFile.BaseName -match '第\s*\d+\s*次') {
      $destName = $SourceFile.Name
    }
  }
  if (-not $destName) {
    $rnd = Get-NextPracticeRound $Root $Sid
    $destName = ('{0}-R{1:D2}{2}' -f $Sid, $rnd, $ext)
  }
  $dest = Join-Path $retDir $destName
  if (Test-Path -LiteralPath $dest) {
    $rnd = Get-NextPracticeRound $Root $Sid
    $destName = ('{0}-R{1:D2}{2}' -f $Sid, $rnd, $ext)
    $dest = Join-Path $retDir $destName
  }
  Copy-Item -LiteralPath $SourceFile.FullName -Destination $dest -Force
  return (Get-Item -LiteralPath $dest)
}

function Show-TabletImportAndGrade {
  Ensure-WorkTree $script:WorkDir
  if (-not $script:current) {
    [void][System.Windows.Forms.MessageBox]::Show('請先在左側選一位學生（座號），再匯入手寫檔。', '手寫板')
    return
  }
  $sid = Get-StudentId $script:current.Name
  $importDir = Get-TabletImportDir $script:WorkDir

  $dlg = New-Object System.Windows.Forms.Form
  $dlg.Text = "手寫板匯入並批｜座號 $sid"
  $dlg.Size = New-Object System.Drawing.Size(640, 420)
  $dlg.StartPosition = 'CenterParent'
  $dlg.Font = $font

  $lbl = New-Object System.Windows.Forms.Label
  $lbl.Text = "把平板／手寫板匯出的圖或 PDF 放到下方資料夾後選檔，一鍵進「練習回傳」並複製 Cursor 批閱提示。"
  $lbl.Location = New-Object System.Drawing.Point(12, 10)
  $lbl.Size = New-Object System.Drawing.Size(600, 40)
  $dlg.Controls.Add($lbl)

  $lblDir = New-Object System.Windows.Forms.Label
  $lblDir.Text = '匯入資料夾：' + $importDir
  $lblDir.Location = New-Object System.Drawing.Point(12, 55)
  $lblDir.Size = New-Object System.Drawing.Size(480, 40)
  $dlg.Controls.Add($lblDir)

  $btnPickDir = New-Object System.Windows.Forms.Button
  $btnPickDir.Text = '改資料夾'
  $btnPickDir.Location = New-Object System.Drawing.Point(500, 55)
  $btnPickDir.Size = New-Object System.Drawing.Size(100, 28)
  $btnPickDir.Add_Click({
      $fb = New-Object System.Windows.Forms.FolderBrowserDialog
      $fb.SelectedPath = $importDir
      if ($fb.ShowDialog() -eq 'OK') {
        $script:settings | Add-Member -NotePropertyName tabletImportDir -NotePropertyValue $fb.SelectedPath -Force
        Save-Settings $script:WorkDir $script:settings
        $importDir = $fb.SelectedPath
        $lblDir.Text = '匯入資料夾：' + $importDir
        Refresh-TabletList
      }
    })
  $dlg.Controls.Add($btnPickDir)

  $listFiles = New-Object System.Windows.Forms.ListBox
  $listFiles.Location = New-Object System.Drawing.Point(12, 100)
  $listFiles.Size = New-Object System.Drawing.Size(590, 180)
  $dlg.Controls.Add($listFiles)

  function Refresh-TabletList {
    $listFiles.Items.Clear()
    if (-not (Test-Path -LiteralPath $importDir)) { return }
    $files = @(Get-ChildItem -LiteralPath $importDir -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -match '\.(pdf|png|jpe?g|tif{1,2}|bmp|webp)$' } |
      Sort-Object LastWriteTime -Descending)
    foreach ($f in $files) {
      [void]$listFiles.Items.Add(('{0} ｜ {1}' -f $f.Name, $f.LastWriteTime.ToString('MM-dd HH:mm')))
    }
    if ($listFiles.Items.Count -gt 0) { $listFiles.SelectedIndex = 0 }
  }
  Refresh-TabletList

  $btnOpenDir = New-Object System.Windows.Forms.Button
  $btnOpenDir.Text = '開匯入夾'
  $btnOpenDir.Location = New-Object System.Drawing.Point(12, 295)
  $btnOpenDir.Size = New-Object System.Drawing.Size(100, 32)
  $btnOpenDir.Add_Click({ Start-Process explorer.exe $importDir; Start-Sleep -Milliseconds 400; Refresh-TabletList })
  $dlg.Controls.Add($btnOpenDir)

  $btnRefresh = New-Object System.Windows.Forms.Button
  $btnRefresh.Text = '重新整理'
  $btnRefresh.Location = New-Object System.Drawing.Point(120, 295)
  $btnRefresh.Size = New-Object System.Drawing.Size(100, 32)
  $btnRefresh.Add_Click({ Refresh-TabletList })
  $dlg.Controls.Add($btnRefresh)

  $btnGo = New-Object System.Windows.Forms.Button
  $btnGo.Text = '匯入並立即批閱'
  $btnGo.Location = New-Object System.Drawing.Point(280, 295)
  $btnGo.Size = New-Object System.Drawing.Size(160, 32)
  $btnGo.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 70)
  $btnGo.ForeColor = [System.Drawing.Color]::White
  $btnGo.FlatStyle = 'Flat'
  $btnGo.Add_Click({
      if ($listFiles.SelectedIndex -lt 0) {
        [void][System.Windows.Forms.MessageBox]::Show('請先選一個手寫檔（或把檔案存進匯入夾後按重新整理）', '手寫板')
        return
      }
      $files = @(Get-ChildItem -LiteralPath $importDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '\.(pdf|png|jpe?g|tif{1,2}|bmp|webp)$' } |
        Sort-Object LastWriteTime -Descending)
      if ($listFiles.SelectedIndex -ge $files.Count) { return }
      $src = $files[$listFiles.SelectedIndex]
      try {
        $dest = Import-TabletFileToReturn -Root $script:WorkDir -Sid $sid -SourceFile $src
      } catch {
        [void][System.Windows.Forms.MessageBox]::Show([string]$_.Exception.Message, '匯入失敗')
        return
      }
      $rnd = 1
      if ($dest.BaseName -match '[Rr]0*(\d+)') { $rnd = [int]$Matches[1] }
      $prompt = Build-ReturnCursorPrompt $script:WorkDir $sid $dest $rnd
      [System.Windows.Forms.Clipboard]::SetText($prompt)
      Start-Process -FilePath $dest.FullName
      $status.Text = "手寫已匯入：$($dest.Name)｜已複製 Cursor 批閱提示"
      $dlg.Close()
      [void][System.Windows.Forms.MessageBox]::Show(
        "已匯入練習回傳：$($dest.Name)`n`n已複製「批閱回傳」提示到剪貼簿，並開啟檔案。`n請到 Cursor 貼上並附檔。`n批完後打開「練習回傳循環」貼回分數／指導／下一輪練習。",
        '手寫板即時批閱'
      )
      Show-PracticeLoopDialog
    })
  $dlg.Controls.Add($btnGo)

  $btnCancel = New-Object System.Windows.Forms.Button
  $btnCancel.Text = '關閉'
  $btnCancel.Location = New-Object System.Drawing.Point(500, 295)
  $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
  $btnCancel.Add_Click({ $dlg.Close() })
  $dlg.Controls.Add($btnCancel)

  $hint2 = New-Object System.Windows.Forms.Label
  $hint2.Text = '也可把 OneNote／Whiteboard／繪圖軟體的預設匯出路徑設成「改資料夾」。'
  $hint2.Location = New-Object System.Drawing.Point(12, 340)
  $hint2.Size = New-Object System.Drawing.Size(600, 30)
  $dlg.Controls.Add($hint2)

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
  [void]$sb.AppendLine('每次回饋都要含：分數、問題點、進步說明、下一次練習（含自學指導＋建議影片連結或 YouTube 搜尋頁）。')
  [void]$sb.AppendLine('不要依賴均一指派；請直接自動產生練習題、逐步指導、合適教學影片連結／搜尋關鍵詞。')
  if (Test-IsBehindLevel $level) {
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('【落後生｜多次補齊 → 有成就 → 漸次跟上】')
    [void]$sb.AppendLine('- 回饋先寫做對／進步之處，再寫「下一次要補的那一小點」。')
    [void]$sb.AppendLine('- 一次只補 1 個洞、題數 ≤ 3；下一題只難一點點。')
    [void]$sb.AppendLine('- 「多次」是分日／分次小補；兩次之間宜隔開。')
    [void]$sb.AppendLine('- 階段小目標（約 60～70%）做對＝本次成功。')
    [void]$sb.AppendLine('- 必須附：自學指導（短步驟）＋ 1 個對準本次問題的影片搜尋連結（可用 youtube results?search_query=）。')
  } else {
    [void]$sb.AppendLine('目標：針對問題點給適切回饋並自動產下一輪練習；略落後建議本單元 ≤ 3 輪。')
  }
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('請輸出可直接貼回批改程式的欄位：')
  [void]$sb.AppendLine('1) 分數：得分/滿分')
  [void]$sb.AppendLine('2) 問題點')
  [void]$sb.AppendLine('3) 回饋說明（先成就再下一步）')
  [void]$sb.AppendLine('4) 是否達標：是／否')
  [void]$sb.AppendLine('5) 下一次練習全文：須含「自學指導」「建議影片／學習連結」「練習題」「解答」（題目與解答分段）')
  [void]$sb.AppendLine('6) 分數進步一句話＋本次成就一句話')
  [void]$sb.AppendLine('影片規則：優先給可點的 YouTube 搜尋結果連結；若有把握再給具體影片 URL；禁止捏造不存在的影片網址。')
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
  [void]$sb.AppendLine('每位學生輸出一份註記：題號註記、對錯摘要、診斷、程度、建議、自學練習（含自學指導＋建議影片＋練習題＋解答）。')
  [void]$sb.AppendLine('不要用均一指派；請直接自動產生練習題、指導步驟、合適網路教學影片連結或 YouTube 搜尋頁。')
  [void]$sb.AppendLine('跟上者：少鞏固、多再提升挑戰；好的學生要能再進步。')
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

function Build-CursorPromptOne([string]$root, $studentFile, [switch]$HandwritingHard) {
  $id = Get-StudentId $studentFile.Name
  $ansFiles = @(Get-AnswerFiles $root)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('請直接批閱這一位學生的數學試卷（一人一檔）。')
  if ($HandwritingHard) {
    [void]$sb.AppendLine('【手寫加強模式｜辨識優先】')
    [void]$sb.AppendLine('這份是手寫／掃描，字跡可能很差。請依下列強制規則：')
    [void]$sb.AppendLine('A. 先「逐格／逐位」判讀數字與運算符號；放大細節再決定。')
    [void]$sb.AppendLine('B. 只對「有把握」的內容判 ✓／✗；沒把握一律標 ?，禁止猜答案硬批。')
    [void]$sb.AppendLine('C. 每個 ? 必須寫：位置（第幾題／哪一行）、你看到的候選（例如 6 或 0）、為何不確定。')
    [void]$sb.AppendLine('D. 先輸出「手寫轉譯稿」：把看得懂的式子打成純文字；看不清處用【?】占位。')
    [void]$sb.AppendLine('E. 能批的題先批完；整題都看不清就整題 ?，不要整份放棄。')
    [void]$sb.AppendLine('F. 最後給「老師認知輸入清單」：要我補哪幾格文字／是否建議學生重謄。')
    [void]$sb.AppendLine('G. 程度判定：若 ? 太多，程度可寫「待判定」，並說明待認知後再定。')
  } else {
    if ($ansFiles.Count -gt 0) {
      [void]$sb.AppendLine('【模式｜對照正確答案】')
      [void]$sb.AppendLine('規則：必須以我一併提供的「正確答案」檔為批改依據；學生卷與答案不一致才可判 ✗。')
      [void]$sb.AppendLine('接受合理等價解法；看不懂標 ? 存疑（供我人工確認／重謄）。禁止忽略答案自行另立標準。')
    } else {
      [void]$sb.AppendLine('【模式｜直接 AI 批閱（無標準答案檔）】')
      [void]$sb.AppendLine('規則：未附正確答案檔；請依題意與數學正確性直接批改（合理等價解法給 ✓）。')
      [void]$sb.AppendLine('看不懂標 ? 存疑；字跡潦草寧可多標 ?，不要猜錯。')
    }
    [void]$sb.AppendLine('若字跡潦草：寧可多標 ?，不要猜錯；可先給看得懂題目的診斷與練習。')
  }
  [void]$sb.AppendLine('請務必輸出：')
  if ($HandwritingHard) {
    [void]$sb.AppendLine('0) 手寫轉譯稿（純文字式子＋【?】）')
    [void]$sb.AppendLine('0b) 老師認知輸入清單（題號／位置／候選字）')
  }
  [void]$sb.AppendLine('1) 題號註記（✓／✗／?；? 要附原因）')
  [void]$sb.AppendLine('2) 對錯摘要（分開：已確認／仍存疑）')
  [void]$sb.AppendLine('3) 個別診斷結果（弱點類型、是否跟得上進度；存疑多則待判定）')
  [void]$sb.AppendLine('4) 程度分級：跟上／略落後／明顯落後／需補先備／待判定')
  [void]$sb.AppendLine('5) 個別建議（短）')
  [void]$sb.AppendLine('6) 依程度自學練習（請一次寫完整，我會存成數位練習給學生）：')
  [void]$sb.AppendLine('   a. 自學指導：短步驟／口訣／易錯提醒')
  [void]$sb.AppendLine('   b. 建議影片／學習連結：給 1～2 個；優先 https://www.youtube.com/results?search_query=編碼後關鍵詞 ；有把握才給具體影片 URL；禁止捏造網址')
  [void]$sb.AppendLine('   c. 練習題（先全部列出）')
  [void]$sb.AppendLine('   d. 解答（全部放在題目之後另段）')
  [void]$sb.AppendLine('   - 跟上：少鞏固、多靈活＋再提升挑戰；禁止只改數字。')
  [void]$sb.AppendLine('   - 略落後：對應錯題，少而精。')
  [void]$sb.AppendLine('   - 明顯落後／需補先備：多次補齊（每次 1 點、≤3 題），先有成就再漸次跟上。')
  [void]$sb.AppendLine('   - 待判定：先給「已確認錯題」對應的少量練習；存疑題等我認知後再補。')
  [void]$sb.AppendLine('不要要求學生另上均一完成任務；練習與指導由此直接產生。')
  [void]$sb.AppendLine('格式方便我貼回批改程式／存成 輸出\' + $id + '-註記.md')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('座號：' + $id)
  if ($id -notmatch '^\d{2}$') {
    [void]$sb.AppendLine('（注意：檔名未含清楚座號，請老師核對真實座號；目前暫用：' + $id + '）')
  }
  [void]$sb.AppendLine('學生試卷：' + $studentFile.FullName)
  [void]$sb.AppendLine('正確答案檔：')
  if ($ansFiles.Count -eq 0) {
    [void]$sb.AppendLine(' （無｜採直接 AI 批閱）')
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
$form.Text = '數學習作批改（Gemini 自動批｜對照答案或直接 AI｜一人一檔）'
$form.Size = New-Object System.Drawing.Size(1060, 780)
$form.StartPosition = 'CenterScreen'
$form.Font = $font
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 248, 244)

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = 'Gemini 自動批：有正確答案就對照；沒有就直接 AI 批（都自動處理）'
$lbl.Font = $fontBig
$lbl.ForeColor = [System.Drawing.Color]::FromArgb(20, 70, 50)
$lbl.Location = New-Object System.Drawing.Point(16, 10)
$lbl.Size = New-Object System.Drawing.Size(960, 28)

# --- 開始區：答案＋模式 ---
$grpStart = New-Object System.Windows.Forms.GroupBox
$grpStart.Text = '① 開始：正確答案（可選）與批閱方式'
$grpStart.Location = New-Object System.Drawing.Point(16, 42)
$grpStart.Size = New-Object System.Drawing.Size(950, 88)

$lblAns = New-Object System.Windows.Forms.Label
$lblAns.Location = New-Object System.Drawing.Point(12, 28)
$lblAns.Size = New-Object System.Drawing.Size(700, 22)
$grpStart.Controls.Add($lblAns)

$cmbMode = New-Object System.Windows.Forms.ComboBox
$cmbMode.DropDownStyle = 'DropDownList'
$cmbMode.Items.AddRange(@(
    '自己對照批（開啟答案＋學生卷）',
    '請 Cursor 直接批閱（複製提示並開檔）',
    '請 Cursor 手寫加強批閱（難辨／潦草）',
    '請 Gemini 自動批閱（API＝真正自動）',
    '請 Gemini 自動手寫加強（API）',
    '請 Gemini 網頁批閱（要手動貼，非自動）',
    '請 Gemini 網頁手寫加強（要手動貼）'
  ))
$cmbMode.Location = New-Object System.Drawing.Point(12, 52)
$cmbMode.Size = New-Object System.Drawing.Size(480, 28)
# 預設：Gemini API 自動批閱（最後用 Gemini）
if (-not $script:settings.mode) { $script:settings.mode = 'gemini_auto' }
switch ($script:settings.mode) {
  'gemini_auto_hw' { $cmbMode.SelectedIndex = 4 }
  'gemini_auto' { $cmbMode.SelectedIndex = 3 }
  'gemini_hw' { $cmbMode.SelectedIndex = 6 }
  'gemini' { $cmbMode.SelectedIndex = 5 }
  'cursor_hw' { $cmbMode.SelectedIndex = 2 }
  'cursor' { $cmbMode.SelectedIndex = 1 }
  'manual' { $cmbMode.SelectedIndex = 0 }
  default { $cmbMode.SelectedIndex = 3 }
}
$grpStart.Controls.Add($cmbMode)

function Refresh-AnswerLabel {
  $files = @(Get-AnswerFiles $script:WorkDir)
  if ($files.Count -eq 0) {
    $lblAns.Text = '正確答案：尚未載入（可選｜沒有也能「直接 AI 批」）'
    $lblAns.ForeColor = [System.Drawing.Color]::FromArgb(120, 80, 20)
  } else {
    $names = ($files | ForEach-Object { $_.Name }) -join '、'
    $lblAns.Text = "正確答案：已載入 $($files.Count) 個｜對照批｜$names"
    $lblAns.ForeColor = [System.Drawing.Color]::FromArgb(20, 70, 50)
  }
}

$btnLoadAns = New-Object System.Windows.Forms.Button
$btnLoadAns.Text = '載入正確答案'
$btnLoadAns.Location = New-Object System.Drawing.Point(500, 48)
$btnLoadAns.Size = New-Object System.Drawing.Size(110, 32)
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

$btnGeminiKey = New-Object System.Windows.Forms.Button
$btnGeminiKey.Text = 'Gemini金鑰'
$btnGeminiKey.Location = New-Object System.Drawing.Point(620, 48)
$btnGeminiKey.Size = New-Object System.Drawing.Size(100, 32)
$btnGeminiKey.Add_Click({ [void](Show-GeminiKeyDialog) })
$grpStart.Controls.Add($btnGeminiKey)

$btnOpenAns = New-Object System.Windows.Forms.Button
$btnOpenAns.Text = '開啟答案'
$btnOpenAns.Location = New-Object System.Drawing.Point(730, 48)
$btnOpenAns.Size = New-Object System.Drawing.Size(90, 32)
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
$btnOpenAnsFolder.Text = '答案夾'
$btnOpenAnsFolder.Location = New-Object System.Drawing.Point(830, 48)
$btnOpenAnsFolder.Size = New-Object System.Drawing.Size(80, 32)
$btnOpenAnsFolder.Add_Click({ Start-Process explorer.exe (Join-Path $script:WorkDir '標準答案') })
$grpStart.Controls.Add($btnOpenAnsFolder)

$cmbMode.Add_SelectedIndexChanged({
    $mode = 'manual'
    switch ($cmbMode.SelectedIndex) {
      1 { $mode = 'cursor' }
      2 { $mode = 'cursor_hw' }
      3 { $mode = 'gemini_auto' }
      4 { $mode = 'gemini_auto_hw' }
      5 { $mode = 'gemini' }
      6 { $mode = 'gemini_hw' }
    }
    $script:settings | Add-Member -NotePropertyName mode -NotePropertyValue $mode -Force
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
$status.Text = '可載入正確答案（對照批）或直接按 Gemini 自動批（預設）'

$script:files = @()
$script:current = $null
# 連續自動批：成功後不跳確認窗，直接下一位
$script:SilentAutoContinue = $false
$script:AutoBatchDone = 0

function Refresh-PathLabel {
  $lblPath.Text = '工作資料夾：' + $script:WorkDir + '　　（輸入＝學生卷｜輸出＝註記PDF）'
}

function Ensure-AnswerOrWarn {
  param(
    # 自動批：答案可選；只提示是否要載入，選「否」仍可直接 AI 批
    [switch]$OfferForAuto
  )
  $files = @(Get-AnswerFiles $script:WorkDir)
  if ($files.Count -eq 0) {
    if ($OfferForAuto) {
      # 連續／靜默模式不打斷：直接 AI 批
      if ($script:SilentAutoContinue) { return $true }
      $ask = [System.Windows.Forms.MessageBox]::Show(
        "尚未載入正確答案。`n`n「是」＝現在載入（對照批）`n「否」＝直接用 Gemini AI 批（無答案檔）",
        '對照答案 或 直接 AI 批',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
      )
      if ($ask -ne 'Yes') { return $true }
      $ofd = New-Object System.Windows.Forms.OpenFileDialog
      $ofd.Title = '選擇正確答案（可多選）'
      $ofd.Filter = '答案檔|*.pdf;*.png;*.jpg;*.jpeg;*.txt;*.md|所有檔|*.*'
      $ofd.Multiselect = $true
      if ($ofd.ShowDialog() -ne 'OK') { return $true }
      $dest = Join-Path $script:WorkDir '標準答案'
      New-Item -ItemType Directory -Force -Path $dest | Out-Null
      foreach ($f in $ofd.FileNames) {
        Copy-Item -LiteralPath $f -Destination (Join-Path $dest ([IO.Path]::GetFileName($f))) -Force
      }
      Refresh-AnswerLabel
      return $true
    }
    $r = [System.Windows.Forms.MessageBox]::Show(
      "尚未載入正確答案。`n建議先載入以便比對；沒有也可繼續（自行對照／AI 直接批）。`n仍要繼續嗎？",
      '正確答案（可選）',
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
  $inDir = Join-Path $script:WorkDir '輸入'
  $skipped = @(Get-InputSkipped $script:WorkDir)
  $allCount = @(Get-ChildItem -LiteralPath $inDir -File -ErrorAction SilentlyContinue).Count
  if ($script:files.Count -eq 0 -and $allCount -gt 0) {
    $names = ($skipped | Select-Object -First 5 | ForEach-Object { $_.Name }) -join '、'
    $status.Text = ("輸入夾有 {0} 個檔，但副檔名不支援（需 pdf/png/jpg/heic…）。例：{1}" -f $allCount, $names)
    [void][System.Windows.Forms.MessageBox]::Show(
      ("「輸入」夾目前有 {0} 個檔，但程式認不到。`n`n請用：PDF、PNG、JPG、HEIC、WEBP。`n若是 Word／Pages／壓縮檔，請先匯出成 PDF 再放入。`n`n資料夾：`n{1}" -f $allCount, $inDir),
      '輸入檔未列入清單'
    )
  } elseif ($script:files.Count -eq 0) {
    $status.Text = ('輸入 0 人｜請把學生卷放入：' + $inDir)
  } else {
    $extra = if ($skipped.Count -gt 0) { "｜另有 $($skipped.Count) 個不支援副檔名未列入" } else { '' }
    $status.Text = ('輸入 {0} 人{1}｜{2}' -f $script:files.Count, $extra, $script:WorkDir)
  }
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
  # Gemini 自動批：答案可選；其他模式仍提醒
  $preIdx = $cmbMode.SelectedIndex
  $willGeminiAuto = ($preIdx -eq 3 -or $preIdx -eq 4)
  if ($willGeminiAuto) {
    if (-not (Ensure-AnswerOrWarn -OfferForAuto)) { return }
  } else {
    if (-not (Ensure-AnswerOrWarn)) { return }
  }

  $id = Get-StudentId $script:current.Name
  if ($id -notmatch '^\d{1,2}$' -or $script:current.Name -match '^S__') {
    $ask = [System.Windows.Forms.MessageBox]::Show(
      ("目前檔名像是通訊軟體亂碼（$($script:current.Name)），座號讀成「$id」，容易批不出來。`n`n要先改成座號檔名嗎？`n試發請用 00（例如 00.jpg）`n選「是」會請你輸入座號並改名。"),
      '請先改座號檔名',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($ask -eq 'Yes') {
      $formAsk = New-Object System.Windows.Forms.Form
      $formAsk.Text = '輸入座號（試發用 00）'
      $formAsk.Size = New-Object System.Drawing.Size(320, 140)
      $formAsk.StartPosition = 'CenterParent'
      $tb = New-Object System.Windows.Forms.TextBox
      $tb.Location = New-Object System.Drawing.Point(20, 20)
      $tb.Width = 260
      $tb.Text = '00'
      $formAsk.Controls.Add($tb)
      $ok = New-Object System.Windows.Forms.Button
      $ok.Text = '確定'
      $ok.Location = New-Object System.Drawing.Point(110, 60)
      $ok.DialogResult = 'OK'
      $formAsk.Controls.Add($ok)
      $formAsk.AcceptButton = $ok
      $dr = $formAsk.ShowDialog()
      $input = if ($dr -eq 'OK') { $tb.Text.Trim() } else { '' }
      if ($input -match '^\d{1,2}$') {
        $newId = $input.PadLeft(2, '0')
        $ext = $script:current.Extension
        $dest = Join-Path $script:current.DirectoryName ($newId + $ext)
        if (Test-Path -LiteralPath $dest) {
          [void][System.Windows.Forms.MessageBox]::Show("已存在 $newId$ext，請先換名或刪除舊檔。", '無法改名')
          return
        }
        Rename-Item -LiteralPath $script:current.FullName -NewName ($newId + $ext)
        Refresh-List
        $idx = 0
        foreach ($f in $script:files) {
          if ($f.Name -eq ($newId + $ext)) { $list.SelectedIndex = $idx; break }
          $idx++
        }
        if (-not $script:current) { return }
      } else {
        return
      }
    }
  }

  if ($cmbMode.SelectedIndex -ge 1) {
    # 1–2 Cursor 手動｜3–4 Gemini API 自動｜5–6 Gemini 網頁手動
    $idx = $cmbMode.SelectedIndex
    $useGeminiAuto = ($idx -eq 3 -or $idx -eq 4)
    $useGeminiWeb = ($idx -eq 5 -or $idx -eq 6)
    $useGemini = ($useGeminiAuto -or $useGeminiWeb)
    $hw = ($idx -eq 2 -or $idx -eq 4 -or $idx -eq 6)

    if (-not $hw -and -not $useGeminiAuto) {
      $sug = [System.Windows.Forms.MessageBox]::Show(
        "若剛剛批不出來／字跡很差，建議改用「手寫加強批閱」。`n`n現在改用加強模式嗎？",
        '批閱模式',
        [System.Windows.Forms.MessageBoxButtons]::YesNo
      )
      if ($sug -eq 'Yes') {
        if ($useGeminiWeb) { $cmbMode.SelectedIndex = 6 }
        else { $cmbMode.SelectedIndex = 2 }
        $hw = $true
        $idx = $cmbMode.SelectedIndex
      }
    }

    $ansList = @(Get-AnswerFiles $script:WorkDir)
    $hasAns = ($ansList.Count -gt 0)
    $p = Build-CursorPromptOne $script:WorkDir $script:current -HandwritingHard:$hw
    if ($useGemini) {
      if ($hasAns) {
        $p = ("【任務】你是數學老師助理，用 Google Gemini 自動批閱。`r`n" +
          "【模式】對照正確答案`r`n" +
          "【已附檔】1) 學生試卷 2) 正確答案（可能多檔）。`r`n" +
          "【必做】先看正確答案，再對學生卷逐題判 ✓／✗／?；以答案為準，等價解法可給 ✓。`r`n" +
          "【禁止】不要要我再貼檔；不要忽略正確答案自行出標準。`r`n`r`n") + $p
      } else {
        $p = ("【任務】你是數學老師助理，用 Google Gemini 自動批閱。`r`n" +
          "【模式】直接 AI 批閱（未附正確答案檔）`r`n" +
          "【已附檔】學生試卷。`r`n" +
          "【必做】依題意與數學正確性逐題判 ✓／✗／?；等價解法可給 ✓；看不清標 ?。`r`n" +
          "【禁止】不要要我再貼檔。`r`n`r`n") + $p
      }
    }

    if ($useGeminiAuto) {
      $key = Get-GeminiApiKey $script:WorkDir
      if ([string]::IsNullOrWhiteSpace($key)) {
        $ask = [System.Windows.Forms.MessageBox]::Show(
          "自動批閱需要 Gemini API 金鑰（與網頁 Pro 訂閱分開，到 AI Studio 免費申請）。`n`n現在設定嗎？",
          '需要 Gemini 金鑰',
          [System.Windows.Forms.MessageBoxButtons]::YesNo
        )
        if ($ask -ne 'Yes') { $script:SilentAutoContinue = $false; $script:AutoBatchDone = 0; return }
        if (-not (Show-GeminiKeyDialog)) { $script:SilentAutoContinue = $false; $script:AutoBatchDone = 0; return }
        $key = Get-GeminiApiKey $script:WorkDir
        if ([string]::IsNullOrWhiteSpace($key)) { $script:SilentAutoContinue = $false; $script:AutoBatchDone = 0; return }
      }

      $sid = Get-StudentId $script:current.Name
      $files = New-Object System.Collections.ArrayList
      [void]$files.Add($script:current.FullName)
      # 有正確答案就全部附上；沒有就純 AI 直接批
      foreach ($a in $ansList) {
        [void]$files.Add($a.FullName)
      }

      $modeLabel = if ($hasAns) { "對照答案 $($ansList.Count) 檔" } else { '直接 AI 批' }
      $status.Text = "Gemini 自動批閱中（座號 $sid｜$modeLabel）…"
      $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
      [System.Windows.Forms.Application]::DoEvents()
      try {
        $model = 'gemini-2.5-flash'
        try {
          if ($script:settings.geminiModel) {
            $cand = [string]$script:settings.geminiModel
            if ($cand -and $cand -notmatch 'gemini-2\.0|gemini-1\.5') { $model = $cand }
          }
        } catch {}
        $result = Invoke-GeminiGenerateContent -ApiKey $key -Model $model -Prompt $p -FilePaths @($files.ToArray())
        $text = [string]$result.Text
        Apply-GeminiReplyToForm $text
        $outDir = Join-Path $script:WorkDir '輸出'
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        $utf8 = New-Object System.Text.UTF8Encoding $true
        [IO.File]::WriteAllText((Join-Path $outDir ($sid + '-Gemini提示.txt')), $p, $utf8)
        [IO.File]::WriteAllText((Join-Path $outDir ($sid + '-Gemini回覆.md')), $text, $utf8)
        # 自動寫入註記並嘗試產 PDF（老師仍可再改）
        $saved = $false
        try { $saved = [bool](Save-Current) } catch { $saved = $false }
        if ($script:SilentAutoContinue) { $script:AutoBatchDone++ }
        $status.Text = "Gemini 已自動批完（$($result.Model)）｜$modeLabel｜座號 $sid｜註記已寫入"
        $extra = if ($saved) { "`n已自動輸出此生 PDF／註記。" } else { "`n請再按「輸出此生PDF」確認。" }

        if ($script:SilentAutoContinue) {
          # 連續模式：不跳確認，直接下一位未批
          $form.Cursor = [System.Windows.Forms.Cursors]::Default
          Select-NextUngraded -Quiet
          if ($script:current) {
            Start-GradeCurrent
          } else {
            $n = $script:AutoBatchDone
            $script:SilentAutoContinue = $false
            $script:AutoBatchDone = 0
            $status.Text = "連續自動批完成｜共 $n 份（Gemini）"
            [void][System.Windows.Forms.MessageBox]::Show(
              ("連續自動批完成。`n已用 Gemini 自動處理 $n 份。`n`n請抽查「輸出」夾的註記／PDF。"),
              '連續自動批完成'
            )
          }
        } else {
          $ansHint = if ($hasAns) { "答案檔：$($ansList.Count) 個｜對照批" } else { '模式：直接 AI 批（無答案檔）' }
          $next = [System.Windows.Forms.MessageBox]::Show(
            ("已自動批完座號 $sid（模型：$($result.Model)）。`n$ansHint`n回覆：輸出\$sid-Gemini回覆.md" + $extra + "`n`n要繼續自動批「下一位未批」嗎？"),
            'Gemini 自動批閱',
            [System.Windows.Forms.MessageBoxButtons]::YesNo
          )
          if ($next -eq 'Yes') {
            Select-NextUngraded -Quiet
            if ($script:current) { Start-GradeCurrent }
          }
        }
      } catch {
        $script:SilentAutoContinue = $false
        $script:AutoBatchDone = 0
        $status.Text = 'Gemini 自動批閱失敗'
        [void][System.Windows.Forms.MessageBox]::Show(
          ("自動批閱失敗：`n" + $_.Exception.Message + "`n`n請確認：Gemini 金鑰有效、網路正常。`n若是 503，等 1～2 分鐘再按一次「Gemini自動批」。"),
          '錯誤'
        )
      } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
      }
      return
    }

    [System.Windows.Forms.Clipboard]::SetText($p)
    try {
      $sid = Get-StudentId $script:current.Name
      $tag = if ($useGemini) { 'Gemini提示' } else { 'Cursor提示' }
      $promptPath = Join-Path (Join-Path $script:WorkDir '輸出') ($sid + '-' + $tag + '.txt')
      $utf8 = New-Object System.Text.UTF8Encoding $true
      [System.IO.File]::WriteAllText($promptPath, $p, $utf8)
    } catch {}
    Start-Process -FilePath $script:current.FullName
    $ans = @(Get-AnswerFiles $script:WorkDir)
    foreach ($a in $ans) { Start-Process -FilePath $a.FullName }
    if ($useGeminiWeb) {
      try { Start-Process 'https://gemini.google.com/app' } catch {}
      $toolName = 'Gemini'
      $step1 = "1. 已開啟 Gemini 網頁（若沒開請到 https://gemini.google.com/app）"
      $fileHint = "輸出\{座號}-Gemini提示.txt"
    } else {
      $toolName = 'Cursor'
      $step1 = '1. 開 Cursor 對話'
      $fileHint = "輸出\{座號}-Cursor提示.txt"
    }
    if ($hw) {
      $status.Text = "已複製「手寫加強」提示｜請到 ${toolName}：貼上＋附上學生卷圖檔"
      [void][System.Windows.Forms.MessageBox]::Show(
        ("【一定要做這 3 步，否則會批不出來】`n`n" + $step1 + "`n2. Ctrl+V 貼上提示（已在剪貼簿）`n3. 再把學生卷圖／PDF「附檔／上傳」加進去後送出`n`n只貼文字不附圖＝無法辨識手寫。`n`n提示也已存到 " + $fileHint + "`n`n想免手動貼檔：選「Gemini 自動批閱」並設定 API 金鑰。"),
        ("手寫加強批閱（$toolName）")
      )
    } else {
      $status.Text = "已複製 $toolName 提示｜請到 ${toolName}：貼上＋附檔"
      [void][System.Windows.Forms.MessageBox]::Show(
        ("【一定要做這 3 步】`n`n" + $step1 + "`n2. 貼上提示（Ctrl+V）`n3. 附上學生卷檔後送出`n`n想免手動貼檔：選「Gemini 自動批閱（API）」並按「Gemini金鑰」。"),
        ("請 $toolName 批閱")
      )
    }
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
  param([switch]$Quiet)
  Refresh-List
  for ($i = 0; $i -lt $script:files.Count; $i++) {
    $id = Get-StudentId $script:files[$i].Name
    $note = Get-NotePath $script:WorkDir $id
    if (-not (Test-Path -LiteralPath $note)) {
      $list.SelectedIndex = $i
      Load-Selected
      $status.Text = "下一位未批：座號 $id"
      return $true
    }
  }
  $script:current = $null
  if (-not $Quiet) {
    [void][System.Windows.Forms.MessageBox]::Show("全員都有註記了。`n可按「產生全班存疑清單」處理看不懂的地方。", '完成')
  }
  return $false
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
      switch ($script:settings.mode) {
        'gemini_auto_hw' { $cmbMode.SelectedIndex = 4 }
        'gemini_auto' { $cmbMode.SelectedIndex = 3 }
        'gemini_hw' { $cmbMode.SelectedIndex = 6 }
        'gemini' { $cmbMode.SelectedIndex = 5 }
        'cursor_hw' { $cmbMode.SelectedIndex = 2 }
        'cursor' { $cmbMode.SelectedIndex = 1 }
        default { $cmbMode.SelectedIndex = 0 }
      }
      Refresh-PathLabel
      Refresh-AnswerLabel
      Refresh-List
    }
  })

$btnOpenIn = New-Object System.Windows.Forms.Button
$btnOpenIn.Text = '輸入夾'
$btnOpenIn.Location = New-Object System.Drawing.Point(156, $y1)
$btnOpenIn.Size = New-Object System.Drawing.Size(90, 36)
$btnOpenIn.Add_Click({
  $inDir = Join-Path $script:WorkDir '輸入'
  New-Item -ItemType Directory -Force -Path $inDir | Out-Null
  Start-Process explorer.exe $inDir
  Start-Sleep -Milliseconds 500
  Refresh-List
})

$btnOpenOut = New-Object System.Windows.Forms.Button
$btnOpenOut.Text = '輸出夾'
$btnOpenOut.Location = New-Object System.Drawing.Point(256, $y1)
$btnOpenOut.Size = New-Object System.Drawing.Size(90, 36)
$btnOpenOut.Add_Click({ Start-Process explorer.exe (Join-Path $script:WorkDir '輸出') })

$btnGrade = New-Object System.Windows.Forms.Button
$btnGrade.Text = 'Gemini自動批'
$btnGrade.Location = New-Object System.Drawing.Point(356, $y1)
$btnGrade.Size = New-Object System.Drawing.Size(120, 36)
$btnGrade.BackColor = [System.Drawing.Color]::FromArgb(40, 90, 140)
$btnGrade.ForeColor = [System.Drawing.Color]::White
$btnGrade.FlatStyle = 'Flat'
$btnGrade.Add_Click({
  # 一鍵：強制 Gemini API 自動（有答案對照／無答案直接 AI）
  if ($cmbMode.SelectedIndex -lt 3 -or $cmbMode.SelectedIndex -gt 4) {
    $cmbMode.SelectedIndex = 3
  }
  Start-GradeCurrent
})

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
$btnNext.Size = New-Object System.Drawing.Size(100, 36)
$btnNext.Add_Click({ Select-NextUngraded })

$btnAutoAll = New-Object System.Windows.Forms.Button
$btnAutoAll.Text = '連續自動批'
$btnAutoAll.Location = New-Object System.Drawing.Point(736, $y1)
$btnAutoAll.Size = New-Object System.Drawing.Size(110, 36)
$btnAutoAll.BackColor = [System.Drawing.Color]::FromArgb(45, 106, 79)
$btnAutoAll.ForeColor = [System.Drawing.Color]::White
$btnAutoAll.FlatStyle = 'Flat'
$btnAutoAll.Add_Click({
  # Gemini API 連續自動批：有答案就對照，沒有就直接 AI
  $cmbMode.SelectedIndex = 3
  [void](Ensure-AnswerOrWarn -OfferForAuto)
  $key = Get-GeminiApiKey $script:WorkDir
  if ([string]::IsNullOrWhiteSpace($key)) {
    $askKey = [System.Windows.Forms.MessageBox]::Show(
      "連續自動批需要 Gemini API 金鑰。`n`n現在設定嗎？",
      '需要 Gemini 金鑰',
      [System.Windows.Forms.MessageBoxButtons]::YesNo
    )
    if ($askKey -ne 'Yes') { return }
    if (-not (Show-GeminiKeyDialog)) { return }
  }
  # 若目前這份已有註記，跳到下一位未批
  if ($script:current) {
    $curId = Get-StudentId $script:current.Name
    $curNote = Get-NotePath $script:WorkDir $curId
    if (Test-Path -LiteralPath $curNote) { [void](Select-NextUngraded -Quiet) }
  } else {
    [void](Select-NextUngraded -Quiet)
  }
  if (-not $script:current) {
    [void][System.Windows.Forms.MessageBox]::Show('沒有未批學生（請把試卷放入「輸入」夾）。', '提示')
    return
  }
  $ansN = @(Get-AnswerFiles $script:WorkDir).Count
  $modeHint = if ($ansN -gt 0) { "有正確答案 $ansN 檔 → 對照批" } else { '無正確答案 → 直接 AI 批' }
  $confirm = [System.Windows.Forms.MessageBox]::Show(
    ("將用 Gemini 連續自動批所有未批學生。`n$modeHint`n`n每份成功會自動存註記／PDF，再處理下一位。`n中途失敗會停下。`n`n開始？"),
    '連續自動批',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
  )
  if ($confirm -ne 'Yes') { return }
  $script:SilentAutoContinue = $true
  $script:AutoBatchDone = 0
  $status.Text = "連續自動批開始｜Gemini｜$modeHint"
  Start-GradeCurrent
})

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = '重新整理'
$btnRefresh.Location = New-Object System.Drawing.Point(856, $y1)
$btnRefresh.Size = New-Object System.Drawing.Size(90, 36)
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

$btnJunyi = New-Object System.Windows.Forms.Button
$btnJunyi.Text = '自產練習說明'
$btnJunyi.Location = New-Object System.Drawing.Point(516, $y4)
$btnJunyi.Size = New-Object System.Drawing.Size(130, 32)
$btnJunyi.BackColor = [System.Drawing.Color]::FromArgb(40, 100, 90)
$btnJunyi.ForeColor = [System.Drawing.Color]::White
$btnJunyi.FlatStyle = 'Flat'
$btnJunyi.Add_Click({
    Ensure-WorkTree $script:WorkDir
    $guide = Join-Path $script:WorkDir '自產練習與影片說明.txt'
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    $body = @(
      '自產練習與影片（不用均一）'
      '===================='
      ''
      '做法：'
      '1. 選「請 Cursor 直接批閱」→ Cursor 會自動產出：診斷、程度、自學指導、練習題、解答、建議影片連結／搜尋頁'
      '2. 貼回右側後按「輸出此生PDF」→「數位練習」會有手機可開的練習'
      '3. 回傳循環時，Cursor 同樣會依問題點再產「下一輪練習＋指導＋影片」'
      ''
      '影片規則：'
      '- 優先用 YouTube 搜尋結果頁（可點）：'
      '  https://www.youtube.com/results?search_query=年級+單元+教學'
      '- 有把握才貼具體影片網址；不要捏造連結'
      ''
      '發放：LINE 群公告＋個別傳練習檔；回傳圖檔到「練習回傳」'
      '均一：可完全不用。'
    ) -join "`r`n"
    [IO.File]::WriteAllText($guide, $body, $utf8Bom)
    Start-Process notepad.exe $guide
    $status.Text = '已開：自產練習與影片說明（不用均一）'
  })

$btnTablet = New-Object System.Windows.Forms.Button
$btnTablet.Text = '手寫板匯入並批'
$btnTablet.Location = New-Object System.Drawing.Point(656, $y4)
$btnTablet.Size = New-Object System.Drawing.Size(140, 32)
$btnTablet.BackColor = [System.Drawing.Color]::FromArgb(20, 90, 130)
$btnTablet.ForeColor = [System.Drawing.Color]::White
$btnTablet.FlatStyle = 'Flat'
$btnTablet.Add_Click({ Show-TabletImportAndGrade })

$form.Size = New-Object System.Drawing.Size(1000, 820)
$status.Location = New-Object System.Drawing.Point(16, 688)
$status.Size = New-Object System.Drawing.Size(950, 40)

$form.Controls.AddRange(@(
    $lbl, $grpStart, $lblPath, $list, $grp, $status,
    $btnWork, $btnOpenIn, $btnOpenOut, $btnGrade, $btnSave, $btnNext, $btnAutoAll, $btnRefresh,
    $btnCsv, $btnUnclear, $btnClarify, $btnOpenCog,
    $btnDigital, $btnCopyLine, $btnPrintPack, $btnOpenDigital,
    $btnTools, $btnLoop, $btnRetFolder, $btnJunyi, $btnTablet
  ))

Refresh-PathLabel
Refresh-AnswerLabel
Refresh-List
if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }

[void]$form.ShowDialog()
