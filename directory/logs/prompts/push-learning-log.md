# 快捷提示詞｜學習日誌（跨電腦／全專案）

在**任何專案**的 Cursor 對話直接輸入短語即可。

## 開啟網頁

| 短語 | 開啟 |
|------|------|
| `連日誌`／`連上學習日誌`／`開日誌` | [當月學習日誌列表](https://copyshae.github.io/hello-world/directory/logs/) |
| `日誌首頁`／`學習日誌首頁`／`開首頁` | [學習日誌首頁](https://copyshae.github.io/hello-world/directory/) |

## 推送工作大要

| 短語 | 用途 |
|------|------|
| `推日誌` | 今日日期、本對話工作大要 |
| `上日誌` | 同上 |
| `收工推日誌` | 收工時用 |
| `推日誌 0727` | 指定月日（當年） |
| `工作大要推 hello-world` | 完整說法 |

寫入：https://github.com/copyshae/hello-world → `directory/logs/`

## 換機／新電腦（做一次）

```powershell
cd <hello-world倉庫>
git pull
powershell -ExecutionPolicy Bypass -File .\install-push-log-shortcut.ps1
```

會安裝到：

- `%USERPROFILE%\.cursor\rules\push-learning-log.mdc`
- `%USERPROFILE%\.cursor\skills\push-learning-log\SKILL.md`

倉庫更新捷徑後再跑一次安裝腳本。

## 倉庫內正式檔

- `.cursor/skills/push-learning-log/SKILL.md`
- `.cursor/rules/push-learning-log.mdc`
- `install-push-log-shortcut.ps1`
