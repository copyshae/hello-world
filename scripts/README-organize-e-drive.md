# 一鍵整理 E:\（本機 Windows）

雲端 **不會** 幫你搬 `E:\`。檔案總管若只有「私人」「學校」、沒有「超級生命密碼」，代表本機腳本尚未成功 `-Execute`。

## 步驟（請開 PowerShell，不要只開資料夾）

雲端 Agent **無法** 代你搬本機 `E:\`，必須在這台 Windows 執行。

腳本已存成 **UTF-8 BOM**（給 Windows PowerShell 5.1）。若出現「未預期的語彙基元／字串遺漏結尾」，請先 `git pull` 再跑。


1. 鍵盤 `Win + X` → 選 **Windows PowerShell** 或 **終端機**
2. **推薦一鍵**（自動找倉庫、pull、預覽；加 `-Execute` 會再問一次 Y 才搬）：

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
git checkout cursor/move-company-from-private-f39f
powershell -ExecutionPolicy Bypass -File .\scripts\run-organize-local.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\run-organize-local.ps1 -Execute
```

3. 或手動分步：

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
