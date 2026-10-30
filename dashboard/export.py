#!/usr/bin/env python3
"""Ekspor dashboard KIRANA ke PNG per tab, tangkapan layar filter dan drill-through, lalu gabungkan menjadi satu PDF.

  METABASE_USER=... METABASE_PASSWORD=... python3 dashboard/export.py [--out dashboard/export]

Butuh: pip install playwright pillow  (memakai Google Chrome sistem, tanpa unduhan browser) dan dashboard sudah dibuat oleh provision.py.
Hasil: <out>/NN_<nama>.png, <out>/Dashboard_KIRANA.pdf. Ganti nama PDF menjadi UAS_BI_<NIM>_<NamaLengkap>_Dashboard.pdf untuk pengumpulan.
"""
import json, os, sys, time
import requests
from PIL import Image
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
URL = os.environ.get("METABASE_URL", "http://localhost:3000").rstrip("/")
OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(HERE, "export")
CHROME = os.environ.get("CHROME_PATH", "/usr/bin/google-chrome")
W, H = 1600, 3600


def login():
    r = requests.post(f"{URL}/api/session", json={"username": os.environ["METABASE_USER"], "password": os.environ["METABASE_PASSWORD"]}, timeout=30)
    r.raise_for_status()
    return r.json()["id"]


def settle(page, extra=2500):
    page.wait_for_load_state("networkidle")
    page.wait_for_selector("[data-testid='dashboard-grid']", timeout=60000)
    # tunggu semua kartu selesai memuat (tidak ada spinner)
    for _ in range(60):
        if page.locator("[data-testid='loading-indicator'], [data-testid='loading-spinner']").count() == 0:
            break
        time.sleep(1)
    time.sleep(extra / 1000)


def main():
    os.makedirs(OUT, exist_ok=True)
    state = json.load(open(os.path.join(HERE, ".state.json")))
    sid = login()
    hdr = {"X-Metabase-Session": sid}
    main_id, detail_id = state["dashboards"]["kirana"], state["dashboards"]["detail_toko"]
    dash = requests.get(f"{URL}/api/dashboard/{main_id}", headers=hdr).json()
    tabs = dash["tabs"]
    shots = []
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path=CHROME, headless=True)
        ctx = b.new_context(viewport={"width": W, "height": H}, device_scale_factor=1)
        host = URL.split("//")[1].split(":")[0].split("/")[0]
        ctx.add_cookies([{"name": "metabase.SESSION", "value": sid, "domain": host, "path": "/"}])
        page = ctx.new_page()

        def shot(name, url, after=None):
            page.goto(url)
            settle(page)
            if after:
                after(page)
                settle(page, 1500)
            path = os.path.join(OUT, name)
            page.screenshot(path=path, full_page=True)
            shots.append((name, path))
            print("ok", name)

        # 1) satu gambar per tab (tanpa filter)
        for i, t in enumerate(tabs, start=1):
            shot(f"{i:02d}_tab_{t['name'].split('. ',1)[-1].replace(' ', '_').replace('&','dan')}.png", f"{URL}/dashboard/{main_id}?tab={t['id']}")

        # 2) filter: FY2025, channel Store
        t_exec = tabs[0]["id"]
        shot("06_filter_periode2025_channelStore.png",
             f"{URL}/dashboard/{main_id}?tab={t_exec}&periode=2025-01-01~2025-12-31&channel=Store")

        # 3) drill-down region (nilai filter Region diisi seperti klik pada tabel region) -> tabel toko tersaring
        t_crs = tabs[1]["id"]
        shot("07_drilldown_region_JawaBarat.png", f"{URL}/dashboard/{main_id}?tab={t_crs}&region=Jawa%20Barat&periode=2025-01-01~2025-12-31")

        # 4) klik nyata pada baris region (click behavior crossfilter) dan pada toko (link ke Detail Toko)
        def click_region(pg):
            pg.get_by_text("Jabodetabek", exact=True).first.click()
        shot("08_klik_region_Jabodetabek.png", f"{URL}/dashboard/{main_id}?tab={t_crs}&periode=2025-01-01~2025-12-31", after=click_region)

        def click_store(pg):
            pg.get_by_text("SBY-01", exact=True).first.click()
        shot("09_klik_toko_SBY-01_detail.png", f"{URL}/dashboard/{main_id}?tab={t_crs}&periode=2025-01-01~2025-12-31", after=click_store)
        print("URL setelah klik toko:", page.url)
        b.close()

    # ---- gabungkan ke PDF (satu halaman per gambar, lebar A4 landscape-ish proporsional)
    imgs = []
    for _, p in shots:
        im = Image.open(p).convert("RGB")
        bg = im.getpixel((5, im.height - 5))              # buang ruang kosong di bawah konten
        rows = [y for y in range(im.height - 1, 0, -4) if any(im.getpixel((x, y)) != bg for x in range(40, im.width - 40, 40))]
        if rows:
            im = im.crop((0, 0, im.width, min(im.height, rows[0] + 40)))
            im.save(p)
        imgs.append(im)
    pdf = os.path.join(OUT, "Dashboard_KIRANA.pdf")
    imgs[0].save(pdf, save_all=True, append_images=imgs[1:], resolution=110)
    print("PDF:", pdf, f"({len(imgs)} halaman)")


if __name__ == "__main__":
    main()
