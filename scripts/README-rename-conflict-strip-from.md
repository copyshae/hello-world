# 搬移衝突檔名去掉 fromE 等英文後綴

把 `_搬移衝突` 內像 `報告_fromE_20260809123456789.pdf` 改成 `報告.pdf`（`fromPrivate` 等同理）。

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1 -Execute
```
