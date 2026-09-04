#Requires -Version 5.1
<#
.SYNOPSIS
  恢復 E:\私人：當「私人」已刪、子目錄被提到 E:\ 同層時，重建私人並收回子目錄。

.DESCRIPTION
  典型現況：E:\ 下直接有 財務、家庭、備份、影音歸檔、文件歸檔…（原私人底下的東西）
  本腳本會：
    1) 建立 E:\私人（若不存在）
    2) 把 E:\ 根層符合私人骨架的資料夾／檔案移回 E:\私人\
    3) 不碰：學校、超級生命密碼、公司、_清點報告、系統目錄

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) { throw "找不到 $DriveRoot" }

$privateRoot = Join-Path $DriveRoot '私人'

# 原私人第一層常見項目（可依實際增補）
$privateChildren = @(
  '財務', '家庭', '證件合約', '掃描檔', '車禍事故', '密碼與金鑰', '醫療健康',
  '備份', '影音歸檔', '文件歸檔', '桌面歸檔', '下載歸檔', '圖片歸檔', '工具軟體',
  '從學校移入', '公司'
)

# 同層不要搬進私人的目錄
$leaveAtRoot = @(
  '私人', '學校', '超級生命密碼', '公司',
  '_清點報告', '_找回的MP4',
  'System Volume Information', '$RECYCLE.BIN', 'FOUND.000'
)

function Get-UniqueDest([string]$dir, [string]$name) {
  $dest = Join-Path $dir $name
  if (-not (Test-Path -LiteralPath $dest)) { return $dest }
  $base = [IO.Path]::GetFileNameWithoutExtension($name)
  $ext = [IO.Path]::GetExtension($name)
  for ($i = 2; $i -le 999; $i++) {
    $c = Join-Path $dir ('{0}_{1}{2}' -f $base, $i, $ext)
    if (-not (Test-Path -LiteralPath $c)) { return $c }
  }
  throw "無法唯一命名: $name"
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host '狀況假設：E:\私人 已刪，原子目錄在 E:\ 同層 → 重建私人並收回'
Write-Host ''
Write-Host '======== E:\ 目前第一層 ========'
$tops = @(Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue)
foreach ($t in $tops) {
  Write-Host ("  {0}" -f $t.Name)
}

if (Test-Path -LiteralPath $privateRoot) {
  Write-Host ''
  Write-Host ("已有 {0}，改為把「仍留在 E:\ 根層」的私人子項收回。" -f $privateRoot)
} else {
  Write-Host ''
  Write-Host '將建立 E:\私人'
}

# 候選：根層名稱在私人骨架清單，或不在 leaveAtRoot 且看起來像私人內容
$candidates = New-Object System.Collections.Generic.List[object]
foreach ($t in $tops) {
  if ($t.Name -eq '私人') { continue }
  if ($leaveAtRoot -contains $t.Name) { continue }
  if ($privateChildren -contains $t.Name) {
    $candidates.Add($t) | Out-Null
    continue
  }
  # 根層散落的 zip／常見私人檔也可收回（可選，只收明確清單外的「歸檔」「備份」相關名）
  if ($t.Name -match '歸檔|備份|私人|掃描|財務|家庭|證件') {
    $candidates.Add($t) | Out-Null
  }
}

Write-Host ''
Write-Host ("將收回至 E:\私人 的根層項目: {0}" -f $candidates.Count)
foreach ($c in $candidates) {
  Write-Host ("  [RECLAIM] {0}" -f $c.FullName)
}

if ($candidates.Count -eq 0 -and (Test-Path -LiteralPath $privateRoot)) {
  Write-Host '沒有需要收回的根層項目；E:\私人 已存在。'
  exit 0
}

if (-not $Execute) {
  Write-Host ''
  Write-Host '確認後執行：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1 -Execute'
  exit 0
}

if (-not (Test-Path -LiteralPath $privateRoot)) {
  New-Item -ItemType Directory -Path $privateRoot -Force | Out-Null
  Write-Host 'MKDIR E:\私人'
}

$moved = 0
$err = 0
foreach ($c in $candidates) {
  if (-not (Test-Path -LiteralPath $c.FullName)) { continue }
  $dest = Join-Path $privateRoot $c.Name
  try {
    if (Test-Path -LiteralPath $dest) {
      if ($c.PSIsContainer) {
        Write-Host ("[MERGE] {0} -> {1}" -f $c.FullName, $dest)
        Get-ChildItem -LiteralPath $c.FullName -Force -ErrorAction SilentlyContinue | ForEach-Object {
          $childDest = Get-UniqueDest $dest $_.Name
          Move-Item -LiteralPath $_.FullName -Destination $childDest -Force
        }
        Remove-Item -LiteralPath $c.FullName -Recurse -Force -ErrorAction SilentlyContinue
      } else {
        $dest = Get-UniqueDest $privateRoot $c.Name
        Write-Host ("[MOVE] {0} -> {1}" -f $c.FullName, $dest)
        Move-Item -LiteralPath $c.FullName -Destination $dest -Force
      }
    } else {
      Write-Host ("[MOVE] {0} -> {1}" -f $c.FullName, $dest)
      Move-Item -LiteralPath $c.FullName -Destination $dest -Force
    }
    $moved++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ''
Write-Host "done moved=$moved err=$err"
Write-Host '請按 F5 確認 E:\ 第一層有「私人」，且財務／備份／影音歸檔等在私人底下。'
Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("  {0}" -f $_.Name) }
if (Test-Path -LiteralPath $privateRoot) {
  Write-Host '======== E:\私人 第一層 ========'
  Get-ChildItem -LiteralPath $privateRoot -Force -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("  {0}" -f $_.Name) }
}
