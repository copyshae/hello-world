# 從私人移出公司檔（本機 Windows）

雲端 Agent **讀不到** `E:\`，請在外接碟已插入的 Windows 執行。

```powershell
cd <hello-world倉庫>
git pull
git checkout cursor/move-company-from-private-f39f
powershell -ExecutionPolicy Bypass -File .\scripts\move-company-from-private.ps1
```

先 **Dry-run** 列出會搬的項目；確認後：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-company-from-private.ps1 -Execute
```

## 行為

| 項目 | 說明 |
|------|------|
| 來源 | `E:\私人`（含其下名為 `公司` 的子資料夾內容） |
| 目的 | `E:\公司\`（公文合約／財務報銷／掃描檔） |
| 匹配 | 名稱含 `公司`、`上班`、`公文`、`報銷` 等 |
| 略過 | 私人骨架；天圓／弟子規／生命密碼（`move-super-life-code.ps1`）；學校類（`move-school-from-private.ps1`） |
| 刪檔 | 真資料只搬不刪；**搬空後會清除 `E:\私人\公司`**（不再留空殼） |
| 日誌 | `E:\公司\_搬移日誌\move-company_*.txt` |

## 只清私人\公司空殼

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clear-private-company-folder.ps1 -Execute
```

## E:\公司 併入學校並刪除

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-e-company.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-e-company.ps1 -Execute
```

詳見 `README-move-clear-e-company.md`。

## 與其他腳本的關係

| 腳本 | 方向 |
|------|------|
| `move-private-from-backup.ps1` | `E:\備份` → `E:\私人` |
| `move-super-life-code.ps1` | 天圓／弟子規／修行／生命密碼 → `E:\超級生命密碼` |
| `move-school-from-private.ps1` | `E:\私人` 內學校類 → `E:\學校` |
| `move-company-from-private.ps1` | `E:\私人` 內其餘公司類 → `E:\公司` |
