#Requires -Version 5.1
<#
.SYNOPSIS
  清點 E:\：各第一層資料夾檔案數，並列出可能「看起來不見」的位置。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\inventory-e-drive.ps1
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [string]$ReportDir = ''
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

if ([string]::IsNullOrWhiteSpace($ReportDir)) {
  $ReportDir = Join-Path $DriveRoot '_清點報告'
}
if (-not (Test-Path -LiteralPath $ReportDir)) {
  New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$summaryPath = Join-Path $ReportDir ("inventory_summary_{0}.txt" -f $stamp)
$deepPath = Join-Path $ReportDir ("inventory_deep_sample_{0}.txt" -f $stamp)
$conflictPath = Join-Path $ReportDir ("inventory_conflict_{0}.txt" -f $stamp)

$skipTop = @('System Volume Information', '$RECYCLE.BIN', 'FOUND.000')
$lines = New-Object System.Collections.Generic.List[string]

function Add-Line([string]$s) {
  Write-Host $s
  $lines.Add($s) | Out-Null
}

Add-Line ("======== E:\ 清點 {0} ========" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Add-Line ''
Add-Line '--- 第一層資料夾／檔案 ---'

$tops = @(Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue |
  Where-Object { $skipTop -notcontains $_.Name })

foreach ($t in $tops) {
  if ($t.PSIsContainer) {
    $files = @(Get-ChildItem -LiteralPath $t.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
    $dirs = @(Get-ChildItem -LiteralPath $t.FullName -Recurse -Directory -Force -ErrorAction SilentlyContinue)
    $bytes = ($files | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $bytes) { $bytes = 0 }
    $gb = [math]::Round($bytes / 1GB, 2)
    Add-Line ("[DIR]  {0,-20} files={1,6} dirs={2,5} size={3} GB" -f $t.Name, $files.Count, $dirs.Count, $gb)
  } else {
    Add-Line ("[FILE] {0}" -f $t.Name)
  }
}

Add-Line ''
Add-Line '--- 特別檢查：搬移衝突／搬移日誌／回收相關 ---'
$specialNames = @('_搬移衝突', '搬移衝突', '_搬移日誌', '搬移日誌', '_已合併_', '_已清空_')
$specialHits = @(Get-ChildItem -LiteralPath $DriveRoot -Recurse -Force -ErrorAction SilentlyContinue |
  Where-Object {
    ($specialNames -contains $_.Name) -or ($_.Name -match '^_已合併_|^_已清空_')
  })

$conflictFiles = New-Object System.Collections.Generic.List[string]
foreach ($h in $specialHits) {
  if ($h.PSIsContainer) {
    $fc = @(Get-ChildItem -LiteralPath $h.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
    Add-Line ("{0}  files={1}" -f $h.FullName, $fc.Count)
    foreach ($f in $fc) {
      $conflictFiles.Add($f.FullName) | Out-Null
    }
  } else {
    Add-Line $h.FullName
    $conflictFiles.Add($h.FullName) | Out-Null
  }
}

Add-Line ''
Add-Line '--- 關鍵字抽樣（私人／學校／超級生命密碼／備份）---'
$kw = '超級生命密碼|生命密碼|天圓|弟子規|鳴馨|太陽盛德|學校|學年|試題'
$sampleRoots = @(
  (Join-Path $DriveRoot '私人'),
  (Join-Path $DriveRoot '學校'),
  (Join-Path $DriveRoot '超級生命密碼')
) | Where-Object { Test-Path -LiteralPath $_ }

$deepLines = New-Object System.Collections.Generic.List[string]
foreach ($r in $sampleRoots) {
  $hits = @(Get-ChildItem -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $kw } |
    Select-Object -First 200)
  $deepLines.Add(("ROOT {0} keywordHits(sample up to 200)={1}" -f $r, $hits.Count)) | Out-Null
  foreach ($x in $hits) {
    $deepLines.Add($x.FullName) | Out-Null
  }
}

# 備份深處也抽樣
$backup = Join-Path (Join-Path $DriveRoot '私人') '備份'
if (Test-Path -LiteralPath $backup) {
  $bh = @(Get-ChildItem -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $kw } |
    Select-Object -First 200)
  $deepLines.Add(("ROOT {0} keywordHits(sample up to 200)={1}" -f $backup, $bh.Count)) | Out-Null
  foreach ($x in $bh) { $deepLines.Add($x.FullName) | Out-Null }
}

$lines | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$deepLines | Set-Content -LiteralPath $deepPath -Encoding UTF8
$conflictFiles | Set-Content -LiteralPath $conflictPath -Encoding UTF8

Add-Line ''
Add-Line ("報告已寫入: {0}" -f $ReportDir)
Add-Line ("  {0}" -f $summaryPath)
Add-Line ("  {0}" -f $deepPath)
Add-Line ("  {0}" -f $conflictPath)
Add-Line ''
Add-Line '若某區 files 很大，檔案多半還在，只是被搬進子資料夾或 _搬移衝突。'
Add-Line '下一步可跑: reclassify-misplaced-on-e.ps1（預覽後再 -Execute）'
