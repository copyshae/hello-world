# 建立 E:\超級生命密碼 並移入相關檔（本機 Windows）

雲端 Agent **讀不到** `E:\`，請在外接碟已插入的 Windows 執行。

```powershell
cd <hello-world倉庫>
git pull
git checkout cursor/move-company-from-private-f39f
powershell -ExecutionPolicy Bypass -File .\scripts\move-super-life-code.ps1
```

先 **Dry-run** 列出會搬的項目；確認後：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-super-life-code.ps1 -Execute
```

## 行為

| 項目 | 說明 |
|------|------|
| 目的 | `E:\超級生命密碼\`（第一層） |
| 子目錄 | 超級生命密碼／天圓文化／弟子規／身心靈修行 |
| 來源 | `E:\` 根層；以及私人、公司、文件／影音／圖片／桌面／下載歸檔（深度 1～3） |
| 匹配 | `超級生命密碼`、`生命密碼`、`天圓`、`太陽盛德`、`弟子規`、`身心靈`、`修行`、`滋養研究` 等 |
| 略過 | `備份` 整樹、私人骨架目錄本身、已在目的地底下 |
| 刪檔 | **不刪**；目的資料夾已存在則合併；檔名衝突進 `_搬移衝突` |
| 日誌 | `E:\超級生命密碼\_搬移日誌\move-super-life_*.txt` |

## 建議執行順序

1. `move-private-from-backup.ps1`（備份 → 私人）
2. `move-super-life-code.ps1`（天圓／弟子規／修行 → 超級生命密碼）
3. `move-school-from-private.ps1`（學校類 → 學校）
4. `move-company-from-private.ps1`（其餘公司檔 → 公司）
