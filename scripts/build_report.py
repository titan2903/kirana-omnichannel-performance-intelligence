#!/usr/bin/env python3
"""Rakit laporan akhir UAS dari reports/*.md dan reports/B_insight_brief.pdf menjadi satu PDF:
cover + daftar isi, Bagian A (A1-A5), Bagian B (brief), Bagian C (C1), pernyataan AI, lalu Lampiran (A7, C2, registri angka).
  KIRANA_NIM=... KIRANA_NAMA="..." python3 scripts/build_report.py [--out-dir dist]
Butuh: playwright (+ Chrome sistem), markdown, pymupdf. Diagram Mermaid (A4) dirender dari CDN jsDelivr, jadi butuh internet.
Halaman utama (di luar lampiran) dicek <= 25."""
import argparse, base64, html, os, re, sys
import markdown, pymupdf
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = os.path.join(ROOT, "reports")
CHROME = os.environ.get("CHROME_PATH", "/usr/bin/google-chrome")
NIM = os.environ.get("KIRANA_NIM", "[NIM]")
NAMA = os.environ.get("KIRANA_NAMA", "[Nama Lengkap]")
MERMAID = "https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js"

PART_A = ["A1_decision_statement.md", "A2_profiling.md", "A3_issue_log.md", "A4_data_model.md", "A5_quality_reconciliation.md"]
PART_C = ["C1_memo_evaluasi.md", "D_pernyataan_ai.md"]
LAMPIRAN = ["A7_kamus_metrik.md", "C2_tata_kelola.md", "number_registry.md"]

CSS = """
@page { size: A4; margin: 15mm 13mm 16mm 13mm; }
body { font: 9.3pt/1.4 'DejaVu Sans', Arial, sans-serif; color: #1b1b1a; }
h1 { font-size: 15pt; margin: 0 0 6px; padding-bottom: 3px; border-bottom: 2px solid #2a78d6; margin-top: 16px; }
.brk h1 { page-break-before: always; margin-top: 0; } .brk h1:first-child { page-break-before: avoid; }
h1, h2, h3 { page-break-after: avoid; }
h2 { font-size: 11.5pt; margin: 14px 0 4px; } h3 { font-size: 10pt; margin: 10px 0 3px; }
table { border-collapse: collapse; width: 100%; margin: 6px 0 9px; font-size: 7.9pt; line-height: 1.3; }
th, td { border: 1px solid #c9c8c3; padding: 2.5px 4px; vertical-align: top; overflow-wrap: break-word; }
th { background: #eef1f6; text-align: left; } tr { page-break-inside: avoid; }
code { font: 7.8pt 'DejaVu Sans Mono', monospace; background: #f2f1ee; padding: 0 2px; }
pre { background: #f6f5f2; padding: 5px 7px; font-size: 7.5pt; white-space: pre-wrap; page-break-inside: avoid; }
pre code { background: none; } img { max-width: 100%; } blockquote { margin: 6px 0; padding: 3px 10px; border-left: 3px solid #2a78d6; background: #f4f7fb; }
.mermaid { text-align: center; margin: 8px 0; page-break-inside: avoid; } .mermaid svg { max-width: 100% !important; height: auto; }
.cover { height: 250mm; display: flex; flex-direction: column; justify-content: center; page-break-after: always; }
.cover h1 { font-size: 24pt; border: 0; page-break-before: avoid; } .cover .sub { font-size: 12pt; color: #444; margin-bottom: 22px; }
.cover table { font-size: 9.5pt; width: auto; } .cover td { border: 0; padding: 2px 14px 2px 0; }
.toc td, .toc th { font-size: 9.5pt; } .sec { margin-top: 18px; font-weight: bold; }
"""


def md_html(files):
    parts = []
    for i, f in enumerate(files):
        t = open(os.path.join(R, f), encoding="utf-8").read()
        t = re.sub(r"```mermaid\n(.*?)```", lambda m: f'\n<div class="mermaid">{html.escape(m.group(1))}</div>\n', t, flags=re.S)
        t = re.sub(r"!\[([^\]]*)\]\((img/[^)]+\.png)\)",  # set_content tidak boleh membuka file://, jadi gambar disematkan
                   lambda m: f'<img alt="{m.group(1)}" src="data:image/png;base64,{base64.b64encode(open(os.path.join(R, m.group(2)), "rb").read()).decode()}">', t)
        parts.append(markdown.markdown(t, extensions=["tables", "fenced_code", "sane_lists"]))
    return "\n".join(parts)


def render(pw_browser, body, out, brk=False):
    doc = f"<!doctype html><html lang='id'><head><meta charset='utf-8'><base href='file://{R}/'><style>{CSS}</style></head><body class='{'brk' if brk else ''}'>{body}</body></html>"
    p = pw_browser.new_page()
    p.set_content(doc, wait_until="load")
    n = body.count('class="mermaid"')
    if n:
        p.add_script_tag(url=MERMAID)
        p.evaluate("() => { mermaid.initialize({startOnLoad:false, theme:'neutral', flowchart:{useMaxWidth:true}, er:{useMaxWidth:true}}); return mermaid.run({querySelector:'.mermaid'}); }")
        p.wait_for_function(f"document.querySelectorAll('.mermaid svg').length >= {n}", timeout=60000)
    p.pdf(path=out, format="A4", print_background=True, margin={"top": "15mm", "bottom": "16mm", "left": "13mm", "right": "13mm"}, prefer_css_page_size=True)
    p.close()
    return len(pymupdf.open(out))


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--out-dir", default=os.path.join(ROOT, "dist")); a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)
    tmp = os.path.join(a.out_dir, ".parts"); os.makedirs(tmp, exist_ok=True)
    brief = os.path.join(R, "B_insight_brief.pdf")
    if not os.path.exists(brief):
        sys.exit("reports/B_insight_brief.pdf belum ada: jalankan python3 scripts/build_insights.py")
    with sync_playwright() as pw:
        br = pw.chromium.launch(executable_path=CHROME, args=["--no-sandbox"])
        pa = os.path.join(tmp, "A.pdf"); na = render(br, md_html(PART_A), pa)
        pc = os.path.join(tmp, "C.pdf"); nc = render(br, md_html(PART_C), pc)
        pl = os.path.join(tmp, "L.pdf"); nl = render(br, md_html(LAMPIRAN), pl, brk=True)
        nb = len(pymupdf.open(brief))
        n_main = 1 + na + nb + nc
        sec = [("Bagian A. Dokumentasi teknis", 2, na), ("Bagian B. Insight brief untuk Direktur Komersial", 2 + na, nb), ("Bagian C. Memo evaluasi dan pernyataan penggunaan AI", 2 + na + nb, nc),
               ("Lampiran: kamus metrik (A7), tata kelola (C2), registri angka", n_main + 1, nl)]
        rows = "".join(f"<tr><td>{t}</td><td>hlm {s} - {s + n - 1}</td></tr>" for t, s, n in sec)
        cover = (f"<div class='cover'><h1>KIRANA Omnichannel Performance Intelligence</h1><div class='sub'>Laporan UAS Business Intelligence Systems, Universitas Cakrawala (Sains Data, Blok A)</div>"
                 f"<table><tr><td><b>Nama</b></td><td>{html.escape(NAMA)}</td></tr><tr><td><b>NIM</b></td><td>{html.escape(NIM)}</td></tr><tr><td><b>Periode data</b></td><td>1 Jan 2024 - 30 Jun 2026</td></tr>"
                 f"<tr><td><b>Keputusan</b></td><td>Realokasi anggaran promo dan program perbaikan toko/region, H2 2026</td></tr></table>"
                 f"<div class='sec'>Daftar isi</div><table class='toc'>{rows}</table></div>")
        pcv = os.path.join(tmp, "cover.pdf"); ncv = render(br, cover, pcv)
        br.close()
    if ncv != 1:
        sys.exit(f"cover harus 1 halaman, dapat {ncv}")
    out = pymupdf.open()
    for f in (pcv, pa, brief, pc):
        out.insert_pdf(pymupdf.open(f))
    main_pages = len(out)
    out.insert_pdf(pymupdf.open(pl))
    for i, pg in enumerate(out, start=1):
        pg.insert_text((pg.rect.width / 2 - 60, pg.rect.height - 20), f"UAS BI KIRANA - {i} / {len(out)}", fontsize=7, color=(0.4, 0.4, 0.4))
    name = f"UAS_BI_{NIM}_{NAMA.replace(' ', '')}_Laporan.pdf"
    path = os.path.join(a.out_dir, name)
    out.save(path, deflate=True)
    print(f"{path}: {len(out)} halaman total; {main_pages} halaman di luar lampiran (batas 25); lampiran {nl}")
    print(f"  A={na} B={nb} C={nc} lampiran={nl}")
    if main_pages > 25:
        sys.exit("MELEBIHI 25 halaman di luar lampiran")


if __name__ == "__main__":
    main()
