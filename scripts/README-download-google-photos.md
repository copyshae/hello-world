# 下載 Google 相簿 → E:\GOOGLE相簿

## 建議：一次貼上（不依賴舊腳本）

```powershell
$dir = "$env:USERPROFILE\Desktop\hello-world-tools\scripts"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
# 防快取
$url = "https://raw.githubusercontent.com/copyshae/hello-world/cursor/move-company-from-private-f39f/scripts/bootstrap-google-photos-to-e.ps1?t=$(Get-Random)"
Invoke-WebRequest -Uri $url -OutFile "$dir\bootstrap-google-photos-to-e.ps1" -UseBasicParsing
powershell -ExecutionPolicy Bypass -File "$dir\bootstrap-google-photos-to-e.ps1"
```

會自動：
1. 下載免安裝 `rclone.exe` 到 `Desktop\hello-world-tools\tools\rclone\`
2. 開 `rclone config`（名稱填 `gphotos`，選 Google Photos）
3. 下載到 `E:\GOOGLE相簿\全部媒體` 與 `相簿`

## 或分步腳本

```powershell
cd $env:USERPROFILE\Desktop\hello-world-tools
$url = "https://raw.githubusercontent.com/copyshae/hello-world/cursor/move-company-from-private-f39f/scripts/download-google-photos-to-e.ps1?t=$(Get-Random)"
Invoke-WebRequest -Uri $url -OutFile ".\scripts\download-google-photos-to-e.ps1" -UseBasicParsing
powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Setup
powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Execute
```

（已改為**不走 winget**；缺少 rclone 時直接下載 zip）
