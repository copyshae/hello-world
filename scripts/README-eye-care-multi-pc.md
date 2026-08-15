# 護眼提醒｜兩台都有 Cursor

兩台電腦各自用同一 GitHub 倉庫安裝即可。

## 每一台都做一次

在 Cursor 終端或 PowerShell：

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git fetch origin
git checkout cursor/eye-care-reminders-433c
git pull origin cursor/eye-care-reminders-433c

# 只要本機提醒（兩台設定各自獨立）
powershell -ExecutionPolicy Bypass -File .\scripts\install-eye-care-app-to-desktop.ps1

# 或：時間／文案要兩台同步（需同一 OneDrive 帳號）
powershell -ExecutionPolicy Bypass -File .\scripts\install-eye-care-app-to-desktop.ps1 -UseOneDrive
```

然後雙擊桌面 **`護眼提醒.vbs`** → **開始提醒**。

## 建議

| 項目 | 做法 |
|------|------|
| 程式更新 | 兩台都 `git pull` 後再跑一次 install |
| 時間／文案同步 | 兩台都加 `-UseOneDrive` |
| 已提醒過的狀態 | 只存本機，不會互相干擾 |

若另一台還沒 clone：

```powershell
cd $env:USERPROFILE\Desktop
git clone https://github.com/copyshae/hello-world.git
cd hello-world
git checkout cursor/eye-care-reminders-433c
powershell -ExecutionPolicy Bypass -File .\scripts\install-eye-care-app-to-desktop.ps1 -UseOneDrive
```
