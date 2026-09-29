# 只處理「未命名」檔名（20260717 規則）

依學習日誌：可搜尋檔名 = `YYYY-MM-DD_代表性名稱.副檔名`。  
本腳本**只改檔名含「未命名」者**，不搬公司／學校分類。

## 本機執行

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
git checkout cursor/move-company-from-private-f39f

# 預覽
powershell -ExecutionPolicy Bypass -File .\scripts\rename-unnamed-on-e.ps1

# 真的改名
powershell -ExecutionPolicy Bypass -File .\scripts\rename-unnamed-on-e.ps1 -Execute
```

## 行為

| 項目 | 說明 |
|------|------|
| 範圍 | `E:\` 遞迴檔案 |
| 條件 | 檔名含「未命名」，且尚未是 `YYYY-MM-DD_` 開頭 |
| 日期 | 檔案 `LastWriteTime` |
| 代表性名稱 | 去掉「未命名」後的殘餘詞；若空則 `未命名待整理` |
| 略過 | 回收桶、System Volume Information |

無法讀 PDF 內容時不會猜證件／學校關鍵詞；僅做日期前綴＋待整理標示。
