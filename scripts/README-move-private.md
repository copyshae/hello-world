# 從備份移出私人檔（本機 Windows）

雲端 Agent **讀不到** `E:\`，請在外接碟已插入的 Windows 執行：

```powershell
cd <hello-world倉庫>
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\move-private-from-backup.ps1
```

先 **Dry-run** 列出會搬的項目；確認後：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-private-from-backup.ps1 -Execute
```

## 行為

| 項目 | 說明 |
|------|------|
| 來源 | `E:\備份`（含 `另一硬碟備份` 頂層非 school 項） |
| 目的 | `E:\私人\` 下：財務／家庭／證件合約／掃描檔／車禍事故／密碼與金鑰／醫療健康 |
| 略過 | `school`、`NNN學年school`、衛生／健促等公務樹 |
| 刪檔 | **不刪**；同名衝突改放 `_搬移衝突` |
| 日誌 | `E:\私人\_搬移日誌\move-private_*.txt` |
