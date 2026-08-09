# 下載 Google 相簿 → E:\GOOGLE相簿

Google 相簿**不是** `G:` Google Drive，不能用複製 `G:` 的方式備份。

## 本機步驟（rclone）

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
git checkout cursor/move-company-from-private-f39f
git pull origin cursor/move-company-from-private-f39f

# 若尚未安裝 rclone：加 -InstallRclone，或先 winget install --id Rclone.Rclone -e
# 第一次授權（會開瀏覽器登入 Google）
powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Setup

# 預覽
powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1

# 真正下載到 E:\GOOGLE相簿
powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Execute
```

目錄結構：

- `E:\GOOGLE相簿\全部媒體` ← 所有照片／影片
- `E:\GOOGLE相簿\相簿` ← 依相簿分類

只抓全部媒體：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Execute -Scope all
```

## 注意

- 需本機已登入可開瀏覽器授權的 Google 帳號
- Google Photos API 可能無法保證每張都是「原始檔」；共用／他人分享內容可能抓不到
- 可重跑 `-Execute` 續傳（已下載的會略過）
- 外接碟 `E:` 需已插入

## 若要官方完整打包（替代）

1. 開 https://takeout.google.com/
2. 只勾選「Google 相簿」
3. 匯出後把下載的 zip 解壓到 `E:\GOOGLE相簿`
