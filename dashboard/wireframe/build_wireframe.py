#!/usr/bin/env python3
"""Hasilkan wireframe beranotasi dari sumber yang sama dengan dashboard (dashboard/questions/*.sql + dashboard/layout.json):
  wireframe.drawio (editable di draw.io, satu halaman per tab), wireframe_<tab>.png (pratinjau), wireframe.md (anotasi).
  python3 dashboard/wireframe/build_wireframe.py        (butuh Pillow untuk PNG)
Anotasi (tujuan, pengguna, keputusan, pertanyaan bisnis) ada di ANNOT di bawah."""
import glob, json, os
from xml.sax.saxutils import escape
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.dirname(HERE)
layout = json.load(open(os.path.join(D, "layout.json"), encoding="utf-8"))

ANNOT = {
    "executive": dict(
        tujuan="Satu layar untuk menjawab: apakah Net Sales dan margin FY2025 dan H1 2026 berada di jalur target, dan seberapa lengkap datanya.",
        pengguna="Direktur Komersial (utama); Finance Controller (validasi margin dan angka).",
        keputusan="Keputusan 2 (channel/region mana diprioritaskan perbaikan) dan keputusan 1 (apakah tekanan margin menuntut realokasi promo).",
        pertanyaan="Q1 pencapaian vs target; Q2 tren dan kontribusi channel; Q3 margin."),
    "channel_region_store": dict(
        tujuan="Menemukan di mana kinerja di bawah target: channel, region, lalu toko (drill-down region -> toko -> detail toko), dan memisahkan toko bermasalah karena bisnis dari data.",
        pengguna="Head of Store Operations (utama); Direktur Komersial; Head of E-Commerce (channel online).",
        keputusan="Keputusan 2: toko atau region mana yang masuk program perbaikan kinerja H2 2026.",
        pertanyaan="Q1 pencapaian per channel, region, toko; Q2 pergeseran kontribusi channel; Q5 toko berkinerja rendah dan penyebabnya."),
    "margin_promo": dict(
        tujuan="Menunjukkan siapa yang menekan margin (kategori, channel, biaya channel, diskon) dan promo mana yang tumbuh menguntungkan atau hanya membeli revenue dengan margin.",
        pengguna="Direktur Komersial (utama); Head of E-Commerce; Finance Controller.",
        keputusan="Keputusan 1: realokasi anggaran promo antar-channel, kategori, dan mekanisme promo.",
        pertanyaan="Q3 gross dan contribution margin; Q4 efektivitas promo."),
    "returns_customers": dict(
        tujuan="Mengukur tingkat dan alasan retur serta pembatalan/void, dan aktivitas serta repeat purchase member per channel.",
        pengguna="Head of Store Operations (Store); Head of E-Commerce (online).",
        keputusan="Keputusan 1 dan 2: kualitas channel/kategori yang layak ditambah anggaran promo atau diperbaiki.",
        pertanyaan="Q6 retur per kategori dan channel; Q7 aktivitas dan repeat member."),
    "storyline": dict(
        tujuan="Menyajikan 4-6 temuan terkuantifikasi berjudul asertif beserta rekomendasi, merujuk kartu pada tab 1-4 (diisi pada Task 5).",
        pengguna="Direktur Komersial.",
        keputusan="Kedua keputusan H2 2026.",
        pertanyaan="Seluruh Q1-Q7 (ringkasan)."),
    "detail": dict(
        tujuan="Drill-down satu toko: tren terhadap target alokasi, bauran kategori, dan kelengkapan data (dibuka dengan klik toko).",
        pengguna="Head of Store Operations.",
        keputusan="Keputusan 2: apakah satu toko layak masuk program perbaikan atau hanya terdampak kejadian/data.",
        pertanyaan="Q5 toko berkinerja rendah dan penyebabnya (bisnis atau data)."),
}
FILTER_LABEL = {"period": "Periode", "channel": "Channel", "region": "Region", "category": "Kategori", "store": "Toko"}
FILL = {"scalar": ("#fff2cc", "#d6b656"), "gauge": ("#fff2cc", "#d6b656"), "table": ("#d5e8d4", "#82b366"), "text": ("#f5f5f5", "#999999"),
        "heading": ("#f5f5f5", "#999999")}
CHART = ("#dae8fc", "#6c8ebf")


def parse(path):
    meta = {"filters": []}
    for line in open(path, encoding="utf-8").read().splitlines():
        if not line.startswith("-- "):
            break
        k, _, v = line[3:].partition(": ")
        if k == "filter":
            meta["filters"].append(v.split(" = ")[0])
        elif k == "pos":
            meta["pos"] = [int(x.split("=")[1]) for x in v.split()]
        elif k in ("name", "display", "tab", "dashboard", "note"):
            meta[k] = v
    return meta


cards = [parse(p) for p in sorted(glob.glob(os.path.join(D, "questions", "*.sql")))]


def tab_items(dkey, tab):
    items = []
    for t in tab.get("texts", []):
        items.append(dict(name=t["text"][:90], display=t["type"], pos=[t["row"], t["col"], t["w"], t["h"]], filters=[]))
    for m in cards:
        pos = None
        if m["dashboard"] == dkey and m["tab"] == tab["key"]:
            pos = m["pos"]
        elif m["tab"] == "*" and dkey == "kirana":
            sh = layout["shared_cards"].get(os.path.basename(m["name"]), None)
            key = "kesegaran_data" if "Kesegaran" in m["name"] else "peringatan_kelengkapan"
            sh = layout["shared_cards"][key]
            pos = m["pos"] if sh.get("tabs") == "all" else sh.get(tab["key"])
        if pos:
            items.append(dict(name=m["name"], display=m["display"], pos=pos, filters=m["filters"]))
    return items


UX, UY, PAD = 40, 34, 4   # piksel per kolom, per baris
pages, md = [], ["# Wireframe dashboard KIRANA\n",
                 "Dihasilkan oleh `dashboard/wireframe/build_wireframe.py` dari `dashboard/questions/*.sql` dan `dashboard/layout.json`; berkas draw.io "
                 "(`wireframe.drawio`) dapat diedit dan memuat satu halaman per tab. Kotak = kartu Metabase (kuning = angka utama, hijau = tabel, biru = grafik, abu = teks). "
                 "Huruf di kanan bawah kotak = filter yang berlaku: **P**eriode, **C**hannel, **R**egion, **K**ategori, **T**oko.\n"]
fnt = ImageFont.load_default()
for dkey, dash in layout["dashboards"].items():
    for tab in dash["tabs"]:
        items = tab_items(dkey, tab)
        a = ANNOT[tab["key"]]
        rows = max(i["pos"][0] + i["pos"][3] for i in items)
        w, h = 24 * UX + 380, rows * UY + 60
        cells, im = [], Image.new("RGB", (w, h), "white")
        dr = ImageDraw.Draw(im)
        dr.text((10, 8), f"{dash['name']}  |  {tab['name']}", fill="black", font=fnt)
        n = 2
        for it in items:
            r, c, sw, sh = it["pos"]
            x, y, ww, hh = c * UX + 10, r * UY + 30, sw * UX - PAD, sh * UY - PAD
            fill, stroke = FILL.get(it["display"], CHART)
            tag = "".join(FILTER_LABEL[f][0] if f != "category" else "K" for f in it["filters"]) if it["filters"] else ""
            label = f"{it['name']} [{it['display']}]" + (f"  ({tag})" if tag else "")
            dr.rectangle([x, y, x + ww, y + hh], fill=fill, outline=stroke)
            # bungkus teks sederhana
            line, ly = "", y + 4
            for word in label.split():
                if dr.textlength(line + " " + word, font=fnt) > ww - 8:
                    dr.text((x + 4, ly), line, fill="black", font=fnt); ly += 12; line = word
                else:
                    line = (line + " " + word).strip()
            dr.text((x + 4, ly), line, fill="black", font=fnt)
            cells.append(f'<mxCell id="c{n}" value="{escape(label)}" style="rounded=0;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};align=left;verticalAlign=top;fontSize=10;" vertex="1" parent="1">'
                         f'<mxGeometry x="{x}" y="{y}" width="{ww}" height="{hh}" as="geometry"/></mxCell>')
            n += 1
        ann = (f"TUJUAN: {a['tujuan']}\n\nPENGGUNA: {a['pengguna']}\n\nKEPUTUSAN: {a['keputusan']}\n\nPERTANYAAN BISNIS: {a['pertanyaan']}\n\n"
               f"FILTER DASHBOARD: {', '.join(FILTER_LABEL[p] for p in dash['parameters'])}")
        ax, aw = 24 * UX + 20, 350
        cells.append(f'<mxCell id="ann" value="{escape(ann).replace(chr(10), "&#xa;")}" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#b85450;align=left;verticalAlign=top;fontSize=10;spacing=6;" vertex="1" parent="1">'
                     f'<mxGeometry x="{ax}" y="30" width="{aw}" height="{min(rows * UY, 420)}" as="geometry"/></mxCell>')
        dr.rectangle([ax, 30, ax + aw, 30 + min(rows * UY, 420)], outline="#b85450")
        yy = 36
        for para in ann.split("\n\n"):
            line = ""
            for word in para.split():
                if dr.textlength(line + " " + word, font=fnt) > aw - 12:
                    dr.text((ax + 6, yy), line, fill="black", font=fnt); yy += 12; line = word
                else:
                    line = (line + " " + word).strip()
            dr.text((ax + 6, yy), line, fill="black", font=fnt); yy += 20
        png = f"wireframe_{dkey}_{tab['key']}.png"
        im.save(os.path.join(HERE, png))
        pages.append(f'<diagram name="{escape(tab["name"])}" id="{dkey}_{tab["key"]}"><mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" page="1" pageWidth="{w+40}" pageHeight="{h+40}">'
                     f'<root><mxCell id="0"/><mxCell id="1" parent="0"/>{"".join(cells)}</root></mxGraphModel></diagram>')
        md.append(f"\n## {dash['name']}: {tab['name']}\n")
        md.append(f"![{tab['name']}]({png})\n")
        md.append(f"- **Tujuan:** {a['tujuan']}\n- **Pengguna:** {a['pengguna']}\n- **Keputusan yang didukung:** {a['keputusan']}\n- **Pertanyaan bisnis:** {a['pertanyaan']}\n")
        md.append("| Kartu | Bentuk | Filter yang berlaku |\n| --- | --- | --- |")
        for it in sorted(items, key=lambda i: (i["pos"][0], i["pos"][1])):
            if it["display"] in ("heading", "text"):
                continue
            md.append(f"| {it['name']} | {it['display']} | {', '.join(FILTER_LABEL[f] for f in it['filters']) or 'tidak ada (indikator global)'} |")
open(os.path.join(HERE, "wireframe.drawio"), "w", encoding="utf-8").write(
    '<?xml version="1.0" encoding="UTF-8"?>\n<mxfile host="app.diagrams.net">' + "".join(pages) + "</mxfile>\n")
open(os.path.join(HERE, "wireframe.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")
print(len(pages), "halaman wireframe dibuat")
