#!/usr/bin/env python3
"""Tambahkan tautan GitHub ke penyebutan file repo di PDF laporan yang belum bertautan (halaman insight brief disisipkan
dengan pdfpages, yang membuang tautan PDF asal). Penyebutan yang sudah bertautan (\\href di .tex) dilewati; aman diulang.
  python3 scripts/link_pdf.py laporan_akhir/UAS_BI_<NIM>_<Nama>_Laporan.pdf      (butuh pymupdf)"""
import os
import subprocess
import sys

import pymupdf

REPO = "https://github.com/titan2903/kirana-omnichannel-performance-intelligence/blob/master/"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

files = subprocess.run(["git", "-C", ROOT, "ls-files"], capture_output=True, text=True, check=True).stdout.split()
# path lengkap dan akhiran path tanpa folder teratas (mis. "insights/insight_registry.md"); yang terpanjang dicari lebih dulu
terms = {}
for f in files:
    parts = f.split("/")
    for i in range(len(parts) - 1):
        terms.setdefault("/".join(parts[i:]), f)
terms = sorted(terms.items(), key=lambda kv: -len(kv[0]))

path = sys.argv[1]
doc = pymupdf.open(path)
added = 0
for page in doc:
    text = page.get_text()
    taken = [pymupdf.Rect(l["from"]) for l in page.get_links()]
    for term, f in terms:
        if term not in text:
            continue
        for r in page.search_for(term):
            if any(r.intersects(t) for t in taken):
                continue
            page.insert_link({"kind": pymupdf.LINK_URI, "from": r, "uri": REPO + f})
            taken.append(r)
            added += 1
if added:  # simpan hanya bila berubah, agar berkas identik dengan salinannya di dist/
    tmp = path + ".tmp"
    doc.save(tmp, garbage=3, deflate=True)
    doc.close()
    os.replace(tmp, path)
print(f"{added} tautan ditambahkan ke {path}")
