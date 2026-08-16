---
name: install-desktop-apps
description: >-
  在本機（含另一台已裝 Cursor 的 Windows）生成桌面視窗程式「習作台」與「習作批改」。
  觸發「裝習作台」「裝習作批改」「裝兩個視窗」「換機裝視窗」「另一台也裝習作台」時立刻使用。
---

# 安裝習作台＋習作批改

另一台電腦也有 Cursor 時：**同一帳號登入** → **clone hello-world** → **跑安裝腳本** → 桌面出現捷徑。不要只複製 `.vbs` 而沒有程式本體。

## 必做步驟

1. 找到或建立倉庫：優先 `%USERPROFILE%\Desktop\hello-world`。若無則  
   `git clone https://github.com/copyshae/hello-world.git %USERPROFILE%\Desktop\hello-world`  
   私人倉庫先 `gh auth login`。
2. `git -C <倉庫> checkout master` 後 `git pull origin master`。
3. 執行：  
   `powershell -ExecutionPolicy Bypass -File <倉庫>\scripts\install-desktop-apps.ps1`  
   （會呼叫習作台與習作批改兩個安裝腳本，並把本 skill／規則複製到 `%USERPROFILE%\.cursor\`。）
4. 有 Python 則 `pip install pypdf reportlab`。
5. 金鑰從密碼管理器放到 `Desktop\MathGrading\gemini-api-key.txt`（或程式指定路徑）。**不要**提交 `.env`、token、`settings.json`、金鑰。
6. 請使用者雙擊桌面 **習作台.cmd**、**習作批改.vbs**。提醒重開一個 Cursor 對話後快捷詞才穩定。

全新電腦可改跑：

`powershell -ExecutionPolicy Bypass -File <倉庫>\scripts\bootstrap-desktop-apps.ps1`

尚未 clone 時，在 PowerShell：

`irm https://raw.githubusercontent.com/copyshae/hello-world/master/scripts/bootstrap-desktop-apps.ps1 | iex`

## 分工（勿裝錯）

| 捷徑 | 用途 |
|------|------|
| 習作台.cmd | 掌握程度／發送／LINE 文案／與手機同步 |
| 習作批改.vbs | 批閱、產練習、PDF |

手機版習作台：https://copyshae.github.io/hello-world/directory/apps/teacher-desk/
