# 從私人移出學校檔（本機 Windows）

雲端 Agent **讀不到** `E:\`，請在外接碟已插入的 Windows 執行。

```powershell
cd <hello-world倉庫>
git pull
git checkout cursor/move-company-from-private-f39f
powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1
```

先 **Dry-run** 列出會搬的項目；確認後：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1 -Execute
```

## 行為

| 項目 | 說明 |
|------|------|
| 來源 | `E:\私人`（深度 1～3） |
| 目的 | `E:\學校\`（第一層） |
| 子目錄 | 學年資料／衛生健促／科展科學營／試題教案／請假／打掃區域／其他學校 |
| 匹配 | `school`、學年、衛生、健促、科展、科學營、試題、教案、請假、打掃、學校、班級、教室… |
| 略過 | 私人骨架；天圓／弟子規／生命密碼（走超級生命密碼腳本）；公司關鍵字 |
| 刪檔 | **不刪**；同名目錄合併；檔名衝突進 `_搬移衝突` |
| 日誌 | `E:\學校\_搬移日誌\move-school_*.txt` |

## 建議執行順序

1. `move-super-life-code.ps1` → `E:\超級生命密碼`
2. `move-school-from-private.ps1` → `E:\學校`
3. `move-company-from-private.ps1` → `E:\公司`
