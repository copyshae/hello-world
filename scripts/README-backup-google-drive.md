# 備份 G: Google Drive → E:\google_drive

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull

# 預覽（偵測 G:\我的雲端硬碟 或 G:\My Drive）
powershell -ExecutionPolicy Bypass -File .\scripts\backup-google-drive-to-e.ps1

# 真正備份（複製，不刪 E: 既有檔）
powershell -ExecutionPolicy Bypass -File .\scripts\backup-google-drive-to-e.ps1 -Execute
```

若路徑不對：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\backup-google-drive-to-e.ps1 -Execute -SourceRoot "G:\我的雲端硬碟"
```

**串流模式**可能拷不到未下載檔；請在 Google Drive 改「鏡像硬碟」或先讓檔案可離線。
