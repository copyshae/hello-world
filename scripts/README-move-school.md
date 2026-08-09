# 整理學校檔到 E:\學校（本機 Windows）

雲端 Agent **讀不到** `E:\`。你截圖裡的 `E:\學校` 若是**空的且沒有子目錄**，代表還沒成功跑過 `-Execute`（或來源本來就不在 `私人`）。

先前整理時，學校檔多半已在 **`E:\文件歸檔\學校`**，不在 `E:\私人`。本腳本已改為會一併搬：

- `E:\私人`
- `E:\文件歸檔\學校`（整包併入）
- `E:\` 根層、文件／桌面／下載歸檔中名稱像學校的項目

```powershell
cd <hello-world倉庫>
git pull
git checkout cursor/move-company-from-private-f39f

# 先看會搬哪些（應出現 Candidates > 0，並列出路徑）
powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1

# 確認後真的搬
powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1 -Execute

# 成功時應看到子目錄，不是空資料夾
explorer E:\學校
Get-ChildItem E:\學校
```

## 成功時 E:\學校 應有

學年資料／衛生健促／科展科學營／試題教案／請假／打掃區域／其他學校／`_搬移日誌`

## 若 Candidates: 0

在本機跑：

```powershell
Get-ChildItem E:\文件歸檔\學校 -ErrorAction SilentlyContinue
Get-ChildItem E:\私人 | Select-Object Name
Get-ChildItem E:\文件歸檔 -Recurse -Depth 2 | Where-Object { $_.Name -match '學校|試題|衛生|科展|請假|school' } | Select-Object FullName
```

把輸出貼回對話，再調規則。
