# 快捷提示詞｜推學習日誌（跨電腦／全專案）

## 日常用法

在**任何專案**的 Cursor 對話直接輸入：

```
推日誌
```

| 短語 | 用途 |
|------|------|
| `推日誌` | 今日日期、本對話工作大要 |
| `上日誌` | 同上 |
| `收工推日誌` | 收工時用 |
| `推日誌 0727` | 指定月日（當年） |
| `工作大要推 hello-world` | 完整說法 |

寫入並推送：https://github.com/copyshae/hello-world → `directory/logs/`  
線上例：https://copyshae.github.io/hello-world/directory/logs/

## 換機／新電腦（做一次）

1. `git clone https://github.com/copyshae/hello-world.git`（或 `git pull` 更新）
2. 在倉庫根目錄執行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-push-log-shortcut.ps1
```

3. 重新開一個 Cursor 對話即可。

腳本會把規則與 skill 複製到：

- `%USERPROFILE%\.cursor\rules\push-learning-log.mdc`
- `%USERPROFILE%\.cursor\skills\push-learning-log\SKILL.md`

之後**不限專案**都認得「推日誌」。倉庫更新捷徑後再跑一次安裝腳本即可同步。

## 倉庫內正式檔（GitHub 真相來源）

- `.cursor/skills/push-learning-log/SKILL.md`
- `.cursor/rules/push-learning-log.mdc`
- `install-push-log-shortcut.ps1`
