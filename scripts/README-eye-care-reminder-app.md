# 護眼提醒桌面視窗程式

可在視窗裡**彈性修改提醒時間與文案**，按「開始提醒」後常駐檢查。

## 安裝到桌面（本機）

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git fetch origin cursor/eye-care-reminders-433c
git checkout origin/cursor/eye-care-reminders-433c -- `
  scripts/eye-care-reminder-app.ps1 `
  scripts/install-eye-care-app-to-desktop.ps1

powershell -ExecutionPolicy Bypass -File .\scripts\install-eye-care-app-to-desktop.ps1
```

之後雙擊桌面 **`護眼提醒.cmd`**。

## 視窗操作

1. 左欄選一筆提醒  
2. 右側改「類型／時間／每隔分鐘／時段／標題／文案」  
3. 按 **套用這筆**（會寫入 `桌面\護眼提醒\reminders.json`）  
4. 按 **開始提醒**  
5. **試播這筆**可立刻預覽彈窗  

### 類型

- **每日固定時間**：例如 `07:30` 百恩晴、`12:00` 午餐  
- **時段內每隔N分**：例如 `07:30–17:00` 每 20 分用眼休息、每 60 分喝水  

設定檔可用記事本改，也可按「開啟資料夾」。
