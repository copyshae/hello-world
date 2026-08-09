# 下載 Google 相簿 → E:\GOOGLE相簿

Google 相簿**不是** `G:` Google Drive。

## 最快（本機已有 hello-world-tools）

```powershell
cd $env:USERPROFILE\Desktop\hello-world-tools

# 重新抓最新腳本
$base = "https://raw.githubusercontent.com/copyshae/hello-world/cursor/move-company-from-private-f39f/scripts"
Invoke-WebRequest -Uri "$base/download-google-photos-to-e.ps1" -OutFile ".\scripts\download-google-photos-to-e.ps1" -UseBasicParsing

# 下載免安裝 rclone + 瀏覽器授權 + 下載相簿
powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -InstallRclone -Setup
powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Execute
```

`-InstallRclone` 會把 `rclone.exe` 放到：

`Desktop\hello-world-tools\tools\rclone\rclone.exe`

（不依賴系統 PATH，可避開 winget 裝完仍找不到的問題）

## 目錄

- `E:\GOOGLE相簿\全部媒體`
- `E:\GOOGLE相簿\相簿`

## 替代：Google Takeout

https://takeout.google.com/ → 只勾「Google 相簿」→ 解壓到 `E:\GOOGLE相簿`
