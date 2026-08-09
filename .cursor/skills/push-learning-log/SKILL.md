---
name: push-learning-log
description: >-
  hello-world 學習日誌捷徑：推送工作大要，或開啟線上學習日誌／學習日誌首頁。
  觸發「推日誌」「上日誌」「收工推日誌」「工作大要推 hello-world」「推到 github hello world」、
  「連日誌」「連上學習日誌」「開日誌」「日誌首頁」「學習日誌首頁」「開首頁」「裝快捷詞」時立刻使用。適用任何專案。
---

# 學習日誌捷徑（hello-world）

## A｜開啟網頁（只開連結、不改檔）

用系統預設瀏覽器開啟對應 URL，並把網址回給使用者。

| 短語 | 開啟 |
|------|------|
| `連日誌`／`連上學習日誌`／`開日誌` | 當月列表（見下方月份路徑）；目前優先 https://copyshae.github.io/hello-world/directory/202608/ |
| `日誌首頁`／`學習日誌首頁`／`開首頁` | https://copyshae.github.io/hello-world/directory/ |

Windows 例：`Start-Process "https://…"`

## B｜安裝／更新快捷詞（本機）

使用者說 `裝快捷詞` 時：

1. 找到 hello-world 倉庫根目錄。
2. 執行：`powershell -ExecutionPolicy Bypass -File .\install-push-log-shortcut.ps1`
3. 回覆安裝完成，提醒「重新開一個 Cursor 對話」。

## C｜推送工作大要

### 觸發短語

- `推日誌`／`上日誌`／`收工推日誌`
- `工作大要推 hello-world`／`推到 github hello world`
- 可加日期：`推日誌 0727`

### 月份路徑

| 月份 | 日誌檔與列表 |
|------|----------------|
| `202607` | `directory/logs/`（舊連結相容） |
| `202608` 起 | `directory/YYYYMM/`（例：`directory/202608/`） |

### 必做步驟

1. 本機倉庫優先：`C:\Users\CSM\Desktop\hello-world`、`%USERPROFILE%\Desktop\hello-world`，或已 clone 路徑；若無則 `gh repo clone copyshae/hello-world`。先 `git pull`。
2. 依日期決定月份資料夾（上表）；檔名 `YYYYMMDD-learning-log.html`。使用者指定月日則用該日；若該月資料夾尚不存在則先建立（含 `index.html`，樣式對齊既有月）。
3. HTML 對齊既有篇（CSS、nav、分節、線上連結）；nav 連回 `directory/` 與該月 `index.html`。
4. 只寫工作大要；勿寫密碼、vault、個資、學生名冊。
5. 更新**該月** `index.html` 最上方一筆；若是新月份，並在 `directory/index.html` 列表最上方加該月連結。
6. Commit＋push `origin master`。缺 git user 時用環境變數（勿改 git config）：name `copyshae`，email `125623160+copyshae@users.noreply.github.com`。
7. 回覆線上連結，例如：  
   `https://copyshae.github.io/hello-world/directory/202608/YYYYMMDD-learning-log.html`  
   （202607 仍為 `…/directory/logs/YYYYMMDD-learning-log.html`）

### Commit 訊息

`Add YYYYMMDD learning log: <英文短述>.`
