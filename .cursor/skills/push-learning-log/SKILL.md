---
name: push-learning-log
description: >-
  把本對話剛完成的工作大要寫成學習日誌，提交並推送到 GitHub copyshae/hello-world。
  使用者說「推日誌」「上日誌」「收工推日誌」「工作大要推 hello-world」「推到 github hello world」
  或同類短語時立刻使用此 skill。適用任何專案對話。
---

# 推學習日誌到 hello-world

## 觸發短語（使用者可只打這些）

- `推日誌`
- `上日誌`
- `收工推日誌`
- `工作大要推 hello-world`
- `推到 github hello world`

可加日期：`推日誌 0727`（當年月日）。

## 必做步驟

1. 本機倉庫優先尋找（存在即用）：
   - `C:\Users\CSM\Desktop\hello-world`
   - `%USERPROFILE%\Desktop\hello-world`
   - 或已 clone 的 `hello-world` 路徑  
   若無：`gh repo clone copyshae/hello-world` 到桌面該路徑。先 `git pull`。
2. 依今日系統日期決定檔名 `directory/logs/YYYYMMDD-learning-log.html`。使用者指定日期（如 `0727`／`改成 0727`）則用 `YYYY`＋該月日。
3. HTML 格式對齊既有篇（例 `20260726-learning-log.html`）：同一套 CSS、nav、`h1`／`lead`／分節、線上連結。
4. 內容只寫**工作大要**：目標、做了什麼、結果路徑／數字、可重跑要點、踩坑。禁止空泛教學；**勿寫密碼、vault、個資、學生名冊**。
5. 更新 `directory/logs/index.html`：清單最上方加一筆（新到舊），含標題短句與線上 URL。
6. Commit＋push 到 `origin master`。若缺 git user，用環境變數（**勿改 git config**）：
   - `GIT_AUTHOR_NAME` / `GIT_COMMITTER_NAME` = `copyshae`
   - email = `125623160+copyshae@users.noreply.github.com`
7. 回覆**線上網址**：
   `https://copyshae.github.io/hello-world/directory/logs/YYYYMMDD-learning-log.html`

## Commit 訊息風格

`Add YYYYMMDD learning log: <英文短述>.`
