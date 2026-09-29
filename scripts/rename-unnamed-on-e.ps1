#Requires -Version 5.1
<#
.SYNOPSIS
  只處理 E:\ 底下檔名含「未命名」者，依 20260717 規則改成 YYYY-MM-DD_代表性名稱.副檔名。

.DESCRIPTION
  - 來源：E:\ 全碟（略過回收桶／系統目錄）
  - 規則：YYYY-MM-DD_代表性名稱.ext（日期取 LastWriteTime）
  - 已符合 ^\d{4}-\d{2}-\d{2}_ 的檔名略過
  - 無法從內容辨識時，代表性名稱用「未命名待整理」或去掉「未命名」後的殘餘詞
  - 預設 Dry-run；加 -Execute 才 Rename-Item

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\rename-unnamed-on-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\rename-unnamed-on-e.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot 。請在本機 Windows、外接碟已插入時執行。"
}

$skipDirRe = '^(System Volume Information|\$RECYCLE\.BIN|FOUND\.\d+|\$RECYCLE\.BIN)$'
$alreadyNamedRe = '^\d{4}-\d{2}-\d{2}_'
$unnamedRe = '未命名'

function Get-DatePrefix([datetime]$dt) {
  return $dt.ToString('yyyy-MM-dd')
}

function Get-RepresentativeBase([string]$baseName) {
  # 去掉副檔名後的主檔名 → 代表性名稱
  $s = $baseName.Trim()
  # 常見掃描軟體殘留時間戳先保留有意義片段
  $s = $s -replace '未命名\s*', ''
  $s = $s -replace '[\(\)（）\[\]【】]', ' '
  $s = $s -replace '_+', '_'
  $s = $s -replace '\s+', ' '
  $s = $s.Trim(' ', '_', '-', '.')
  if ([string]::IsNullOrWhiteSpace($s)) {
    return '未命名待整理'
  }
  # 過短或純數字編號 → 仍當待整理，但保留編號避免全撞名
  if ($s -match '^\d{1,3}$') {
    return ('未命名待整理_' + $s)
  }
  return $s
}

function Get-UniquePath([string]$dir, [string]$fileName) {
  $dest = Join-Path $dir $fileName
  if (-not (Test-Path -LiteralPath $dest)) { return $dest }
  $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
  $ext = [System.IO.Path]::GetExtension($fileName)
  for ($i = 2; $i -le 999; $i++) {
    $candidate = Join-Path $dir ('{0}_{1}{2}' -f $base, $i, $ext)
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
  }
  throw "無法產生唯一檔名: $fileName"
}

$candidates = New-Object System.Collections.Generic.List[object]

Get-ChildItem -LiteralPath $DriveRoot -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
  $full = $_.FullName
  # 略過系統／回收路徑
  foreach ($seg in ($full -split '[\\/]')) {
    if ($seg -match $skipDirRe) { return }
  }
  if ($_.Name -notmatch $unnamedRe) { return }
  if ($_.BaseName -match $alreadyNamedRe) { return }

  $datePrefix = Get-DatePrefix $_.LastWriteTime
  $rep = Get-RepresentativeBase $_.BaseName
  # 若代表性名稱本身沒有日期前綴，套用規則
  $newBase = '{0}_{1}' -f $datePrefix, $rep
  $newName = $newBase + $_.Extension
  if ($newName -eq $_.Name) { return }

  $dest = Get-UniquePath $_.DirectoryName $newName
  $candidates.Add([pscustomobject]@{
    Source = $full
    Dest   = $dest
    Old    = $_.Name
    New    = [System.IO.Path]::GetFileName($dest)
  })
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的改名）' })))
Write-Host ("DriveRoot: {0}" -f $DriveRoot)
Write-Host ("Candidates: {0}" -f $candidates.Count)
Write-Host "規則: YYYY-MM-DD_代表性名稱.ext（僅檔名含「未命名」）"

if ($candidates.Count -eq 0) {
  Write-Host ""
  Write-Host "沒有找到檔名含「未命名」且尚未符合日期前綴的檔案。"
  Write-Host "可先確認："
  Write-Host "  Get-ChildItem E:\ -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object Name -Match '未命名' | Select-Object -First 30 FullName"
  exit 0
}

$renamed = 0
$err = 0
foreach ($c in $candidates) {
  Write-Host ("[RENAME] {0} -> {1}" -f $c.Old, $c.New)
  Write-Host ("         {0}" -f $c.Source)
  if (-not $Execute) { continue }
  try {
    Rename-Item -LiteralPath $c.Source -NewName $c.New -Force
    $renamed++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ""
if ($Execute) {
  Write-Host "done renamed=$renamed err=$err"
} else {
  Write-Host "Dry-run 結束。確認後執行："
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\rename-unnamed-on-e.ps1 -Execute"
}
