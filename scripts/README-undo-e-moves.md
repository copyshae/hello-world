# 盡力還原今日 E:\ 搬移（非完整時光機）

**不能保證**回到今天整理前的最原始狀態。搬移用的是 Move，不是複製。

## 較可靠的還原（請先試）

1. 檔案總管對 **`E:\`**（或 `E:\私人`）右鍵 → **內容** → **以前的版本**  
2. 若有今天以前的還原點，還原整個資料夾  
3. 或從你既有的完整備份碟還原

## 日誌反向搬回（次佳）

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\undo-e-moves-from-logs.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\undo-e-moves-from-logs.ps1 -Execute
```

只處理 `_搬移日誌\move-*.txt` 有記錄的路徑；已刪空殼、衝突改名、沒寫進日誌的操作無法還原。
