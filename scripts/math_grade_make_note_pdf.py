#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate per-student grading note PDF; optionally append after original exam PDF."""

from __future__ import annotations

import argparse
import re
import sys
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

    # Also emit student handout: questions PDF + answers PDF (separate files)
    sid = md_path.name.replace("-註記.md", "")
    if not md_path.name.endswith("-註記.md"):
        return
    q, a = split_practice_questions_answers(text)
    out_dir = md_path.parent
    if q:
        write_simple_pdf(
            f"座號 {sid}｜自學練習題（先做完再看解答）",
            q,
            out_dir / f"{sid}-練習題.pdf",
        )
    if a:
        write_simple_pdf(
            f"座號 {sid}｜練習解答（全部題目完成後再看）",
            a,
            out_dir / f"{sid}-練習解答.pdf",
        )


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
        "2. 個別練習請看該生 `座號-練習題.pdf`（先做）與 `座號-練習解答.pdf`（做完再看）。",
        "3. 「跟上」學生練習含再提升挑戰，鼓勵多做靈活／挑戰題，勿只重複簡單題。",
        "4. 明顯落後／需補先備者，宜採少而精、先補基礎，避免只重複整卷難題。",
        "5. 本表為學習狀況溝通用，非正式成績單。",
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
    ap.add_argument("--apply-clarifications", action="store_true")
    args = ap.parse_args()

    work = Path(args.work_dir)
    out_dir = work / "輸出"
    in_dir = work / "輸入"
    out_dir.mkdir(parents=True, exist_ok=True)
    (work / "認知輸入").mkdir(parents=True, exist_ok=True)
    (work / "重謄補充").mkdir(parents=True, exist_ok=True)

    if args.apply_clarifications:
        n = apply_clarifications(work)
        print(f"applied clarifications to {n} students")

    if args.unclear_list:
        p = build_unclear_list(out_dir)
        print(f"unclear list: {p}")

    if args.class_report:
        p = build_class_learning_report(out_dir)
        print(f"class report: {p}")

    # Only regenerate student PDFs when grading / merging / clarifying a student
    need_student_pdfs = bool(args.student or args.merge_original or args.apply_clarifications)
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
