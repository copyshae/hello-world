#Requires -Version 5.1
# Sync learning logs 0821-0829 from copyshae/- _export into Desktop\hello-world and push Pages.
# ASCII-only (Windows PowerShell 5.1 misparses UTF-8 without BOM as Big5).
$ErrorActionPreference = "Stop"
$branch = "main"
$base = "https://raw.githubusercontent.com/copyshae/-/$branch/_export/hello-world"

$root = Join-Path ([Environment]::GetFolderPath("Desktop")) "hello-world"
if (-not (Test-Path -LiteralPath $root)) {
  throw "hello-world not found: $root. Clone https://github.com/copyshae/hello-world.git to Desktop first."
}

function Save-RemoteFile([string]$Rel) {
  $url = "$base/$($Rel.Replace('\','/'))"
  $path = Join-Path $root ($Rel.Replace("/", [string][char]92))
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
  Write-Host "Download $Rel"
  $tmp = Join-Path $env:TEMP ("hw-pull-" + [guid]::NewGuid().ToString() + ".bin")
  try {
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
    [System.IO.File]::WriteAllBytes($path, [System.IO.File]::ReadAllBytes($tmp))
  } finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
}

$files = @(
  "directory/index.html",
  "directory/learning-log.html",
  "directory/202608/index.html",
  "directory/202608/20260820-learning-log.html",
  "directory/202608/20260821-learning-log.html",
  "directory/202608/20260822-learning-log.html",
  "directory/202608/20260823-learning-log.html",
  "directory/202608/20260824-learning-log.html",
  "directory/202608/20260825-learning-log.html",
  "directory/202608/20260826-learning-log.html",
  "directory/202608/20260827-learning-log.html",
  "directory/202608/20260828-learning-log.html",
  "directory/202608/20260829-learning-log.html"
)

foreach ($f in $files) { Save-RemoteFile $f }

Set-Location $root
$pagesBranch = "master"
# git writes progress to stderr; Stop would treat that as a terminating error.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  git fetch origin $pagesBranch | Out-Null
  if ((git branch --show-current).Trim() -ne $pagesBranch) {
    git checkout $pagesBranch | Out-Null
    if ($LASTEXITCODE -ne 0) { git checkout -B $pagesBranch "origin/$pagesBranch" | Out-Null }
  }
  git pull origin $pagesBranch | Out-Null
} finally {
  $ErrorActionPreference = $prevEap
}

if (-not (git config user.name)) {
  $env:GIT_AUTHOR_NAME = "copyshae"
  $env:GIT_AUTHOR_EMAIL = "125623160+copyshae@users.noreply.github.com"
  $env:GIT_COMMITTER_NAME = $env:GIT_AUTHOR_NAME
  $env:GIT_COMMITTER_EMAIL = $env:GIT_AUTHOR_EMAIL
}

Write-Host ""
Write-Host "=== git status ==="
git add directory/index.html directory/learning-log.html directory/202608/
git status --short

$pending = git status --porcelain
if (-not $pending) {
  Write-Host ""
  Write-Host "[WARN] No changes to commit. Download failed or files already match."
  git log -1 --oneline
  exit 1
}

git commit -m "Add 20260821-20260829 learning logs: 14 samples, 7 habits, reading docs, Dizigui, Shengde KTV."
Write-Host ""
Write-Host "=== git push ==="
$ErrorActionPreference = "Continue"
git push origin $pagesBranch
$pushCode = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($pushCode -ne 0) {
  Write-Host ""
  Write-Host "[ERROR] git push failed. Sign in to GitHub, then: git push origin master"
  exit 1
}

Write-Host ""
Write-Host "=== OK ==="
git log -1 --oneline
Write-Host ""
Write-Host "Wait 1-2 min, then open:"
Write-Host "  https://copyshae.github.io/hello-world/directory/202608/index.html"
Write-Host "  Top entry should be 20260829"
