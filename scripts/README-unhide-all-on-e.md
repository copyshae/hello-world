# 讓 E:\ 所有檔案顯示（取消隱藏）

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\unhide-all-on-e.ps1 -Execute
```

會：
1. 開啟檔案總管「顯示隱藏的項目」
2. 清掉 `E:\` 底下檔案／資料夾的 Hidden 屬性

若仍有看不到：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\unhide-all-on-e.ps1 -Execute -AlsoClearSystem
```

然後關閉檔案總管再重開，或按 F5。
