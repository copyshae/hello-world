---
name: visio-school-map
description: >-
  Edits school floor-plan / cleaning-zone Visio files (.vsd/.vsdx) via Visio COM:
  open side-by-side with Cursor, rename, replace school-year text, map class numbers
  from Excel (old→new), optionally limit to filled/colored room shapes, handle
  vertical newline-split numbers, skip mm dimensions. Use when the user mentions
  Visio, .vsd, .vsdx, 教室分佈, 掃地區域, 班級輪替, or 學年平面圖.
---

# Visio 學校平面圖編輯

## 預設原則（2026-07 起）

1. **並排**：Cursor 左、Visio 右；改完以 Visio 本體為準即時查看。
2. **班級取代**：優先 **Excel 兩欄（舊→新）**，不要預設 1→2→3→1 循環。
3. **範圍**：只改 **有底塗／填色** 框住的班級；**無填色底圖教室不改**。
4. **排除**：`*mm` 尺寸、學年標記數字、地址／無關長數字。
5. **直書**：數字間有換行時，組成三碼查表後寫回並保留換行。
6. **先掃後改**：回報將改／略過數量與範例；使用者說「直接改」可跳過確認。
7. **存檔**：`ActiveDocument.Save()`；`.vsd` 預設不推公開 Git。

完整可貼提示詞與檢查清單見專案：  
`directory/logs/prompts/visio-edit-prompt.md`  
（個人技能複本：`~/.cursor/skills/visio-school-map/`）

## 執行步驟

### 1. 開啟

- Visio：`C:\Program Files\Microsoft Office\root\Office16\VISIO.EXE`
- COM：`GetActiveObject('Visio.Application')` 或開啟文件後取得 Application

### 2. 學年

- 取代標題等處的 `NNN學年`／`學年度`
- 右側直行獨立學年數字一併改；勿套用班級對照

### 3. Excel 對照

- 讀使用者指定的 xlsx／xls；A=舊、B=新
- 建字典後只替換命中鍵

### 4. 底色過濾

- `FillPattern = 0` → 跳過（無填滿）
- 文字在子 Shape、色塊在父 Shape → **以父層有填色為準**
- 白色是否算底塗：不確定就先列出再問

### 5. 文字匹配

- 橫式：`(?<![0-9])(\d{3})(?![0-9])`
- 直式：`(?<!\d)(\d)(\s+)(\d)(\s*)(\d)(?!\d)` 等「有分隔的三碼」
- 標籤內嵌（美術／體育／舞蹈／特教班）：有底色且對照表有碼才改其中數字

### 6. 舊循環法（僅明確要求時）

- `1xx→2xx→3xx→1xx` 一次映射；橫直分治；勿重複輪轉已改橫式

## 回報模板

```
將修改：N（有底色＋對照表）
略過：無底色 / 無對照 / 排除
範例：…
已 Save：是／否
```
