# 一鍵整理 E:\（本機 Windows）

雲端 **不會** 幫你搬 `E:\`。檔案總管若只有「私人」「學校」、沒有「超級生命密碼」，代表本機腳本尚未成功 `-Execute`。

## 步驟（請開 PowerShell，不要只開資料夾）

1. 鍵盤 `Win + X` → 選 **Windows PowerShell** 或 **終端機**
2. 貼上（`hello-world` 路徑請改成你的）：

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
git checkout cursor/move-company-from-private-f39f

# 先預覽（會列出 Candidates，不會搬）
powershell -ExecutionPolicy Bypass -File .\scripts\organize-e-drive.ps1

# 確認後真的搬
powershell -ExecutionPolicy Bypass -File .\scripts\organize-e-drive.ps1 -Execute

# 重新整理後應看到超級生命密碼
Get-ChildItem E:\
explorer E:\
```

## 成功時 E:\ 第一層至少應有

- `私人`
- `學校`（底下有學年資料／試題教案…）
- `超級生命密碼`（底下有天圓文化／弟子規…）
- `公司`（若私人裡有公司類檔）

## 若仍然沒有「超級生命密碼」

把 PowerShell **整段輸出**複製貼回對話（含 `Candidates:` 那幾行）。  
並先跑：

```powershell
Get-ChildItem E:\私人 -Recurse -Depth 2 | Select-Object FullName
```
