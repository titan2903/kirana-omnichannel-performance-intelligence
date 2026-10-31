#!/usr/bin/env python3
"""Bangun insight brief (Task 5) dari kirana.duckdb: angka -> grafik -> Markdown -> PDF, plus tab Storyline dashboard.

  python3 scripts/build_insights.py            (DB=path untuk database lain; default kirana.duckdb)

Alur: reports/insights/facts.sql (semua angka dihitung dari DB) -> placeholder {{kunci|filter}} di template diisi -> reports/B_insight_brief.md,
HTML, dan PDF (Chrome headless) -> storyline di dashboard/layout.json -> reports/insights/insight_registry.md (angka, nilai, sumber).
Butuh: duckdb CLI, matplotlib, markdown, Google Chrome. Tidak ada angka yang diketik tangan: kunci yang tak ada di facts.sql membuat build gagal.
"""
import base64, json, os, re, subprocess, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import markdown

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.environ.get("DB", os.path.join(ROOT, "kirana.duckdb"))
CHROME = os.environ.get("CHROME_PATH", "/usr/bin/google-chrome")
INS = os.path.join(ROOT, "reports", "insights")
IMG = os.path.join(INS, "img")
os.makedirs(IMG, exist_ok=True)

# ------------------------------------------------------------------ fakta dari DuckDB
raw = subprocess.run(["duckdb", "-readonly", DB, "-json"], stdin=open(os.path.join(INS, "facts.sql")), capture_output=True, text=True)
if raw.returncode != 0:
    sys.exit("facts.sql gagal:\n" + raw.stderr[:800])
rows = json.loads(raw.stdout)
F = {r["k"]: float(r["v"]) for r in rows}
SRC = {r["k"]: r["src"] for r in rows}
USED = set()

# ------------------------------------------------------------------ format angka (gaya Indonesia: titik ribuan, koma desimal)
MINUS = "−"


def num(x, d=0):
    s = f"{abs(x):,.{d}f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return (MINUS if x < 0 and round(abs(x), d) != 0 else "") + s


def rupiah(x, sign=False, plain=False):
    a, neg = abs(x), x < 0
    if a >= 1e9:
        body = f"{num(a / 1e9, 2)} miliar"
    elif a >= 1e8:
        body = f"{num(a / 1e6, 0)} juta"
    else:
        body = f"{num(a / 1e6, 1)} juta"
    if plain:
        return body
    pre = MINUS if neg else ("+" if sign else "")
    return f"{pre}Rp {body}"


MONTHS = ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"]
FMT = {
    "pct0": lambda x: num(x, 0) + "%", "pct1": lambda x: num(x, 1) + "%", "pct2": lambda x: num(x, 2) + "%",
    "n0": lambda x: num(x, 0), "n1": lambda x: num(x, 1), "n2": lambda x: num(x, 2), "int": lambda x: num(x, 0),
    "pt1": lambda x: num(x, 1) + " pt", "pt2": lambda x: num(x, 2) + " pt",
    "idx": lambda x: num(x - 100, 1),
    "rpj": rupiah, "srpj": lambda x: rupiah(x, sign=True), "rpm": rupiah, "rpj_plain": lambda x: rupiah(x, plain=True),
    "tgl": lambda x: f"{int(x) % 100} {MONTHS[(int(x) // 100) % 100 - 1]} {int(x) // 10000}",
}


def render(text):
    def sub(m):
        key, *flt = [p.strip() for p in m.group(1).split("|")]
        if key not in F:
            sys.exit(f"Kunci tidak ada di facts.sql: {key}")
        USED.add(key)
        v, fmt = F[key], None
        for f in flt:
            if f == "abs":
                v = abs(v)
            elif f == "rpj_abs":
                v, fmt = abs(v), "rpj"
            elif f in FMT:
                fmt = f
            else:
                sys.exit(f"Filter tidak dikenal: {f} pada {key}")
        return FMT[fmt or "n1"](v)
    return re.sub(r"\{\{([^}]+)\}\}", sub, text)


# ------------------------------------------------------------------ grafik (palet dan aturan skill dataviz)
BLUE, ORANGE, AQUA, YELLOW, CATRED, GRAY, INK, INK2 = "#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e34948", "#a8a7a2", "#0b0b0b", "#52514e"
CH = {"st": ("Store", BLUE), "mp": ("Marketplace", ORANGE), "ap": ("Mobile App", AQUA), "wb": ("Website", YELLOW)}
plt.rcParams.update({"font.size": 7.5, "axes.edgecolor": "#c9c8c3", "axes.linewidth": 0.6, "axes.spines.top": False, "axes.spines.right": False,
                     "xtick.color": INK2, "ytick.color": INK2, "axes.labelcolor": INK2, "axes.titleweight": "bold", "axes.titlesize": 8.5,
                     "axes.titlecolor": INK, "figure.dpi": 200, "savefig.bbox": "tight", "savefig.facecolor": "white"})


def use(*ks):
    USED.update(ks)
    return [F[k] for k in ks]


def save(fig, name):
    fig.savefig(os.path.join(IMG, name))
    plt.close(fig)


def chart1():
    gm = use("gm_fy24", "gm_fy25", "gm_h126", "gm_cf_fy25", "gm_cf_h126", "gm_cf_fy24")
    hpp = [100] + use("hpp_idx_fy25", "hpp_idx_h126")
    prc = [100] + use("price_idx_fy25", "price_idx_h126")
    x = ["FY2024", "FY2025", "H1 2026"]
    fig, ax = plt.subplots(1, 2, figsize=(7.4, 2.5), gridspec_kw={"wspace": 0.28})
    a = ax[0]
    a.plot(x, hpp, color=ORANGE, lw=2, marker="o", ms=5, mec="white", mew=1.2)
    a.plot(x, prc, color=BLUE, lw=2, marker="o", ms=5, mec="white", mew=1.2)
    a.text(2.06, hpp[2], f"HPP per unit\n{num(hpp[2] - 100, 1)}%".replace("\n", "\n+"), color=ORANGE, va="center", fontsize=7.5, fontweight="bold")
    a.text(2.06, prc[2], f"Harga neto per unit\n+{num(prc[2] - 100, 1)}%", color=BLUE, va="center", fontsize=7.5, fontweight="bold")
    a.set_xlim(-0.2, 3.0); a.set_ylim(98.5, 107.5); a.set_title("Indeks per unit, SKU sama (FY2024 = 100)", loc="left")
    a.grid(axis="y", color="#ececea", lw=0.6)
    b = ax[1]
    cf = [F["gm_cf_fy24"], gm[3], gm[4]]
    b.plot(x, [gm[0], gm[1], gm[2]], color=BLUE, lw=2, marker="o", ms=5, mec="white", mew=1.2)
    b.plot(x, cf, color=GRAY, lw=2, ls="--", marker="o", ms=5, mec="white", mew=1.2)
    for i, v in enumerate([gm[0], gm[1], gm[2]]):
        b.text(i, v - 0.55, f"{num(v, 1)}%", ha="center", color=BLUE, fontsize=7.5, fontweight="bold")
    b.text(2, cf[2] + 0.3, f"{num(cf[2], 1)}%", ha="center", color=INK2, fontsize=7.5, fontweight="bold")
    b.text(1.0, 47.0, "putus-putus: bila HPP tetap seperti akhir 2024", ha="center", color=INK2, fontsize=7)
    b.set_ylim(41.5, 47.5); b.set_xlim(-0.3, 2.3); b.set_title("Margin kotor: aktual vs HPP dibekukan 2024 (%)", loc="left")
    b.grid(axis="y", color="#ececea", lw=0.6)
    save(fig, "c1_margin.png")


def chart2():
    f0, f1, c0, c1 = {}, {}, {}, {}
    for ch in CH:
        f0[ch], f1[ch], c0[ch], c1[ch] = use(f"share_{ch}_fy24", f"share_{ch}_h126", f"cmch_{ch}_fy24", f"cmch_{ch}_h126")
    fig, ax = plt.subplots(1, 2, figsize=(7.4, 2.3), gridspec_kw={"wspace": 0.38, "width_ratios": [1.05, 1]})
    a = ax[0]
    for yi, (lab, sh) in enumerate([("H1 2026", f1), ("FY2024", f0)]):
        left = 0
        for ch in ["st", "mp", "ap", "wb"]:
            w = sh[ch]
            a.barh(yi, w, left=left, color=CH[ch][1], edgecolor="white", linewidth=1.5, height=0.6)
            if w > 12:
                a.text(left + w / 2, yi, f"{num(w, 1)}%", ha="center", va="center", color="white" if ch != "wb" else INK, fontsize=6.5, fontweight="bold")
            else:
                a.text(left + (w - 0.5 if ch == "ap" else 0.5), yi + 0.42, f"{num(w, 1)}%", ha="right" if ch == "ap" else "left", va="bottom", color=INK, fontsize=6.5, fontweight="bold")
            left += w
    a.set_yticks([0, 1]); a.set_yticklabels(["H1 2026", "FY2024"]); a.set_xlim(0, 100); a.set_xticks([]); a.set_ylim(-0.5, 1.8)
    a.spines["bottom"].set_visible(False); a.set_title("Bauran Net Sales per channel", loc="left")
    a.legend(handles=[plt.Rectangle((0, 0), 1, 1, color=CH[c][1]) for c in ["st", "mp", "ap", "wb"]], labels=[CH[c][0] for c in ["st", "mp", "ap", "wb"]],
             loc="upper center", bbox_to_anchor=(0.5, -0.02), ncol=4, frameon=False, fontsize=6.5, handlelength=1, columnspacing=1)
    b = ax[1]
    order = ["st", "wb", "ap", "mp"]
    for yi, ch in enumerate(order):
        b.plot([c1[ch], c0[ch]], [yi, yi], color="#d6d5d0", lw=2.4, zorder=1)
        b.scatter([c0[ch]], [yi], s=34, facecolor="white", edgecolor=CH[ch][1], lw=1.6, zorder=2)
        b.scatter([c1[ch]], [yi], s=34, color=CH[ch][1], zorder=3)
        b.text(c1[ch] - 0.7, yi, f"{num(c1[ch], 1)}", ha="right", va="center", fontsize=7, color=INK, fontweight="bold")
        b.text(c0[ch] + 0.7, yi, f"{num(c0[ch], 1)}", ha="left", va="center", fontsize=7, color=INK2)
    b.set_yticks(range(len(order))); b.set_yticklabels([CH[c][0] for c in order]); b.set_xlim(26, 50); b.invert_yaxis()
    b.set_title("Contribution margin per channel (%): FY2024 ○ → H1 2026 ●", loc="left"); b.grid(axis="x", color="#ececea", lw=0.6)
    save(fig, "c2_cm.png")


def chart3():
    fig, ax = plt.subplots(1, 2, figsize=(7.4, 2.35), sharey=True, gridspec_kw={"wspace": 0.06})
    for a, per, ttl in [(ax[0], "fy25", "FY2025"), (ax[1], "h126", "H1 2026")]:
        for i, ch in enumerate(["st", "wb", "mp", "ap"]):
            gap, ach = use(f"gap_{ch}_{per}", f"ach_{ch}_{per}")
            a.bar(i, gap / 1e9, color=CH[ch][1], width=0.62)
            a.text(i, gap / 1e9 + (0.07 if gap >= 0 else -0.07), f"{num(ach, 1)}%", ha="center", va="bottom" if gap >= 0 else "top", fontsize=7.5, fontweight="bold", color=INK)
        a.axhline(0, color=INK2, lw=0.8)
        a.set_xticks(range(4)); a.set_xticklabels([CH[c][0].replace("Mobile App", "Mobile\nApp") for c in ["st", "wb", "mp", "ap"]], fontsize=7)
        a.set_title(ttl, loc="left")
        a.set_ylim(-1.45, 1.6); ax[0].set_ylabel("Selisih vs target (Rp miliar)\nangka di batang = achievement", fontsize=7); a.grid(axis="y", color="#ececea", lw=0.6)
    save(fig, "c3_target.png")


def chart4():
    order = [("ap", "App Payday"), ("rmd", "Ramadan"), ("hbn", "Harbolnas"), ("mbr", "Member Day"), ("mega", "Mega Sale"), ("clr", "Clearance")]
    gm = [use(f"p_gm_{t}")[0] / 1e6 for t, _ in order]
    pos = [use(f"p_pos_{t}")[0] for t, _ in order]
    neg = [use(f"p_neg_{t}")[0] for t, _ in order]
    fig, ax = plt.subplots(1, 2, figsize=(7.4, 2.4), gridspec_kw={"wspace": 0.55, "width_ratios": [1.15, 1]})
    a = ax[0]
    ys = range(len(order))[::-1]
    for y, v in zip(ys, gm):
        a.barh(y, v, color=BLUE if v >= 0 else CATRED, height=0.62)
        a.text(v + (6 if v >= 0 else -6), y, num(v, 0), ha="left" if v >= 0 else "right", va="center", fontsize=7.5, fontweight="bold", color=INK)
    a.axvline(0, color=INK2, lw=0.8); a.set_yticks(list(ys)); a.set_yticklabels([n for _, n in order]); a.set_xlim(-280, 400)
    a.set_title("Margin kotor tambahan (Rp juta)", loc="left", fontsize=8); a.grid(axis="x", color="#ececea", lw=0.6)
    b = ax[1]
    for y, p, n in zip(ys, pos, neg):
        b.barh(y, p, color=BLUE, height=0.62, edgecolor="white", linewidth=1.5)
        b.barh(y, n, left=p, color=CATRED, height=0.62, edgecolor="white", linewidth=1.5)
        b.text(p + n + 0.6, y, f"{int(p)} dari {int(p + n)} positif", va="center", fontsize=7, color=INK)
    b.set_yticks(list(ys)); b.set_yticklabels([]); b.set_xlim(0, 44); b.set_xticks([])
    b.spines["bottom"].set_visible(False); b.set_title("Kode promo positif (biru) vs tidak (merah)", loc="left", fontsize=8)
    save(fig, "c4_promo.png")


def chart5():
    stores = sorted({k.split("_")[1] for k in F if re.match(r"s_[a-z]{3}\d\d_ach_h126", k)})
    prog = {"mdn01": "", "sby02": "", "mlg01": "", "sol01": ""}
    expl = {"sby01": "renovasi 49 hari", "bdg02": "sync gagal 7 hari", "dps01": "toko baru, buka Jan 2025"}
    data = sorted([(F[f"s_{s}_ach_h126"], F[f"s_{s}_ach_fy25"], s) for s in stores])
    USED.update(f"s_{s}_ach_{p}" for s in stores for p in ("h126", "fy25"))
    fig, ax = plt.subplots(figsize=(7.4, 3.5))
    for yi, (h, f, s) in enumerate(data):
        col = ORANGE if s in prog else (BLUE if s in expl else GRAY)
        ax.plot([f, h], [yi, yi], color="#d6d5d0", lw=2, zorder=1)
        ax.scatter([f], [yi], s=30, facecolor="white", edgecolor=col, lw=1.5, zorder=2)
        ax.scatter([h], [yi], s=30, color=col, zorder=3)
        lab = s[:3].upper() + "-" + s[3:]
        ax.text(max(h, f) + 1.2, yi, f"{lab}  {num(h, 1)}%" + (f"  ({expl[s]})" if s in expl else ""), va="center", fontsize=7, bbox=dict(fc="white", ec="none", pad=0.6), zorder=4,
                color=col if col != GRAY else INK2, fontweight="bold" if col != GRAY else "normal")
    ax.axvline(90, color=INK2, lw=0.9, ls="--"); ax.axvline(100, color="#d0cfca", lw=0.9)
    ax.text(90, len(data) - 0.2, "90%", ha="center", va="bottom", fontsize=7, color=INK2)
    ax.text(100, len(data) - 0.2, "100%", ha="center", va="bottom", fontsize=7, color=INK2)
    ax.set_yticks([]); ax.set_xlim(74, 128); ax.set_ylim(-0.7, len(data) + 0.4); ax.spines["left"].set_visible(False)
    ax.set_title("Achievement vs target alokasi: FY2025 ○ → H1 2026 ●   (oranye = program, biru = dijelaskan, abu = lainnya)", loc="left", fontsize=8)
    ax.grid(axis="x", color="#f0efec", lw=0.6)
    save(fig, "c5_toko.png")


def chart6():
    items = [("Fashion\nonline", use("rr_fashion_online_pct")[0], ORANGE), ("Fashion\nStore", use("rr_fashion_store_pct")[0], GRAY),
             ("Non-Fashion\nonline", use("rr_other_online_pct")[0], GRAY), ("Non-Fashion\nStore", use("rr_other_store_pct")[0], GRAY)]
    reasons = [("Ukuran tidak sesuai", use("fr_ukuran")[0], ORANGE), ("Warna berbeda dari foto", use("fr_warna")[0], GRAY),
               ("Berubah pikiran", use("fr_berubah")[0], GRAY), ("Barang cacat", use("fr_cacat")[0], GRAY)]
    fig, ax = plt.subplots(1, 2, figsize=(7.4, 2.2), gridspec_kw={"wspace": 0.5})
    a = ax[0]
    for i, (n, v, c) in enumerate(items):
        a.bar(i, v, color=c, width=0.62)
        a.text(i, v + 0.3, f"{num(v, 1)}%", ha="center", fontsize=7.5, fontweight="bold", color=INK)
    a.set_xticks(range(4)); a.set_xticklabels([n for n, _, _ in items], fontsize=7); a.set_ylim(0, 18)
    a.set_title("Return Rate (refund / Net Sales)", loc="left"); a.grid(axis="y", color="#ececea", lw=0.6)
    b = ax[1]
    for i, (n, v, c) in enumerate(reasons[::-1]):
        b.barh(i, v, color=c, height=0.62)
        b.text(v + 1, i, f"{num(v, 1)}%", va="center", fontsize=7.5, fontweight="bold", color=INK)
    b.set_yticks(range(4)); b.set_yticklabels([n for n, _, _ in reasons[::-1]], fontsize=7); b.set_xlim(0, 72)
    b.set_title("Alasan refund Fashion (% nilai refund)", loc="left"); b.grid(axis="x", color="#ececea", lw=0.6)
    save(fig, "c6_retur.png")


for fn in (chart1, chart2, chart3, chart4, chart5, chart6):
    fn()

# ------------------------------------------------------------------ brief: template -> md -> html -> pdf
tpl = open(os.path.join(INS, "brief.tpl.md"), encoding="utf-8").read()
md = render(tpl)
open(os.path.join(ROOT, "reports", "B_insight_brief.md"), "w", encoding="utf-8").write(md)

CSS = """
@page { size: A4; margin: 12mm 13mm 14mm 13mm; @bottom-center { content: counter(page) " / " counter(pages); font: 8px sans-serif; color: #777; } }
body { font-family: 'DejaVu Sans', Arial, sans-serif; font-size: 8.6pt; line-height: 1.36; color: #0b0b0b; }
h1 { font-size: 16pt; margin: 0 0 3px 0; letter-spacing: -0.2px; } h2 { font-size: 11pt; margin: 11px 0 4px; border-bottom: 1.5px solid #2a78d6; padding-bottom: 2px; page-break-after: avoid; }
p, ul, ol { margin: 3px 0 4px; } li { margin: 1.5px 0; } code { font-size: 7.6pt; background: #f1f0ed; padding: 0 2px; border-radius: 2px; }
.meta { font-size: 7.6pt; color: #52514e; margin: 0 0 6px; } .figs { margin: 4px 0 3px; page-break-inside: avoid; } .figs img { width: 100%; }
table { border-collapse: collapse; width: 100%; margin: 5px 0; font-size: 7.6pt; page-break-inside: auto; } tr { page-break-inside: avoid; }
th { background: #eef3fa; text-align: left; padding: 3px 4px; border: 0.6px solid #c9c8c3; } td { padding: 3px 4px; border: 0.6px solid #d8d7d2; vertical-align: top; }
tr.grp td { background: #f6f5f2; } td.bis { color: #1c5cab; font-weight: bold; } td.dat { color: #b33a16; font-weight: bold; }
.note { color: #52514e; font-size: 7.8pt; } strong { font-weight: bold; }
"""
body = markdown.markdown(md, extensions=["tables", "md_in_html"])
html = f"<!doctype html><html lang='id'><head><meta charset='utf-8'><title>Insight Brief KIRANA</title><base href='file://{os.path.join(ROOT, 'reports')}/'><style>{CSS}</style></head><body>{body}</body></html>"
hp = os.path.join(ROOT, "reports", "insights", "brief.html")
open(hp, "w", encoding="utf-8").write(html)
pdf = os.path.join(ROOT, "reports", "B_insight_brief.pdf")
r = subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-sandbox", "--no-pdf-header-footer", f"--print-to-pdf={pdf}", f"file://{hp}"], capture_output=True, text=True, timeout=120)
if not os.path.exists(pdf):
    sys.exit("PDF gagal dibuat:\n" + r.stderr[-600:])
try:
    import fitz
    pages = len(fitz.open(pdf))
    print(f"PDF: {pdf} ({pages} halaman; batas 6)")
    if pages > 6:
        sys.exit(f"Brief {pages} halaman, melebihi batas 6")
except ImportError:
    print("PDF dibuat (pymupdf tidak terpasang, jumlah halaman tidak dicek)")

# ------------------------------------------------------------------ storyline dashboard
ST = [
    ("Margin kotor turun {{gm_drop_pt|pt1}}: HPP per unit naik {{hpp_idx_h126|idx}}%, harga neto hanya {{price_idx_h126|idx}}%",
     "Bila HPP tetap seperti akhir 2024, margin H1 2026 = **{{gm_cf_h126|pct1}}** (aktual {{gm_h126|pct1}}). Diskon hanya naik {{disc_rise_pt|pt2}}. Setiap 1% harga neto = **{{rp_per_1pct_harga|rpj}}** margin per semester.",
     "executive__gm_cm_bulanan", 5),
    ("Contribution margin turun {{cm_drop_pt|pt1}}: {{cm_effect_margin_pt|abs|pt1}} margin dalam channel, {{cm_effect_mix_pt|abs|pt1}} pergeseran ke Marketplace",
     "Marketplace {{share_mp_h126|pct1}} dari Net Sales dengan CM {{cmch_mp_h126|pct1}} (Store {{cmch_st_h126|pct1}}). Komisi 9,0% -> 11,5% sejak Apr 2025 menambah biaya **{{mp_fee_extra_total_rp|rpj}}**.\n\n*Filter Periode = 1 Jan 2026 - 30 Jun 2026 menampilkan angka H1 2026 di kartu.*",
     "margin_promo__margin_bridge_channel", 5),
    ("Target agregat tercapai hanya karena online: Marketplace {{ach_mp_h126|pct1}} dan Mobile App {{ach_ap_h126|pct1}} menutup Store ({{ach_st_h126|pct1}}) dan Website ({{ach_wb_h126|pct1}})",
     "H1 2026 total {{ach_total_h126|pct1}} ({{gap_total_h126|srpj}}); FY2025 {{ach_total_fy25|pct1}}. Website bukan kehilangan pelanggan: dari {{web_mig_total|int}} member FY2024, {{web_mig_app|int}} pindah ke Mobile App.\n\n*Filter Periode = 1 Jan 2026 - 30 Jun 2026 menampilkan angka H1 2026 di kartu.*",
     "executive__achievement_per_channel", 5),
    ("Mega Sale dan Clearance menggerus margin; App Payday menambahnya di {{p_pos_ap|int}} dari {{p_n_ap|int}} kode",
     "Mega Sale ({{mega_discount_pct|int}}%): margin kotor saat promo {{p_gmpct_promo_mega|pct1}}, CM {{p_cm_mega|rpj}}. Estimasi dampak H2 2026 bila dihentikan dan dialihkan: **{{scn_promo_total_low_rp|srpj}} s.d. {{scn_promo_total_high_rp|srpj}}** CM.",
     "margin_promo__promo_incremental_gm_bar", 5),
    ("Hanya MDN-01 konsisten di bawah target tanpa penjelasan lain; SBY-02, MLG-01, SOL-01 memburuk; SBY-01, BDG-02, Jawa Barat bukan masalah kinerja",
     "MDN-01: {{s_mdn01_ach_fy25|pct1}} dan {{s_mdn01_ach_h126|pct1}}, penjualan {{s_mdn01_yoy|pct1}} YoY. SBY-01 tutup {{sby01_closed_days|int}} hari (renovasi), BDG-02 sync gagal {{bdg02_failed_days|int}} hari (data), Jawa Barat FY2025 {{ach_reg_jb_fy25|pct1}} setelah koreksi region. Target toko = alokasi (asumsi).\n\n*Filter Periode = 1 Jan 2026 - 30 Jun 2026 menampilkan angka H1 2026 di kartu.*",
     "channel_region_store__store_ranking", 9),
    ("Fashion online mengembalikan {{rr_fashion_online_pct|pct1}} penjualannya (Store {{rr_fashion_store_pct|pct1}}); {{fr_ukuran|pct0}} refund Fashion karena ukuran",
     "Fashion = {{fashion_refund_share_pct|pct1}} dari seluruh refund. Menurunkan Return Rate Fashion online ke level Store menghindari sekitar **{{fashion_excess_refund_year_rp|rpj}}** refund per tahun.",
     "returns_customers__return_rate_per_kategori", 5),
]
texts, extra, row = [], [], 6   # baris 1-3 = kartu kesegaran data (ada di semua tab)
texts.append({"row": 0, "col": 0, "w": 24, "h": 1, "type": "heading", "text": "Storyline: margin dan promo menentukan H2 2026, bukan volume"})
texts.append({"row": 4, "col": 0, "w": 24, "h": 2, "type": "text", "text": render(
    "**Ringkasan.** Net Sales memenuhi target ({{ach_total_fy25|pct1}} FY2025, {{ach_total_h126|pct1}} H1 2026) tetapi margin kotor turun {{gm_drop_pt|pt1}} dan contribution margin {{cm_drop_pt|pt1}}. "
    "Keputusan 1 (promo): hentikan atau batasi Mega Sale, hentikan Clearance, ubah Member Day, alihkan ke App Payday. Keputusan 2 (toko): program intensif MDN-01, pantau SBY-02, MLG-01, SOL-01. "
    "Angka identik dengan `reports/B_insight_brief.pdf`. *Tanpa filter, kartu menampilkan seluruh periode (FY2025 + H1 2026); angka H1 2026 muncul bila Periode = 1 Jan - 30 Jun 2026.*")})
for i, (title, body, card, h) in enumerate(ST, start=1):
    texts.append({"row": row, "col": 0, "w": 9, "h": h, "type": "text", "text": render(f"### {i}. {title}\n\n{body}")})
    extra.append({"card": card, "pos": [row, 9, 15, h]})
    row += h
texts.append({"row": row, "col": 0, "w": 24, "h": 2, "type": "text", "text": render(
    "**Anotasi pengukuran.** BGR-01 pindah ke Jabodetabek pada 1 Jul 2025 tetapi target FY2025 tidak disesuaikan; achievement memakai peta region awal tahun target. "
    "Dengan region saat transaksi, Jawa Barat tampak anjlok dari {{reg_jb_h125_asof|pct1}} ke {{reg_jb_h225_asof|pct1}} (artefak). Estimasi dampak adalah replay H2 2025 dan bersifat indikatif.")})
lp = os.path.join(ROOT, "dashboard", "layout.json")
L = json.load(open(lp, encoding="utf-8"))
tab = next(t for t in L["dashboards"]["kirana"]["tabs"] if t["key"] == "storyline")
tab["texts"] = texts
L["extra_placements"] = {"storyline": extra}
json.dump(L, open(lp, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(f"Storyline: {len(texts)} teks dan {len(extra)} kartu di dashboard/layout.json")

# ------------------------------------------------------------------ registri angka
reg = ["# Insight Registry", "",
       "Dihasilkan otomatis oleh `scripts/build_insights.py` dari `reports/insights/facts.sql` dan `kirana.duckdb`. Setiap angka yang dikutip di `B_insight_brief.md`, ",
       "storyline dashboard, dan grafik ada di tabel ini beserta sumbernya. Nilai mentah dalam Rupiah penuh atau persen/poin.", "",
       "| Kunci | Nilai | Sumber |", "| --- | ---: | --- |"]
for k in sorted(USED):
    reg.append(f"| `{k}` | {('%.4f' % F[k]).rstrip('0').rstrip('.')} | {SRC[k]} |")
open(os.path.join(INS, "insight_registry.md"), "w", encoding="utf-8").write("\n".join(reg) + "\n")
print(f"Registri: {len(USED)} angka dipakai dari {len(F)} yang dihitung")
