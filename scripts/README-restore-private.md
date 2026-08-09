# 恢復 E:\私人

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\find-private-on-e.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1 -Execute
```
