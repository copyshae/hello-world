#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate per-student grading note PDF; optionally append after original exam PDF."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, PageBreak


def find_cjk_font() -> str | None:
    candidates = [
        Path("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc"),
        Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
        Path("/usr/share/fonts/truetype/arphic/uming.ttc"),
        Path("C:/Windows/Fonts/msjh.ttc"),
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/mingliu.ttc"),
        Path("C:/Windows/Fonts/kaiu.ttf"),
    ]
    for p in candidates:
        if p.exists():
            return str(p)
    return None


def register_font() -> str:
    path = find_cjk_font()
    if path:
        try:
            pdfmetrics.registerFont(TTFont("CJK", path, subfontIndex=0))
            return "CJK"
        except Exception:
            try:
                pdfmetrics.registerFont(TTFont("CJK", path))
                return "CJK"
            except Exception:
                pass
    return "Helvetica"


def md_to_flowables(text: str, font_name: str):
    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "T",
        parent=styles["Heading1"],
        fontName=font_name,
        fontSize=16,
        leading=22,
        spaceAfter=10,
    )
    h2 = ParagraphStyle(
        "H2",
        parent=styles["Heading2"],
        fontName=font_name,
        fontSize=13,
        leading=18,
        spaceBefore=10,
        spaceAfter=6,
    )
    body = ParagraphStyle(
        "B",
        parent=styles["Normal"],
        fontName=font_name,
        fontSize=11,
        leading=16,
    )
    small = ParagraphStyle(
        "S",
        parent=body,
        fontSize=9,
        leading=13,
        textColor="gray",
    )

    story = []
    story.append(Paragraph("批閱註記（初核｜人工終核前）", title))
    story.append(
        Paragraph(
            "原則：接受合理等價解法。✓ 可快速打勾；? 存疑待老師確認／重謄。練習解答另頁，做完題再看。",
            small,
        )
    )
    story.append(Spacer(1, 0.3 * cm))
    content_started = False

    for raw in text.splitlines():
        line = raw.rstrip()
        if not line:
            story.append(Spacer(1, 0.15 * cm))
            continue
        # 解答與題目分頁：解答一律從新頁開始（文件開頭的解答標題除外）
        is_answer_break = (
            line.startswith("---")
            or line.startswith("#### 解答")
            or line.startswith("### 解答")
            or line.startswith("## 解答")
            or ("解答（全部題目完成後" in line)
            or line.startswith("#### 解答（")
        )
        if is_answer_break and content_started:
            story.append(PageBreak())
            if line.startswith("---"):
                continue
        if line.startswith("# "):
            story.append(Paragraph(_esc(line[2:]), title))
        elif line.startswith("## "):
            story.append(Paragraph(_esc(line[3:]), h2))
            content_started = True
        elif line.startswith("### ") or line.startswith("#### "):
            story.append(Paragraph(_esc(line.lstrip("#").strip()), h2))
            content_started = True
        elif line.startswith("- "):
            story.append(Paragraph("• " + _esc(line[2:]), body))
            content_started = True
        else:
            story.append(Paragraph(_esc(line), body))
            content_started = True
    return story


def _esc(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def split_practice_questions_answers(md_text: str) -> tuple[str, str]:
    """Split practice block into questions-only and answers-only."""
    if "## 依程度自學／補救練習" in md_text:
        block = md_text.split("## 依程度自學／補救練習", 1)[1]
        if "\n## " in block:
            block = block.split("\n## ", 1)[0]
    elif "## 需再練習" in md_text:
        block = md_text.split("## 需再練習", 1)[1]
        if "\n## " in block:
            block = block.split("\n## ", 1)[0]
    else:
        return "", ""

    # Prefer explicit answer heading
    for marker in (
        "\n#### 解答",
        "\n### 解答",
        "\n## 解答",
        "\n---\n",
    ):
        if marker in block:
            q, a = block.split(marker, 1)
            if marker.strip().startswith("---"):
                a = a.lstrip()
            else:
                a = marker.strip() + a
            return q.strip(), a.strip()
    return block.strip(), ""


def write_simple_pdf(title: str, body: str, pdf_path: Path) -> None:
    font = register_font()
    md = f"# {title}\n\n{body}\n"
    # reuse flowables but without double title noise: feed as md
    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=A4,
        leftMargin=1.8 * cm,
        rightMargin=1.8 * cm,
        topMargin=1.6 * cm,
        bottomMargin=1.6 * cm,
    )
    doc.build(md_to_flowables(md, font))


def _md_body_to_html(body: str) -> str:
    """Plain markdown-ish lines → simple HTML paragraphs for phone reading."""
    parts: list[str] = []
    for raw in body.splitlines():
        line = raw.rstrip()
        if not line:
            parts.append("<br>")
            continue
        if line.startswith("#### "):
            parts.append(f"<h3>{_esc(line[5:].strip())}</h3>")
        elif line.startswith("### "):
            parts.append(f"<h2>{_esc(line[4:].strip())}</h2>")
        elif line.startswith("## "):
            parts.append(f"<h2>{_esc(line[3:].strip())}</h2>")
        elif line.startswith("# "):
            parts.append(f"<h1>{_esc(line[2:].strip())}</h1>")
        elif line.startswith("---"):
            parts.append("<hr>")
        elif line.startswith("- "):
            parts.append(f"<p class='li'>• {_esc(line[2:])}</p>")
        else:
            parts.append(f"<p>{_esc(line)}</p>")
    return "\n".join(parts)


def write_mobile_html(title: str, body: str, html_path: Path, *, is_answer: bool = False) -> None:
    """Self-contained HTML for phone / tablet (LINE、雲端資料夾可開)."""
    warn = (
        "<p class='warn'>⚠ 請先把練習題全部做完，再打開本解答頁。</p>"
        if is_answer
        else "<p class='tip'>請用通訊裝置（手機／平板）閱讀。建議用紙本或記事本演算，做完再看解答檔。</p>"
    )
    html = f"""<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{_esc(title)}</title>
<style>
  :root {{ color-scheme: light; }}
  body {{
    margin: 0; padding: 16px 18px 48px;
    font-family: "Microsoft JhengHei", "Noto Sans TC", "PingFang TC", sans-serif;
    font-size: 18px; line-height: 1.55; color: #1a1a1a;
    background: #f7f4ef;
  }}
  h1 {{ font-size: 1.35rem; margin: 0 0 12px; color: #143d2e; }}
  h2 {{ font-size: 1.15rem; margin: 22px 0 8px; color: #1f4d3a; }}
  h3 {{ font-size: 1.05rem; margin: 16px 0 6px; color: #2a5a44; }}
  p {{ margin: 0.45em 0; }}
  p.li {{ padding-left: 0.2em; }}
  .tip {{ background: #e7f2ea; border-left: 4px solid #2a7a4b; padding: 10px 12px; border-radius: 4px; }}
  .warn {{ background: #fff3e0; border-left: 4px solid #c97820; padding: 10px 12px; border-radius: 4px; }}
  .foot {{ margin-top: 28px; font-size: 0.85rem; color: #666; }}
  hr {{ border: 0; border-top: 1px solid #ccc; margin: 18px 0; }}
</style>
</head>
<body>
<h1>{_esc(title)}</h1>
{warn}
{_md_body_to_html(body)}
<p class="foot">由習作批改工具產生｜優先數位發放，節省紙張</p>
</body>
</html>
"""
    html_path.parent.mkdir(parents=True, exist_ok=True)
    html_path.write_text(html, encoding="utf-8")


def write_digital_practice_for_student(md_path: Path, digital_dir: Path) -> tuple[bool, bool]:
    """Write phone-friendly practice HTML (+ plain txt for LINE). Returns (has_q, has_a)."""
    if not md_path.name.endswith("-註記.md"):
        return False, False
    sid = md_path.name.replace("-註記.md", "")
    text = md_path.read_text(encoding="utf-8")
    q, a = split_practice_questions_answers(text)
    digital_dir.mkdir(parents=True, exist_ok=True)
    has_q = bool(q.strip())
    has_a = bool(a.strip())
    if has_q:
        write_mobile_html(
            f"座號 {sid}｜自學練習題（先做完再看解答）",
            q,
            digital_dir / f"{sid}-練習題.html",
            is_answer=False,
        )
        (digital_dir / f"{sid}-練習題.txt").write_text(
            f"座號 {sid}｜自學練習題（先做完再看解答）\n\n{q}\n",
            encoding="utf-8",
        )
    if has_a:
        write_mobile_html(
            f"座號 {sid}｜練習解答（全部題目完成後再看）",
            a,
            digital_dir / f"{sid}-練習解答.html",
            is_answer=True,
        )
        (digital_dir / f"{sid}-練習解答.txt").write_text(
            f"座號 {sid}｜練習解答（全部題目完成後再看）\n\n{a}\n",
            encoding="utf-8",
        )
    return has_q, has_a


def write_print_practice_pdfs(md_path: Path, print_dir: Path) -> None:
    """Paper handouts only for students without devices."""
    if not md_path.name.endswith("-註記.md"):
        return
    sid = md_path.name.replace("-註記.md", "")
    text = md_path.read_text(encoding="utf-8")
    q, a = split_practice_questions_answers(text)
    print_dir.mkdir(parents=True, exist_ok=True)
    if q.strip():
        write_simple_pdf(
            f"座號 {sid}｜自學練習題（先做完再看解答）",
            q,
            print_dir / f"{sid}-練習題.pdf",
        )
    if a.strip():
        write_simple_pdf(
            f"座號 {sid}｜練習解答（全部題目完成後再看）",
            a,
            print_dir / f"{sid}-練習解答.pdf",
        )


def parse_print_seat_list(work_dir: Path) -> list[str]:
    """Seats without devices → print. File: 列印專用/需列印座號.txt"""
    path = work_dir / "列印專用" / "需列印座號.txt"
    if not path.exists():
        return []
    seats: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        for part in re.split(r"[,，\s]+", line):
            if not part:
                continue
            if part.isdigit():
                seats.append(part.zfill(2))
            elif re.match(r"^\d{1,3}$", part):
                seats.append(part.zfill(2))
    # unique preserve order
    seen = set()
    out: list[str] = []
    for s in seats:
        if s not in seen:
            seen.add(s)
            out.append(s)
    return out


def ensure_print_seat_template(work_dir: Path) -> Path:
    print_dir = work_dir / "列印專用"
    print_dir.mkdir(parents=True, exist_ok=True)
    path = print_dir / "需列印座號.txt"
    if not path.exists():
        path.write_text(
            "# 沒有手機／平板等通訊裝置、需要紙本練習的座號\n"
            "# 一行一個，或用逗號分隔，例如：\n"
            "# 03\n"
            "# 07, 12, 18\n"
            "\n",
            encoding="utf-8",
        )
    return path


def build_digital_pack(work_dir: Path, student: str = "") -> Path:
    """Build mobile practice pack + LINE copy text + index. Prefer digital over paper."""
    out_dir = work_dir / "輸出"
    digital_dir = work_dir / "數位練習"
    digital_dir.mkdir(parents=True, exist_ok=True)
    ensure_print_seat_template(work_dir)

    md_files = sorted(out_dir.glob("*-註記.md"))
    if student:
        md_files = [p for p in md_files if p.name.startswith(student + "-")]

    rows: list[str] = []
    line_msgs: list[str] = [
        "【數學自學練習｜數位發放】",
        "有通訊裝置的同學：請開啟對應座號的「練習題」檔，做完再看「解答」。",
        "沒有裝置的同學：跟老師領紙本（僅列印這些座號）。",
        "",
    ]
    index_items: list[str] = []

    for md in md_files:
        sid = md.name.replace("-註記.md", "")
        has_q, has_a = write_digital_practice_for_student(md, digital_dir)
        if not has_q and not has_a:
            continue
        q_name = f"{sid}-練習題.html"
        a_name = f"{sid}-練習解答.html"
        rows.append(f"- 座號 {sid}：{q_name}" + (f" ／ {a_name}" if has_a else ""))
        index_items.append(
            f'<li><strong>座號 {sid}</strong>：'
            f'<a href="{_esc(q_name)}">練習題</a>'
            + (f'　｜　<a href="{_esc(a_name)}">解答（做完再看）</a>' if has_a else "")
            + "</li>"
        )
        msg = (
            f"【數學練習｜座號{sid}】\n"
            f"請先開啟「{q_name}」做完練習。\n"
            + (f"解答：「{a_name}」（全部做完再打開）\n" if has_a else "")
            + "沒有手機／平板請向老師領紙本。"
        )
        line_msgs.append(msg)
        line_msgs.append("---")
        (digital_dir / f"{sid}-LINE訊息.txt").write_text(msg + "\n", encoding="utf-8")

    guide = (
        "數位練習發放說明（省紙）\n"
        "====================\n"
        "1. 有通訊裝置：把本資料夾放到雲端（Google 雲端／OneDrive）或用 LINE 傳個別 html／txt。\n"
        "2. 學生先開「座號-練習題」，做完再開「座號-練習解答」。\n"
        "3. 也可傳「座號-LINE訊息.txt」內容給家長／學生。\n"
        "4. 沒有裝置：在「列印專用\\需列印座號.txt」填座號，再按程式「無裝置列印包」只印那些人。\n"
        "5. 老師批閱註記 PDF 仍在「輸出」；練習題預設不整班列印。\n"
    )
    (digital_dir / "發放說明.txt").write_text(guide, encoding="utf-8")
    (digital_dir / "LINE發放文案.txt").write_text("\n".join(line_msgs) + "\n", encoding="utf-8")
    (digital_dir / "清單.md").write_text(
        "# 數位練習清單\n\n" + ("\n".join(rows) if rows else "- （尚無練習內容）") + "\n",
        encoding="utf-8",
    )

    index_html = f"""<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>數位練習總表</title>
<style>
  body {{ font-family: "Microsoft JhengHei", sans-serif; margin: 16px; background: #f7f4ef; color: #222; }}
  h1 {{ color: #143d2e; }}
  li {{ margin: 10px 0; font-size: 1.05rem; }}
  a {{ color: #1a5f3f; }}
  .box {{ background: #e7f2ea; padding: 12px; border-radius: 6px; }}
</style>
</head>
<body>
<h1>數位練習總表（手機可開）</h1>
<p class="box">有裝置→看練習題／解答。沒裝置→跟老師領「列印專用」紙本。</p>
<ul>
{chr(10).join(index_items) if index_items else "<li>（尚無練習）</li>"}
</ul>
</body>
</html>
"""
    (digital_dir / "index.html").write_text(index_html, encoding="utf-8")
    return digital_dir


def build_print_pack(work_dir: Path) -> tuple[Path, list[str]]:
    """Generate practice PDFs only for seats listed in 需列印座號.txt."""
    ensure_print_seat_template(work_dir)
    seats = parse_print_seat_list(work_dir)
    print_dir = work_dir / "列印專用"
    out_dir = work_dir / "輸出"
    # clear old practice pdfs in print dir (keep 需列印座號.txt)
    for old in print_dir.glob("*-練習*.pdf"):
        old.unlink(missing_ok=True)

    made: list[str] = []
    for sid in seats:
        md = out_dir / f"{sid}-註記.md"
        if not md.exists():
            continue
        write_print_practice_pdfs(md, print_dir)
        made.append(sid)
    return print_dir, made


def write_note_pdf(md_path: Path, pdf_path: Path, split_practice: bool = True) -> None:
    font = register_font()
    text = md_path.read_text(encoding="utf-8")
    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=A4,
        leftMargin=1.8 * cm,
        rightMargin=1.8 * cm,
        topMargin=1.6 * cm,
        bottomMargin=1.6 * cm,
    )
    doc.build(md_to_flowables(text, font))

    if not split_practice:
        return

    # Digital-first: phone HTML in 數位練習（不預設整班列印練習 PDF）
    digital_dir = md_path.parent.parent / "數位練習"
    write_digital_practice_for_student(md_path, digital_dir)


def merge_original_then_note(original: Path, note_pdf: Path, out_pdf: Path) -> None:
    writer = PdfWriter()
    if original.exists() and original.suffix.lower() == ".pdf":
        reader = PdfReader(str(original))
        for page in reader.pages:
            writer.add_page(page)
    note = PdfReader(str(note_pdf))
    for page in note.pages:
        writer.add_page(page)
    out_pdf.parent.mkdir(parents=True, exist_ok=True)
    with out_pdf.open("wb") as f:
        writer.write(f)


def parse_unclear_from_md(md_text: str, student_id: str, source: str) -> list[dict]:
    """Extract lines containing ? or 存疑 as unclear items."""
    items = []
    section = ""
    if "## 題號註記" in md_text:
        section = md_text.split("## 題號註記", 1)[1]
        if "## " in section:
            section = section.split("## ", 1)[0]
    for line in section.splitlines():
        line = line.strip()
        if not line:
            continue
        if ("?" in line) or ("？" in line) or ("存疑" in line):
            m = re.match(r"^(\d+)\s*", line)
            q = m.group(1) if m else ""
            items.append(
                {
                    "studentId": student_id,
                    "source": source,
                    "question": q,
                    "note": line.lstrip("- ").strip(),
                }
            )
    return items


def build_unclear_list(out_dir: Path) -> Path:
    rows = ["座號,來源檔,題號,存疑說明,建議老師處理"]
    md_lines = [
        "# 全班存疑清單（初核後｜待人工輔助）",
        "",
        "全班試卷檢閱後，下列項目需要老師辨認學生寫了什麼，或提供重謄掃描 PDF。",
        "",
        "處理方式：",
        "1. 看懂後：在 `認知輸入\\座號-Qn.txt` 寫入你確認的內容",
        "2. 或把重謄掃描放到 `重謄補充\\座號-Qn.pdf`（或 `座號-重謄.pdf`）",
        "3. 再跑一次補註／重產 PDF",
        "",
    ]
    for md in sorted(out_dir.glob("*-註記.md")):
        sid = md.name.replace("-註記.md", "")
        text = md.read_text(encoding="utf-8")
        source = ""
        m = re.search(r"來源檔[：:]\s*(.+)", text)
        if m:
            source = m.group(1).strip()
        unclear = parse_unclear_from_md(text, sid, source)
        for u in unclear:
            rows.append(
                f"{u['studentId']},{u['source']},{u['question']},{u['note'].replace(',', '，')},認知輸入或重謄PDF"
            )
            md_lines.append(
                f"- **座號 {u['studentId']}**｜題 {u['question'] or '？'}｜{u['note']}｜來源 `{u['source']}`"
            )
    if len(rows) == 1:
        md_lines.append("（目前沒有標 ?／存疑 的項目）")

    csv_path = out_dir / "全班存疑清單.csv"
    md_path = out_dir / "全班存疑清單.md"
    csv_path.write_text("\n".join(rows) + "\n", encoding="utf-8-sig")
    md_path.write_text("\n".join(md_lines) + "\n", encoding="utf-8")
    return md_path


def _field(text: str, key: str) -> str:
    m = re.search(rf"(?m)^- {re.escape(key)}[：:]\s*(.+)$", text)
    return m.group(1).strip() if m else ""


def _section(text: str, heading: str) -> str:
    marker = f"## {heading}"
    if marker not in text:
        return ""
    block = text.split(marker, 1)[1]
    if "\n## " in block:
        block = block.split("\n## ", 1)[0]
    return block.strip()


def build_class_learning_report(out_dir: Path) -> Path:
    """Summarize class math learning for mentors/parents after teacher review."""
    from collections import Counter
    from datetime import datetime

    students = []
    for md in sorted(out_dir.glob("*-註記.md")):
        sid = md.name.replace("-註記.md", "")
        text = md.read_text(encoding="utf-8")
        students.append(
            {
                "id": _field(text, "座號") or sid,
                "overall": _field(text, "總評") or "未批",
                "level": _field(text, "程度") or "待判定",
                "diagnosis": _section(text, "個別診斷結果") or _section(text, "個別建議"),
                "summary": _section(text, "對錯摘要"),
                "has_unclear": ("?" in text) or ("？" in text) or ("存疑" in text),
            }
        )

    n = len(students)
    level_counts = Counter(s["level"] for s in students)
    overall_counts = Counter(s["overall"] for s in students)

    # simple keyword themes from diagnosis/summary
    themes = Counter()
    keys = [
        ("計算", ["計算", "粗心", "運算"]),
        ("觀念", ["觀念", "概念", "公式", "理解"]),
        ("審題", ["審題", "題意", "看錯", "單位"]),
        ("先備不足", ["先備", "基礎", "跟不上", "落後", "不會"]),
        ("表達／書寫", ["潦草", "看不清", "書寫", "步驟"]),
    ]
    for s in students:
        blob = f"{s['diagnosis']}\n{s['summary']}"
        for label, words in keys:
            if any(w in blob for w in words):
                themes[label] += 1

    def pct(c: int) -> str:
        return f"{c} 人（{(c / n * 100):.0f}%）" if n else "0 人"

    lines = [
        "# 全班數學學習狀況總表",
        "",
        f"- 產出時間：{datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"- 已有註記人數：{n}",
        "- 說明：本表依「Cursor 初核＋老師確認」後的個別註記彙整，供**導師／家長**了解全班概況；個別成績仍以老師終核為準。",
        "- 隱私：表內以**座號**呈現，不含姓名。",
        "",
        "## 一、程度分布",
        "",
        "| 程度 | 人數 |",
        "|------|------|",
    ]
    for lv in ["跟上", "略落後", "明顯落後", "需補先備", "待判定"]:
        if level_counts.get(lv, 0) or lv != "待判定":
            lines.append(f"| {lv} | {pct(level_counts.get(lv, 0))} |")
    for lv, c in sorted(level_counts.items()):
        if lv not in {"跟上", "略落後", "明顯落後", "需補先備", "待判定"}:
            lines.append(f"| {lv} | {pct(c)} |")

    lines += ["", "## 二、總評分布", ""]
    for k, c in overall_counts.most_common():
        lines.append(f"- {k}：{pct(c)}")

    lines += ["", "## 三、常見學習課題（依註記關鍵詞粗分）", ""]
    if themes:
        for k, c in themes.most_common():
            lines.append(f"- {k}：約 {c} 人的註記有相關描述")
    else:
        lines.append("- （註記中尚無足夠文字可歸納，建議補上診斷結果後再產一次）")

    focus = [s for s in students if s["level"] in ("明顯落後", "需補先備") or s["overall"] == "需補救"]
    lines += ["", "## 四、需優先關注（座號）", ""]
    if focus:
        for s in focus:
            short = (s["diagnosis"] or s["summary"] or "（見個別註記）").replace("\n", " ")
            if len(short) > 80:
                short = short[:80] + "…"
            lines.append(f"- 座號 **{s['id']}**：程度 {s['level']}／總評 {s['overall']}｜{short}")
    else:
        lines.append("- （目前沒有標為明顯落後／需補先備／需補救者）")

    unclear = [s for s in students if s["has_unclear"]]
    lines += ["", "## 五、仍有存疑題（待最終確認）", ""]
    if unclear:
        lines.append("座號：" + "、".join(s["id"] for s in unclear))
        lines.append("（細節見「全班存疑清單」）")
    else:
        lines.append("- 無（或存疑已清除）")

    lines += [
        "",
        "## 六、逐座號一覽",
        "",
        "| 座號 | 程度 | 總評 | 診斷摘要 |",
        "|------|------|------|----------|",
    ]
    for s in students:
        short = (s["diagnosis"] or s["summary"] or "—").replace("\n", " ").replace("|", "/")
        if len(short) > 60:
            short = short[:60] + "…"
        lines.append(f"| {s['id']} | {s['level']} | {s['overall']} | {short} |")

    lines += [
        "",
        "## 七、給導師／家長的閱讀建議",
        "",
        "1. 先看「程度分布」與「需優先關注」，掌握全班與個別落差。",
        "2. 個別練習優先用通訊裝置看「數位練習」資料夾（練習題 → 做完再看解答）。",
        "3. 沒有裝置的學生，由老師依「列印專用／需列印座號」印紙本即可，避免整班列印。",
        "4. 「跟上」學生練習含再提升挑戰，鼓勵多做靈活／挑戰題，勿只重複簡單題。",
        "5. 明顯落後／需補先備：採「多次補齊」—每次少量、先有成就，再漸次跟上；避免一次補完或連催多輪。",
        "6. 本表為學習狀況溝通用，非正式成績單。",
        "",
    ]

    md_path = out_dir / "全班學習狀況總表.md"
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # CSV for mentors
    csv_lines = ["座號,程度,總評,診斷摘要"]
    for s in students:
        short = (s["diagnosis"] or s["summary"] or "").replace("\n", " ").replace(",", "，")
        csv_lines.append(f"{s['id']},{s['level']},{s['overall']},{short}")
    csv_path = out_dir / "全班學習狀況總表.csv"
    csv_path.write_text("\n".join(csv_lines) + "\n", encoding="utf-8-sig")

    # PDF
    pdf_path = out_dir / "全班學習狀況總表.pdf"
    write_note_pdf(md_path, pdf_path, split_practice=False)

    return md_path



# ----- 練習回傳閉環：批閱 → 針對回饋 → 調題再練 → 分數進步 -----

RETURN_EXTS = {".pdf", ".png", ".jpg", ".jpeg", ".tif", ".tiff", ".bmp", ".webp"}


def history_path(work_dir: Path, sid: str) -> Path:
    return work_dir / "練習歷程" / f"{sid}-歷程.json"


def load_history(work_dir: Path, sid: str) -> dict:
    p = history_path(work_dir, sid)
    if p.exists():
        try:
            return normalize_history(json.loads(p.read_text(encoding="utf-8")), sid)
        except Exception:
            pass
    data = {
        "studentId": sid,
        "goal": "針對問題點練到穩定掌握（建議正確率達目標分數）",
        "targetScore": 80,
        "weeklyCap": 2,
        "openGaps": [],
        "closedGaps": [],
        "stageGraduated": False,
        "stageNote": "",
        "errorTagCounts": {},
        "attempts": [],
        "largeText": True,
    }
    return data



def normalize_history(data: dict, sid: str = "") -> dict:
    if not isinstance(data, dict):
        data = {}
    sid = str(data.get("studentId") or sid or "00").zfill(2)
    data["studentId"] = sid
    data.setdefault("goal", "針對問題點練到穩定掌握")
    data.setdefault("targetScore", 80)
    data.setdefault("weeklyCap", 2)
    data.setdefault("openGaps", [])
    data.setdefault("closedGaps", [])
    data.setdefault("stageGraduated", False)
    data.setdefault("stageNote", "")
    data.setdefault("errorTagCounts", {})
    data.setdefault("attempts", [])
    data.setdefault("largeText", True)
    return data


def save_history(work_dir: Path, data: dict) -> Path:
    data = normalize_history(data)
    sid = str(data.get("studentId", "00")).zfill(2)
    p = history_path(work_dir, sid)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return p


def parse_return_round(stem: str, sid: str) -> int | None:
    """Parse round from 05-R01 / 05-第2次 / 05_3 / 05-2."""
    s = stem
    if sid and s.startswith(sid):
        s = s[len(sid) :]
    s = s.lstrip("-_")
    m = re.search(r"[Rr]0*(\d+)", s)
    if m:
        return int(m.group(1))
    m = re.search(r"第\s*(\d+)\s*次", s)
    if m:
        return int(m.group(1))
    m = re.fullmatch(r"(\d+)", s)
    if m:
        return int(m.group(1))
    return None


def list_return_files(work_dir: Path, sid: str = "") -> list[dict]:
    ret = work_dir / "練習回傳"
    ret.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    for p in sorted(ret.iterdir()):
        if not p.is_file() or p.suffix.lower() not in RETURN_EXTS:
            continue
        file_sid = None
        m = re.match(r"^(\d{1,3})", p.stem)
        if m:
            file_sid = m.group(1).zfill(2)
        if sid and file_sid != sid.zfill(2):
            continue
        rnd = parse_return_round(p.stem, file_sid or "") if file_sid else None
        rows.append({"studentId": file_sid or "", "round": rnd, "path": p, "name": p.name})
    return rows


def next_return_round(work_dir: Path, sid: str) -> int:
    hist = load_history(work_dir, sid)
    used = {int(a.get("round", 0)) for a in hist.get("attempts", [])}
    for r in list_return_files(work_dir, sid):
        if r["round"]:
            used.add(int(r["round"]))
    n = 1
    while n in used:
        n += 1
    return n


def progress_text_table(data: dict) -> str:
    lines = ["| 次數 | 分數 | 百分比 | 問題點摘要 |", "|------|------|--------|------------|"]
    for a in data.get("attempts", []):
        pp = (a.get("problemPoints") or "—").replace("\n", " ")
        if len(pp) > 40:
            pp = pp[:40] + "…"
        lines.append(
            f"| R{int(a.get('round', 0)):02d} | {a.get('score')}/{a.get('maxScore')} | "
            f"{a.get('percent')}% | {pp} |"
        )
    if len(data.get("attempts", [])) >= 2:
        first = data["attempts"][0].get("percent") or 0
        last = data["attempts"][-1].get("percent") or 0
        delta = round(float(last) - float(first), 1)
        sign = "+" if delta >= 0 else ""
        lines.append("")
        lines.append(f"進步幅度（首次→最近）：{sign}{delta} 百分點")
    return "\n".join(lines)


def write_progress_html(work_dir: Path, sid: str) -> Path:
    data = load_history(work_dir, sid)
    target = float(data.get("targetScore") or 80)
    bars = []
    for a in data.get("attempts", []):
        pct = float(a.get("percent") or 0)
        w = max(0, min(100, pct))
        color = "#2a7a4b" if pct >= target else "#c97820"
        bars.append(
            f"<div class='row'><span class='lab'>R{int(a.get('round', 0)):02d}</span>"
            f"<div class='bar'><i style='width:{w}%;background:{color}'></i></div>"
            f"<span class='pct'>{pct}%（{a.get('score')}/{a.get('maxScore')}）</span></div>"
            f"<p class='pp'><strong>問題點：</strong>{_esc(a.get('problemPoints') or '—')}</p>"
            f"<p class='fb'>{_esc(a.get('feedback') or '')}</p>"
        )
    delta_note = ""
    atts = data.get("attempts") or []
    if len(atts) >= 2:
        delta = round(float(atts[-1].get("percent") or 0) - float(atts[0].get("percent") or 0), 1)
        sign = "+" if delta >= 0 else ""
        delta_note = f"<p class='delta'>進步幅度（首次→最近）：<strong>{sign}{delta}</strong> 百分點</p>"

    latest = atts[-1] if atts else None
    if latest and latest.get("goalMet"):
        status = "本階段成功（有成就）／可維持或下次再補下一點"
    else:
        status = "本次尚未達小目標 → 下次再小步補齊（多次補齊，不急一次追上）"
    html = f"""<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>座號 {sid} 練習歷程</title>
<style>
  body {{ font-family: "Microsoft JhengHei", sans-serif; margin: 16px; background: #f7f4ef; color: #222; }}
  h1 {{ color: #143d2e; font-size: 1.3rem; }}
  .goal {{ background: #e7f2ea; padding: 10px 12px; border-radius: 6px; }}
  .row {{ display: flex; align-items: center; gap: 8px; margin: 10px 0 4px; }}
  .lab {{ width: 2.4rem; font-weight: 700; }}
  .bar {{ flex: 1; height: 14px; background: #ddd; border-radius: 7px; overflow: hidden; }}
  .bar i {{ display: block; height: 100%; }}
  .pct {{ width: 7.5rem; font-size: 0.9rem; }}
  .pp, .fb {{ margin: 0 0 12px; font-size: 0.95rem; }}
  .delta {{ color: #1a5f3f; }}
</style>
</head>
<body>
<h1>座號 {sid}｜練習回饋與分數進步</h1>
<p class="goal"><strong>學習目標：</strong>{_esc(data.get('goal') or '')}<br>
<strong>目標分數：</strong>{target}%　｜　<strong>狀態：</strong>{_esc(status)}</p>
{delta_note}
{''.join(bars) if bars else '<p>（尚無回傳批閱紀錄）</p>'}
<p style="color:#666;font-size:0.85rem">落後生採「多次補齊」：每次小量、先看見成就，再漸次跟上；不必一次補完。</p>
</body>
</html>
"""
    out = work_dir / "練習歷程" / f"{sid}-歷程.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    dig = work_dir / "數位練習"
    dig.mkdir(parents=True, exist_ok=True)
    (dig / f"{sid}-歷程.html").write_text(html, encoding="utf-8")
    return out


def publish_next_practice(work_dir: Path, sid: str, practice: str, after_round: int) -> None:
    dig = work_dir / "數位練習"
    dig.mkdir(parents=True, exist_ok=True)
    fake = "## 依程度自學／補救練習\n" + practice
    q, a = split_practice_questions_answers(fake)
    if not q.strip():
        q = practice
    title_q = f"座號 {sid}｜第 {after_round + 1} 輪練習題（依上回問題點調整）"
    write_mobile_html(title_q, q, dig / f"{sid}-練習題.html", is_answer=False)
    (dig / f"{sid}-練習題.txt").write_text(f"{title_q}\n\n{q}\n", encoding="utf-8")
    if a.strip():
        write_mobile_html(
            f"座號 {sid}｜第 {after_round + 1} 輪解答（做完再看）",
            a,
            dig / f"{sid}-練習解答.html",
            is_answer=True,
        )
    msg = (
        f"【數學練習｜座號{sid}｜第{after_round + 1}輪】\n"
        f"這輪依你上一輪問題點調整題目。\n"
        f"請先開「{sid}-練習題.html」做完，再看解答。\n"
        f"也可看「{sid}-歷程.html」了解分數進步。\n"
        f"做完請回傳 PDF 或圖檔，檔名：{sid}-R{after_round + 1:02d}.jpg（或 .pdf）"
    )
    (dig / f"{sid}-LINE訊息.txt").write_text(msg + "\n", encoding="utf-8")


def publish_goal_met(work_dir: Path, sid: str, attempt: dict) -> None:
    dig = work_dir / "數位練習"
    dig.mkdir(parents=True, exist_ok=True)
    body = (
        f"本輪分數 {attempt.get('percent')}%，已達學習目標。\n\n"
        f"問題點回顧：\n{attempt.get('problemPoints') or '—'}\n\n"
        "可選做伸展挑戰，或等待下一單元。請看歷程頁了解進步。"
    )
    write_mobile_html(
        f"座號 {sid}｜已達標（可選伸展）",
        body,
        dig / f"{sid}-練習題.html",
        is_answer=False,
    )
    msg = (
        f"【數學練習｜座號{sid}】已達標（{attempt.get('percent')}%）\n"
        f"請看「{sid}-歷程.html」的分數進步。若想挑戰可再跟老師要伸展題。"
    )
    (dig / f"{sid}-LINE訊息.txt").write_text(msg + "\n", encoding="utf-8")


def append_attempt(
    work_dir: Path,
    sid: str,
    *,
    round_no: int,
    source_file: str,
    score: float,
    max_score: float,
    problem_points: str,
    feedback: str,
    next_practice: str,
    goal: str = "",
    target_score: float | None = None,
    goal_met: bool | None = None,
) -> dict:
    data = load_history(work_dir, sid)
    if goal:
        data["goal"] = goal
    if target_score is not None:
        data["targetScore"] = target_score
    pct = round(100.0 * score / max_score, 1) if max_score else 0.0
    target = float(data.get("targetScore") or 80)
    if goal_met is None:
        goal_met = pct >= target
    attempt = {
        "round": int(round_no),
        "file": source_file,
        "score": score,
        "maxScore": max_score,
        "percent": pct,
        "problemPoints": problem_points.strip(),
        "feedback": feedback.strip(),
        "nextPractice": next_practice.strip(),
        "goalMet": bool(goal_met),
        "time": datetime.now().strftime("%Y-%m-%d %H:%M"),
    }
    attempts = [a for a in data.get("attempts", []) if int(a.get("round", -1)) != int(round_no)]
    attempts.append(attempt)
    attempts.sort(key=lambda a: int(a.get("round", 0)))
    data["attempts"] = attempts
    save_history(work_dir, data)

    hist_dir = work_dir / "練習歷程"
    hist_dir.mkdir(parents=True, exist_ok=True)
    md = hist_dir / f"{sid}-回饋-R{int(round_no):02d}.md"
    md.write_text(
        "\n".join(
            [
                f"# 練習回饋｜座號 {sid}｜第 {round_no} 次",
                "",
                f"- 回傳檔：{source_file}",
                f"- 分數：{score}/{max_score}（{pct}%）",
                f"- 目標：{data.get('goal', '')}（目標分數 {target}）",
                f"- 是否達成目標：{'是' if goal_met else '否（請依下一輪練習再練）'}",
                f"- 時間：{attempt['time']}",
                "",
                "## 問題點（本輪針對說明）",
                problem_points.strip() or "（無）",
                "",
                "## 回饋說明",
                feedback.strip() or "（無）",
                "",
                "## 分數進步",
                progress_text_table(data),
                "",
                "## 下一輪適切練習（達標前繼續）",
                next_practice.strip() or "（已達標或尚未擬定）",
                "",
            ]
        ),
        encoding="utf-8",
    )

    write_progress_html(work_dir, sid)
    if next_practice.strip() and not goal_met:
        publish_next_practice(work_dir, sid, next_practice.strip(), round_no)
    elif goal_met:
        publish_goal_met(work_dir, sid, attempt)

    return data


def write_return_guide(work_dir: Path) -> Path:
    path = work_dir / "數位發放與回傳說明.txt"
    text = """數位發放／回傳路徑建議（方便、可抓取批閱）
========================================

【先講清楚：LINE 群組還是？】
- 發放／公告：用「LINE 班級群組」最方便（貼連結或練習說明）。
- 回傳作業圖／PDF：請用「LINE 個別傳老師」，或 Classroom／雲端回傳夾。
  不要讓全班把照片塞進群組（洗版、難對座號、難批次抓取）。

【常用組合】
A) 快又省事（多數班級）
   發：LINE 班級群組　＋　回：LINE 個別傳老師 → 另存到「練習回傳\\05-R01.jpg」
B) 長期整齊
   發＋回：Google Classroom（下載繳交檔進「練習回傳」）
C) 雲端兩夾
   發放夾給學生看、回傳夾上傳；同步到本機「練習回傳」
D) （可不用）均一：預設改由 Cursor 自產練習＋指導＋影片連結

【其他】
- 學校 LMS／email：最後一樣匯入「練習回傳」即可被批閱程式抓取
- 沒有裝置：只印「列印專用\\需列印座號」那些人
- 練習來源：Cursor 批閱時自動產生題目、自學指導、YouTube 搜尋／影片連結（不用均一）

【閉環】
發練習 → 回傳 PDF/圖 → 批閱（Cursor／人工）→
針對問題點回饋＋分數 → 調下一輪題 → 再練 → 達標；
每次回饋含分數進步（練習歷程）

【回傳檔名】
05-R01.pdf / 05-R02.jpg / 05-第1次.png 皆可

程式內可按「工具選擇」勾選／改偏好，隨時換組合。
"""
    path.write_text(text, encoding="utf-8")
    write_junyi_guide(work_dir)
    return path


def write_junyi_guide(work_dir: Path) -> Path:
    path = work_dir / "均一結合說明.txt"
    text = """如何結合「均一教育平台」與本批改工具
========================================

【重要限制】
均一「指派任務」目前無法由本程式自動完成（無開放一鍵代點）。
本程式能做的是：依批閱結果「自動產出均一指派清單」，你只要打開均一對照點選；
同一任務可用「任務代碼」複製到其他班級，減少重複設定。

【一句話分工】
- 均一：線上影片／習題／熟練度、差異化指派、分析報告（指派＝手動）
- 本程式：紙本試卷批閱、手寫回傳、多次補齊、成長歷程；並產出「均一指派清單」

兩者互補，不要兩套都叫學生交同一份作業兩次。

【建議流程（半自動）】
1) 本程式批完試卷 → 按「均一指派清單」
2) 打開 `練習歷程\\均一指派清單.md`（已依座號／問題點排好）
3) 到均一「教學管理 → 指派任務」依清單逐項點選（落後生每次 1 個技能）
4) 第一次指派後複製「任務代碼」，其他班可貼代碼重用
5) 學生在均一線上練；手寫過程若要看，再回傳本程式

【帳號與班級】
- 老師建立班級、學生加入
- 多班：任務代碼重複指派（這是均一端最省事的「半自動」）
說明：https://help.junyiacademy.org/home/mission_report/
教師資源：https://www.junyiacademy.org/topics/junyi-teacher-resources

【不要這樣做】
- 期待本程式直接登入均一代你指派（目前做不到）
- 同一題又叫均一交、又叫拍照交兩次
- 落後生一次指派大量均一任務
"""
    path.write_text(text, encoding="utf-8")
    ensure_junyi_skill_map(work_dir)
    return path


def ensure_junyi_skill_map(work_dir: Path) -> Path:
    """Editable mapping: error tag / gap keyword → junyi skill hint (teacher fills)."""
    path = work_dir / "均一技能對照.txt"
    if path.exists():
        return path
    path.write_text(
        "# 均一技能對照（請依本班教材自行填寫；一行一組）\n"
        "# 格式：關鍵詞 = 均一技能或影片名稱（或備註）\n"
        "# 本程式產出「均一指派清單」時會依關鍵詞帶出建議\n"
        "\n"
        "進位 = （請填均一技能名）\n"
        "退位 = （請填均一技能名）\n"
        "分數 = （請填均一技能名）\n"
        "小數 = （請填均一技能名）\n"
        "面積 = （請填均一技能名）\n"
        "單位 = （請填均一技能名）\n"
        "先備 = （請填前一單元基礎技能）\n"
        "計算 = （請填計算類技能）\n"
        "審題 = （建議少題精練＋手寫回饋，均一可選基礎題）\n"
        "粗心 = （建議手寫驗算；均一可選同技能少量）\n"
        "跟上 = （請填進階／挑戰技能）\n"
        "\n",
        encoding="utf-8",
    )
    return path


def load_junyi_skill_map(work_dir: Path) -> dict[str, str]:
    ensure_junyi_skill_map(work_dir)
    path = work_dir / "均一技能對照.txt"
    mp: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k, v = k.strip(), v.strip()
        if k and v and not v.startswith("（請填"):
            mp[k] = v
    return mp


def suggest_junyi_skills(keywords: list[str], skill_map: dict[str, str]) -> list[str]:
    hits = []
    for kw in keywords:
        for mk, mv in skill_map.items():
            if mk in kw or kw in mk:
                item = f"{mk} → {mv}"
                if item not in hits:
                    hits.append(item)
    return hits


def build_junyi_assign_list(work_dir: Path) -> Path:
    """Auto checklist for manual junyi assignment (cannot click junyi for you)."""
    out_dir = work_dir / "輸出"
    hist_dir = work_dir / "練習歷程"
    hist_dir.mkdir(parents=True, exist_ok=True)
    skill_map = load_junyi_skill_map(work_dir)
    write_junyi_guide(work_dir)

    lines = [
        "# 均一指派清單（自動產生｜指派仍須在均一手動點）",
        "",
        "> 均一無法由本程式自動指派。此清單把「誰、補什麼」整理好，你到均一對照點選即可。",
        "> 同一任務可用「任務代碼」複製到他班。技能名稱請維護 `均一技能對照.txt`。",
        "",
        "## 操作步驟",
        "1. 打開均一 → 教學管理 → 指派任務",
        "2. 依下方座號：落後生每次只指派 **1** 個建議技能（多次補齊）",
        "3. 跟上生可指派挑戰技能（選做）",
        "4. 指派後可把任務代碼記在本檔最下方",
        "",
        "## 逐座號建議",
        "",
    ]

    sids = set()
    for p in out_dir.glob("*-註記.md"):
        sids.add(p.name.replace("-註記.md", ""))
    for p in hist_dir.glob("*-歷程.json"):
        sids.add(p.name.replace("-歷程.json", ""))

    if not sids:
        lines.append("- （尚無批閱註記／歷程，請先批改學生）")
    else:
        for sid in sorted(sids):
            level, diagnosis, practice_hint = "待判定", "", ""
            note = out_dir / f"{sid}-註記.md"
            if note.exists():
                text = note.read_text(encoding="utf-8")
                m = re.search(r"(?m)^- 程度[：:]\s*(.+)$", text)
                if m:
                    level = m.group(1).strip()
                if "## 個別診斷結果" in text:
                    diagnosis = text.split("## 個別診斷結果", 1)[1]
                    if "\n## " in diagnosis:
                        diagnosis = diagnosis.split("\n## ", 1)[0]
                    diagnosis = diagnosis.strip().replace("\n", " ")[:120]
            hist = load_history(work_dir, sid)
            gaps = list(hist.get("openGaps") or [])
            tags = list((hist.get("errorTagCounts") or {}).keys())
            # also pull latest attempt problem points
            atts = hist.get("attempts") or []
            if atts:
                pp = str(atts[-1].get("problemPoints") or "")
                if pp:
                    gaps = gaps or [pp[:40]]
            keywords = gaps + tags + ([diagnosis] if diagnosis else []) + [level]
            flat_kw = []
            for k in keywords:
                flat_kw.extend(re.split(r"[,，、/\s]+", str(k)))
            flat_kw = [x for x in flat_kw if x]
            suggestions = suggest_junyi_skills(flat_kw, skill_map)
            if not suggestions:
                if "跟上" in level:
                    suggestions = ["（請在均一選本單元進階／挑戰技能；並填入均一技能對照.txt）"]
                elif level in ("明顯落後", "需補先備"):
                    suggestions = ["（請在均一選 1 個先備／基礎技能；並填入均一技能對照.txt）"]
                else:
                    suggestions = ["（依問題點在均一搜尋對應技能；建議維護均一技能對照.txt）"]

            pace = (
                "每次只指派 1 個｜多次補齊"
                if level in ("明顯落後", "需補先備", "略落後")
                else "可指派挑戰／延伸（選做）"
            )
            lines.append(f"### 座號 {sid}｜{level}｜{pace}")
            if gaps:
                lines.append("- 未補齊／焦點：" + "、".join(str(g) for g in gaps[:5]))
            if tags:
                lines.append("- 錯誤類型：" + "、".join(tags[:8]))
            if diagnosis:
                lines.append(f"- 診斷摘要：{diagnosis}")
            lines.append("- 均一建議指派：")
            for s in suggestions[:4]:
                lines.append(f"  - [ ] {s}")
            lines.append("")

    lines += [
        "## 任務代碼備忘（手動貼上）",
        "",
        "| 用途 | 任務代碼 | 期限 | 備註 |",
        "|------|----------|------|------|",
        "| 本週基礎 |  |  |  |",
        "| 本週挑戰 |  |  |  |",
        "| 先備補齊 |  |  |  |",
        "",
        "產生時間可重跑「均一指派清單」更新。",
        "",
    ]
    out = hist_dir / "均一指派清單.md"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    # also copy short LINE announcement
    ann = (
        "【數學｜均一任務】\n"
        "請依老師在均一指派的任務完成線上練習（看分析報告即可）。\n"
        "若另有手寫回傳，請個別傳老師，檔名：座號-R01.jpg。\n"
        "（均一＝線上練熟；手寫＝看過程。練習非正式成績）\n"
    )
    (hist_dir / "均一任務LINE公告.txt").write_text(ann, encoding="utf-8")
    dig = work_dir / "數位練習"
    dig.mkdir(parents=True, exist_ok=True)
    (dig / "均一任務LINE公告.txt").write_text(ann, encoding="utf-8")
    return out


def build_pending_returns_list(work_dir: Path) -> Path:
    """List return files not yet recorded in history."""
    lines = [
        "# 待批閱回傳清單",
        "",
        "把學生 PDF／圖檔放進 `練習回傳\\`（檔名：座號-R01.pdf）。",
        "",
    ]
    pending = []
    for r in list_return_files(work_dir):
        sid = r["studentId"]
        if not sid:
            continue
        hist = load_history(work_dir, sid)
        done_files = {str(a.get("file", "")) for a in hist.get("attempts", [])}
        done_rounds = {int(a.get("round", -1)) for a in hist.get("attempts", [])}
        if r["name"] in done_files:
            continue
        if r["round"] is not None and int(r["round"]) in done_rounds:
            continue
        pending.append(r)
        lines.append(
            f"- 座號 {sid}｜{r['name']}"
            + (f"｜建議第 {r['round']} 次" if r["round"] else "")
        )
    if not pending:
        lines.append("- （目前無待批回傳，或皆已記入歷程）")
    out = work_dir / "練習歷程" / "待批閱回傳清單.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


def apply_clarifications(work_dir: Path) -> int:
    """Append teacher clarifications / re-transcript notes into student md files."""
    out_dir = work_dir / "輸出"
    cog_dir = work_dir / "認知輸入"
    rescan_dir = work_dir / "重謄補充"
    cog_dir.mkdir(parents=True, exist_ok=True)
    rescan_dir.mkdir(parents=True, exist_ok=True)
    updated = 0

    clar_map: dict[str, list[str]] = {}

    for p in cog_dir.glob("*.txt"):
        # 05-Q3.txt or 05.txt
        stem = p.stem
        sid = stem.split("-")[0]
        body = p.read_text(encoding="utf-8").strip()
        clar_map.setdefault(sid, []).append(f"- 認知輸入（{p.name}）：{body}")

    for p in rescan_dir.glob("*.pdf"):
        stem = p.stem
        sid = stem.split("-")[0]
        clar_map.setdefault(sid, []).append(f"- 重謄掃描：`重謄補充/{p.name}`")

    for sid, bullets in clar_map.items():
        md = out_dir / f"{sid}-註記.md"
        if not md.exists():
            continue
        text = md.read_text(encoding="utf-8")
        block = "## 老師輔助辨認／重謄\n" + "\n".join(bullets) + "\n"
        if "## 老師輔助辨認／重謄" in text:
            # replace section
            pre, rest = text.split("## 老師輔助辨認／重謄", 1)
            if "## " in rest[1:]:
                _, after = rest.split("## ", 1)
                text = pre + block + "\n## " + after
            else:
                text = pre + block
        else:
            text = text.rstrip() + "\n\n" + block + "\n"
        # soften unclear marks if clarification provided
        text = text.replace("總評：存疑多", "總評：已補認知／重謄（待終核）")
        md.write_text(text, encoding="utf-8")
        updated += 1
    return updated


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work-dir", required=True, help="MathGrading work folder")
    ap.add_argument("--student", default="", help="student id e.g. 05; empty = all")
    ap.add_argument("--merge-original", action="store_true", help="original PDF + note pages")
    ap.add_argument("--unclear-list", action="store_true", help="build class unclear list")
    ap.add_argument("--class-report", action="store_true", help="build class learning report for mentors/parents")
    ap.add_argument("--digital-pack", action="store_true", help="build phone/tablet practice HTML pack")
    ap.add_argument("--print-pack", action="store_true", help="build paper PDFs only for seats in 需列印座號.txt")
    ap.add_argument("--pending-returns", action="store_true", help="list ungraded practice returns")
    ap.add_argument("--junyi-list", action="store_true", help="build manual junyi assignment checklist")
    ap.add_argument("--progress-html", action="store_true", help="rebuild progress HTML for student(s)")
    ap.add_argument("--append-attempt", action="store_true", help="append one practice-return attempt from flags")
    ap.add_argument("--attempt-json", default="", help="JSON file with attempt fields (preferred for Unicode)")
    ap.add_argument("--round", type=int, default=0, help="attempt round number")
    ap.add_argument("--score", type=float, default=-1, help="score earned")
    ap.add_argument("--max-score", type=float, default=100, help="score maximum")
    ap.add_argument("--source-file", default="", help="return filename")
    ap.add_argument("--problem-points", default="", help="problem points this round")
    ap.add_argument("--feedback", default="", help="feedback text")
    ap.add_argument("--next-practice", default="", help="next adjusted practice text")
    ap.add_argument("--goal", default="", help="learning goal")
    ap.add_argument("--target-score", type=float, default=-1, help="target percent")
    ap.add_argument("--goal-met", action="store_true", help="mark goal met")
    ap.add_argument("--goal-not-met", action="store_true", help="mark goal not met")
    ap.add_argument("--apply-clarifications", action="store_true")
    args = ap.parse_args()

    work = Path(args.work_dir)
    out_dir = work / "輸出"
    in_dir = work / "輸入"
    out_dir.mkdir(parents=True, exist_ok=True)
    (work / "認知輸入").mkdir(parents=True, exist_ok=True)
    (work / "重謄補充").mkdir(parents=True, exist_ok=True)
    (work / "數位練習").mkdir(parents=True, exist_ok=True)
    (work / "練習回傳").mkdir(parents=True, exist_ok=True)
    (work / "練習歷程").mkdir(parents=True, exist_ok=True)
    ensure_print_seat_template(work)
    write_return_guide(work)

    if args.apply_clarifications:
        n = apply_clarifications(work)
        print(f"applied clarifications to {n} students")

    if args.unclear_list:
        p = build_unclear_list(out_dir)
        print(f"unclear list: {p}")

    if args.class_report:
        p = build_class_learning_report(out_dir)
        print(f"class report: {p}")

    if args.digital_pack:
        p = build_digital_pack(work, student=args.student)
        print(f"digital pack: {p}")

    if args.print_pack:
        p, seats = build_print_pack(work)
        print(f"print pack: {p} seats={','.join(seats) if seats else '(none)'}")

    if args.pending_returns:
        p = build_pending_returns_list(work)
        print(f"pending returns: {p}")

    if args.junyi_list:
        p = build_junyi_assign_list(work)
        print(f"junyi assign list: {p}")

    if args.progress_html:
        if args.student:
            p = write_progress_html(work, args.student.zfill(2))
            print(f"progress html: {p}")
        else:
            for pjson in sorted((work / "練習歷程").glob("*-歷程.json")):
                sid = pjson.name.replace("-歷程.json", "")
                p = write_progress_html(work, sid)
                print(f"progress html: {p}")

    if args.append_attempt:
        payload = {}
        if args.attempt_json:
            payload = json.loads(Path(args.attempt_json).read_text(encoding="utf-8"))
        sid_raw = payload.get("studentId") or args.student
        if not sid_raw:
            print("append-attempt needs studentId", file=sys.stderr)
            return 2
        sid = str(sid_raw).zfill(2)
        rnd = int(payload.get("round") or args.round or next_return_round(work, sid))
        if "score" in payload:
            score = float(payload["score"])
        else:
            score = float(args.score)
        if score < 0:
            print("append-attempt needs score", file=sys.stderr)
            return 2
        max_score = float(payload.get("maxScore", args.max_score))
        goal_met = payload.get("goalMet")
        if goal_met is None:
            if args.goal_met:
                goal_met = True
            elif args.goal_not_met:
                goal_met = False
        target = payload.get("targetScore", None)
        if target is None and args.target_score >= 0:
            target = args.target_score
        data = append_attempt(
            work,
            sid,
            round_no=rnd,
            source_file=str(payload.get("sourceFile") or args.source_file or ""),
            score=score,
            max_score=max_score,
            problem_points=str(payload.get("problemPoints") or args.problem_points or ""),
            feedback=str(payload.get("feedback") or args.feedback or ""),
            next_practice=str(payload.get("nextPractice") or args.next_practice or ""),
            goal=str(payload.get("goal") or args.goal or ""),
            target_score=(float(target) if target is not None else None),
            goal_met=goal_met,
        )
        print(f"attempt saved: {sid} R{rnd:02d} attempts={len(data.get('attempts', []))}")

    # Regenerate student PDFs when merging / clarifying, or bare --student
    need_student_pdfs = bool(args.merge_original or args.apply_clarifications)
    if args.student and not any(
        [
            args.digital_pack,
            args.print_pack,
            args.class_report,
            args.unclear_list,
            args.pending_returns,
            args.junyi_list,
            args.progress_html,
            args.append_attempt,
        ]
    ):
        need_student_pdfs = True
    if not need_student_pdfs:
        return 0

    md_files = sorted(out_dir.glob("*-註記.md"))
    if args.student:
        md_files = [p for p in md_files if p.name.startswith(args.student + "-")]

    for md in md_files:
        sid = md.name.replace("-註記.md", "")
        note_pdf = out_dir / f"{sid}-批閱註記.pdf"
        write_note_pdf(md, note_pdf)
        print(f"note pdf: {note_pdf}")

        if args.merge_original:
            # find original
            original = None
            for ext in (".pdf", ".PDF", ".jpg", ".jpeg", ".png"):
                cand = in_dir / f"{sid}{ext}"
                if cand.exists():
                    original = cand
                    break
            if original is None:
                # fuzzy: starts with sid
                hits = list(in_dir.glob(f"{sid}.*")) + list(in_dir.glob(f"{int(sid):d}.*"))
                original = hits[0] if hits else None
            merged = out_dir / f"{sid}-試卷含批閱.pdf"
            if original and original.suffix.lower() == ".pdf":
                merge_original_then_note(original, note_pdf, merged)
                print(f"merged: {merged}")
            else:
                # image-only: just copy note pdf as final deliverable name
                merged.write_bytes(note_pdf.read_bytes())
                print(f"merged(note-only): {merged}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
