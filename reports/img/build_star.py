#!/usr/bin/env python3
"""Diagram star schema: star_schema.drawio (editable di draw.io) dan star_schema.png.
  python3 reports/img/build_star.py     (butuh Pillow)"""
import os
from xml.sax.saxutils import escape
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
HELP = [("dim_product_cost", "HPP SCD2 (as-of)", "dim_product"), ("ref_channel_fee", "tarif as-of", "dim_channel"), ("dim_store_event", "renovasi SBY-01", "dim_store")]
DIMS = [("dim_date", "date_key"), ("dim_promo", "promo_key"), ("dim_customer", "customer_key (tanpa PII)"), ("dim_product", "product_key, sku"), ("dim_store", "store_key (SCD2 region)"), ("dim_channel", "channel_key")]
FACTS = [("fact_sales", ["grain: 1 item baris valid", "POS + online"], ["date", "product", "store", "channel", "customer", "promo"]),
         ("fact_sales_excluded", ["void, order batal", "(untuk rekonsiliasi)"], ["date", "product", "store", "channel", "customer"]),
         ("fact_returns", ["grain: 1 return_id"], ["date", "product", "store", "channel", "customer"]),
         ("fact_target", ["bulan x channel x region"], ["date", "channel"]),
         ("fact_pos_sync", ["toko x tanggal sync"], ["date", "store"])]
COL = {"date": "#2a78d6", "promo": "#7a5bd0", "customer": "#c0408a", "product": "#1baf7a", "store": "#eb6834", "channel": "#c89200"}
DW, DH, FW, FH, G = 148, 52, 184, 92, 16
X0 = 24
W = X0 * 2 + 6 * DW + 5 * G + 24
YH, YD, YF = 46, 150, 330
img = Image.new("RGB", (W, 470), "white"); d = ImageDraw.Draw(img)
fb = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
fr = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
d.text((X0, 12), "Star schema KIRANA (schema dw): dimensi di atas, fakta di bawah; warna garis = dimensi", font=fb, fill="#1b1b1a")
dx = {n: X0 + i * (DW + G) for i, (n, _) in enumerate(DIMS)}
fx = {n: X0 + i * (FW + 18) for i, (n, _, _) in enumerate(FACTS)}
cells, edges = [], []
def drawio(i, t, sub, x, y, w, h, fill):
    body = "<b>" + escape(t) + "</b><br>" + "<br>".join(escape(s) for s in sub)
    cells.append(f'<mxCell id="{i}" value="{escape(body, {chr(34): "&quot;"})}" style="rounded=1;whiteSpace=wrap;html=1;fillColor={fill};strokeColor=#8a8a85;" vertex="1" parent="1"><mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
for n, k in DIMS:
    d.rounded_rectangle([dx[n], YD, dx[n] + DW, YD + DH], 6, fill="#e6f0fb", outline="#6d8fb5"); d.text((dx[n] + 7, YD + 8), n, font=fb, fill="#1b1b1a"); d.text((dx[n] + 7, YD + 29), k, font=fr, fill="#444")
    drawio(n, n, [k], dx[n], YD, DW, DH, "#e6f0fb")
for n, sub, parent in HELP:
    x = dx[parent]
    d.rounded_rectangle([x, YH, x + DW, YH + 40], 6, fill="#f3f1ea", outline="#9a9a95"); d.text((x + 7, YH + 4), n, font=fb, fill="#1b1b1a"); d.text((x + 7, YH + 23), sub, font=fr, fill="#444")
    d.line([x + DW // 2, YH + 40, x + DW // 2, YD], fill="#888", width=2)
    drawio(n, n, [sub], x, YH, DW, 40, "#f3f1ea"); edges.append(f'<mxCell id="h_{n}" style="endArrow=none;html=1;dashed=1;" edge="1" parent="1" source="{parent}" target="{n}"><mxGeometry relative="1" as="geometry"/></mxCell>')
inc = {}
for n, _, links in FACTS:
    for i, l in enumerate(links):
        inc.setdefault(n, []).append(l)
used = {}
for n, sub, links in FACTS:
    x = fx[n]
    h = FH
    d.rounded_rectangle([x, YF, x + FW, YF + h], 6, fill="#e5f4ec", outline="#5c9a7a"); d.text((x + 8, YF + 8), n, font=fb, fill="#1b1b1a")
    for j, s in enumerate(sub): d.text((x + 8, YF + 30 + j * 16), s, font=fr, fill="#444")
    drawio(n, n, sub, x, YF, FW, h, "#e5f4ec")
    for i, l in enumerate(links):
        dn = "dim_" + l
        sx = dx[dn] + DW // 2 + (used.get(dn, 0) - 1) * 9; used[dn] = used.get(dn, 0) + 1
        ex = x + 14 + (FW - 28) * (i / max(len(links) - 1, 1))
        d.line([sx, YD + DH, ex, YF], fill=COL[l], width=2)
        edges.append(f'<mxCell id="e_{dn}_{n}" style="endArrow=none;html=1;strokeColor={COL[l]};" edge="1" parent="1" source="{dn}" target="{n}"><mxGeometry relative="1" as="geometry"/></mxCell>')
d.text((X0, YF + FH + 22), "Grain tiap fakta ada di bagian 3. dim_store dan dim_product_cost memakai SCD2 (valid_from, valid_to); store_key -1 = online, customer_key -1 = non-member.", font=fr, fill="#444")
img.save(os.path.join(HERE, "star_schema.png"))
open(os.path.join(HERE, "star_schema.drawio"), "w", encoding="utf-8").write('<mxfile><diagram name="Star schema"><mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"/>' + "".join(cells + edges) + "</root></mxGraphModel></diagram></mxfile>")
