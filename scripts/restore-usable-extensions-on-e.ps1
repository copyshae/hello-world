#Requires -Version 5.1
<#
.SYNOPSIS
  檢視 E:\ 全部檔案，把「被改壞、無法正常開啟」的檔名恢復成正確副檔名（預設 Dry-run）。

.DESCRIPTION
  常見壞名：
    報告.xls_fromE_20260809160544254     → 報告.xls
    圖.jpg_fromPrivate_20260809160542543 → 圖.jpg
    簡報_fromE_20260809123456789.pptx    → 簡報.pptx
    檔案.xls_衝突_20260809123456789      → 檔案.xls

  - 掃描整個 E:\（略過系統／回收桶）
  - 不刪檔；目的同名則加 _2、_3
  - 預設 Dry-run；加 -Execute 才 Rename-Item

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\restore-usable-extensions-on-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\restore-usable-extensions-on-e.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

$skipSegRe = '^(System Volume Information|\$RECYCLE\.BIN|FOUND\.\d+)$'

# 常見可用副檔名（小寫比對）
$knownExt = @(
  '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.odt', '.ods', '.odp',
  '.txt', '.rtf', '.csv', '.tsv', '.md', '.json', '.xml', '.html', '.htm', '.css', '.js',
  '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tif', '.tiff', '.webp', '.heic', '.svg', '.ico',
  '.mp3', '.wav', '.flac', '.aac', '.m4a', '.wma', '.ogg',
  '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.mpeg', '.mpg', '.3gp',
  '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.iso',
  '.lnk', '.url', '.exe', '.msi', '.bat', '.cmd', '.ps1', '.vbs',
  '.dwg', '.dxf', '.vsd', '.vsdx', '.pub', '.one', '.msg', '.eml',
  '.pages', '.numbers', '.key', '.epub', '.mobi',
  '.ai', '.psd', '.indd', '.sketch'
)

function Test-UnderSkipped([string]$full) {
  foreach ($seg in ($full -split '[\\/]')) {
    if ($seg -match $skipSegRe) { return $true }
  }
  return $false
}

function Get-UniqueName([string]$dir, [string]$fileName) {
  $dest = Join-Path -Path $dir -ChildPath $fileName
  if (-not (Test-Path -LiteralPath $dest)) { return $fileName }
  $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
  $ext = [System.IO.Path]::GetExtension($fileName)
  if ([string]::IsNullOrWhiteSpace($base)) { $base = '未命名' }
  for ($i = 2; $i -le 999; $i++) {
    $candidate = '{0}_{1}{2}' -f $base, $i, $ext
    if (-not (Test-Path -LiteralPath (Join-Path -Path $dir -ChildPath $candidate))) { return $candidate }
  }
  throw "無法產生唯一檔名: $fileName"
}

function Repair-FileName([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) { return $null }

  $original = $name
  $repaired = $null

  # A) name.ext_fromE_數字 / name.ext_fromPrivate_數字 / name.ext_衝突_數字
  if ($name -match '(?i)^(.+?)(\.[A-Za-z0-9]{1,16})([_-](?:from[A-Za-z]+|衝突)[_-]?\d+)\s*$') {
    $candidateExt = $Matches[2].ToLowerInvariant()
    if ($knownExt -contains $candidateExt) {
      $repaired = $Matches[1] + $Matches[2]
    }
  }

  # B) name_fromE_數字.ext / name_衝突_數字.ext
  if ($null -eq $repaired -and $name -match '(?i)^(.+?)([_-](?:from[A-Za-z]+|衝突)[_-]?\d+)(\.[A-Za-z0-9]{1,16})\s*$') {
    $candidateExt = $Matches[3].ToLowerInvariant()
    if ($knownExt -contains $candidateExt) {
      $repaired = $Matches[1] + $Matches[3]
    } else {
      # 副檔名不在清單仍保留（例如 .vsdx 已在清單；未知則仍試著還原）
      $repaired = $Matches[1] + $Matches[3]
    }
  }

  # C) Windows 把副檔名吃成 .xls_fromE_123 → Extension 很長
  if ($null -eq $repaired) {
    $ext = [System.IO.Path]::GetExtension($name)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
    if ($ext -match '(?i)^(\.[A-Za-z0-9]{1,16})([_-](?:from[A-Za-z]+|衝突).+)$') {
      $realExt = $Matches[1]
      if ($knownExt -contains $realExt.ToLowerInvariant()) {
        $repaired = $base + $realExt
      }
    }
  }

  # D) 僅有 _fromE_／_衝突_ 尾巴、前面已含已知副檔名
  if ($null -eq $repaired -and $name -match '(?i)([_-](?:from[A-Za-z]+|衝突))') {
    $stripped = $name -replace '(?i)([_-](?:from[A-Za-z]+|衝突)[_-]?[0-9]*)+\s*$', ''
    $stripped = $stripped.TrimEnd('_', '-', ' ')
    if (-not [string]::IsNullOrWhiteSpace($stripped) -and $stripped -ne $name) {
      # 確認還原後有可用副檔名，或原本壞名裡藏著副檔名
      $ext2 = [System.IO.Path]::GetExtension($stripped)
      if ($knownExt -contains $ext2.ToLowerInvariant()) {
        $repaired = $stripped
      } elseif ($name -match '(?i)(\.[A-Za-z0-9]{1,16})([_-](?:from[A-Za-z]+|衝突))') {
        # 從原名抓第一個已知副檔名位置
        $m = [regex]::Match($name, '(?i)^(.+?)(\.[A-Za-z0-9]{1,16})([_-](?:from[A-Za-z]+|衝突).+)$')
        if ($m.Success -and ($knownExt -contains $m.Groups[2].Value.ToLowerInvariant())) {
          $repaired = $m.Groups[1].Value + $m.Groups[2].Value
        }
      }
    }
  }

  if ($null -eq $repaired) { return $null }
  if ($repaired -eq $original) { return $null }
  if ([string]::IsNullOrWhiteSpace($repaired)) { return $null }

  # 最終副檔名必須是已知類型，避免改成更糟
  $finalExt = [System.IO.Path]::GetExtension($repaired)
  if ([string]::IsNullOrWhiteSpace($finalExt)) { return $null }
  if ($knownExt -notcontains $finalExt.ToLowerInvariant()) { return $null }

  return $repaired
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的改名）' })))
Write-Host ("DriveRoot: {0}" -f $DriveRoot)
Write-Host '規則: 去掉檔名中 _fromE_／_fromPrivate_／_衝突_ 等尾巴，恢復正確副檔名'

$candidates = New-Object System.Collections.Generic.List[object]

Get-ChildItem -LiteralPath $DriveRoot -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
  if ($null -eq $_) { return }
  if (Test-UnderSkipped $_.FullName) { return }

  # 快速過濾：沒有 from／衝突 關鍵字且副檔名正常 → 略過
  $n = $_.Name
  $ext = $_.Extension
  $looksBroken = ($n -match '(?i)[_-]from[A-Za-z]') -or ($n -match '(?i)[_-]衝突[_-]?\d') -or ($ext -match '(?i)[_-]from') -or ($ext -match '(?i)衝突')
  if (-not $looksBroken) {
    # 副檔名本身含底線雜訊（如 .xls_xxx）
    if ($ext -match '(?i)^\.[A-Za-z0-9]{1,16}_') { $looksBroken = $true }
  }
  if (-not $looksBroken) { return }

  $newName = Repair-FileName $n
  if ($null -eq $newName) { return }
  if ($newName -eq $n) { return }

  $parent = $_.DirectoryName
  if ([string]::IsNullOrWhiteSpace($parent)) {
    $parent = Split-Path -Parent $_.FullName
  }
  if ([string]::IsNullOrWhiteSpace($parent)) { return }

  $unique = Get-UniqueName $parent $newName
  $candidates.Add([pscustomobject]@{
    Source = $_.FullName
    Dir    = $parent
    Old    = $n
    New    = $unique
  }) | Out-Null
}

Write-Host ("Candidates: {0}" -f $candidates.Count)
$renamed = 0
$err = 0
foreach ($c in $candidates) {
  Write-Host ("[REPAIR] {0}" -f $c.Old)
  Write-Host ("      -> {0}" -f $c.New)
  if (-not $Execute) { continue }
  try {
    if (-not (Test-Path -LiteralPath $c.Source)) {
      Write-Warning ("不存在: {0}" -f $c.Source)
      continue
    }
    $unique = Get-UniqueName $c.Dir $c.New
    Rename-Item -LiteralPath $c.Source -NewName $unique -Force
    $renamed++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ''
if ($Execute) {
  Write-Host "done repaired=$renamed err=$err"
  Write-Host '可再跑 inventory-e-drive.ps1 或抽樣雙擊開啟幾個檔確認。'
} else {
  Write-Host 'Dry-run 結束。確認後執行：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\restore-usable-extensions-on-e.ps1 -Execute'
}
