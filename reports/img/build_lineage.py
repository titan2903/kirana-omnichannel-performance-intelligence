#!/usr/bin/env python3
"""Diagram lineage sumber -> dashboard -> brief: lineage.drawio (editable di draw.io) dan lineage.png.
  python3 reports/img/build_lineage.py     (butuh Pillow)"""
import os
from xml.sax.saxutils import escape
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
BOXES = [  # (judul, baris, warna)
    ("Sumber (13 file)", ["POS (IT), e-commerce (Head of E-Com)", "produk, promo (Marketing)", "HPP, tarif channel (Finance)", "target (FP&A)", "retur (Customer Service)", "customers (CRM, PII)", "sync log (IT)", "toko, region, kejadian (Store Ops)"], "#e8e8e4"),
    ("raw  (01_load)", ["TEMP view read_csv / read_xlsx", "kolom kotor sebagai VARCHAR", "tidak disimpan: memuat PII"], "#dbe8f7"),
    ("stg  (02_staging)", ["trim, upper, mapping, try_cast", "dedup, pasangan void", "disposition FACT / EXCLUDE / REJECT", "birth_date -> age_band"], "#dbe8f7"),
    ("dw  (03_model)", ["dim_*: date, product (+HPP SCD2),", "store (SCD2), channel, promo,", "customer; fact_sales, fact_returns,", "fact_target, fact_pos_sync", "tanpa kolom PII"], "#d6efe3"),
    ("dq  (04, 06)", ["dq.reconciliation (selisih 0)", "dq.test_results: 29 BLOCKING", "gerbang build: gagal = tidak rilis"], "#fbe6d3"),
    ("metrics + acc_*  (05)", ["v_* semantic layer, kpi_dictionary", "acc_<region>: view per region", "(Store Manager)"], "#d6efe3"),
    ("Metabase (read-only)", ["39 kartu native SQL -> metrics.v_*", "5 tab + Detail Toko", "filter periode/channel/region/kategori"], "#f3e6c4"),
    ("Brief dan laporan", ["facts.sql -> build_insights.py", "B_insight_brief.pdf, tab Storyline", "number_registry, insight_registry"], "#eadcf2"),
]
W, H, GAP, X0, Y0 = 262, 190, 30, 30, 80
HH = 235
img = Image.new("RGB", (X0 * 2 + len(BOXES) * (W + GAP) - GAP, 400), "white")
d = ImageDraw.Draw(img)
fb = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
fr = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)
d.text((X0, 24), "Lineage KIRANA: sumber -> raw -> stg -> dw -> metrics -> kartu -> tab -> brief", font=fb, fill="#1b1b1a")
cells, edges = [], []
for i, (t, lines, col) in enumerate(BOXES):
    x = X0 + i * (W + GAP)
    d.rounded_rectangle([x, Y0, x + W, Y0 + HH], 8, fill=col, outline="#8a8a85")
    d.text((x + 10, Y0 + 10), t, font=fb, fill="#1b1b1a")
    for j, ln in enumerate(lines):
        d.text((x + 10, Y0 + 40 + j * 20), ln, font=fr, fill="#2b2b29")
    if i:
        ax = x - GAP
        d.line([ax + 4, Y0 + HH // 2, x - 4, Y0 + HH // 2], fill="#555", width=2)
        d.polygon([(x - 4, Y0 + HH // 2), (x - 12, Y0 + HH // 2 - 5), (x - 12, Y0 + HH // 2 + 5)], fill="#555")
    body = "<b>" + escape(t) + "</b><br>" + "<br>".join(escape(l) for l in lines)
    cells.append(f'<mxCell id="b{i}" value="{escape(body, {chr(34): "&quot;"})}" style="rounded=1;whiteSpace=wrap;html=1;align=left;verticalAlign=top;spacingLeft=8;fillColor={col};strokeColor=#8a8a85;" vertex="1" parent="1"><mxGeometry x="{x}" y="{Y0}" width="{W}" height="{HH}" as="geometry"/></mxCell>')
    if i:
        edges.append(f'<mxCell id="e{i}" style="endArrow=block;html=1;" edge="1" parent="1" source="b{i-1}" target="b{i}"><mxGeometry relative="1" as="geometry"/></mxCell>')
d.text((X0, Y0 + HH + 24), "Dua gerbang: (1) uji BLOCKING pada build.sh sebelum kirana.duckdb diganti; (2) T12 memeriksa tidak ada kolom PII di stg, dw, dq, metrics, acc_*.", font=fr, fill="#444")
img.save(os.path.join(HERE, "lineage.png"))
xml = '<mxfile><diagram name="Lineage"><mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"/>' + "".join(cells + edges) + "</root></mxGraphModel></diagram></mxfile>"
open(os.path.join(HERE, "lineage.drawio"), "w", encoding="utf-8").write(xml)
