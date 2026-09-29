# 將 E:\學校 搬到合適同層目錄（不重建私人）

| 內容 | 目的 |
|------|------|
| 超碼／天圓／弟子規／身心靈 | `E:\超級生命密碼\…` |
| 影音／歌曲／mp4… | `E:\影音歸檔`（若有） |
| 圖片 | `E:\圖片歸檔`（若有） |
| 學年／試題／文件 | `E:\文件歸檔\學校`（若有文件歸檔） |
| 其餘 | `E:\從學校移入` |

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute
```
