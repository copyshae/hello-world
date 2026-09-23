# 找回／修復 E:\ 上的 MP4

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull

# 先清點（報告：E:\_清點報告\mp4_find_*.txt）
powershell -ExecutionPolicy Bypass -File .\scripts\find-restore-mp4-on-e.ps1

# 修復壞檔名＋取消隱藏
powershell -ExecutionPolicy Bypass -File .\scripts\find-restore-mp4-on-e.ps1 -Execute

# 再把「搬移衝突／日誌」裡的 MP4 集中到 影音歸檔\_找回的MP4
powershell -ExecutionPolicy Bypass -File .\scripts\find-restore-mp4-on-e.ps1 -Execute -GatherFromConflict
```

若是弟子規／超碼歌曲，也可一併：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\find-dizigui-episodes-on-e.ps1 -Execute
powershell -ExecutionPolicy Bypass -File .\scripts\find-super-life-on-e.ps1 -Execute
```
