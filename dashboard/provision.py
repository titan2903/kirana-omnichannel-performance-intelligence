#!/usr/bin/env python3
"""Bangun dashboard KIRANA di Metabase dari file di repo (kartu = dashboard/questions/*.sql, tata letak = dashboard/layout.json).

  METABASE_USER=... METABASE_PASSWORD=... python3 dashboard/provision.py [--verify] [--keep]

Variabel lingkungan:
  METABASE_URL       default http://localhost:3000
  METABASE_USER / METABASE_PASSWORD   akun admin Metabase (JANGAN simpan di repo)
  METABASE_DB_NAME   nama koneksi DuckDB di Metabase (default: koneksi pertama dengan engine duckdb)
Perilaku: koleksi "KIRANA BI" dikosongkan lalu dibuat ulang (idempoten). Edit manual di koleksi itu akan tertimpa; --keep
menonaktifkan penghapusan (membuat duplikat). Public sharing tidak pernah diaktifkan oleh skrip ini.
--verify : jalankan semua kartu tanpa filter, lalu tiap filter dashboard satu per satu pada kartu yang dipetakan; cetak matriks baris.
"""
import glob, json, os, re, sys, time, uuid
import requests

HERE = os.path.dirname(os.path.abspath(__file__))
URL = os.environ.get("METABASE_URL", "http://localhost:3000").rstrip("/")
SAMPLE = {"period": "2025-01-01~2025-12-31", "channel": "Store", "region": "Jabodetabek", "category": "Fashion", "store": "JKT-01"}
WIDGET = {"period": "date/all-options"}


class MB:
    def __init__(self):
        user, pw = os.environ.get("METABASE_USER"), os.environ.get("METABASE_PASSWORD")
        if not user or not pw:
            sys.exit("Isi METABASE_USER dan METABASE_PASSWORD (akun admin). Jangan simpan di repo.")
        r = requests.post(f"{URL}/api/session", json={"username": user, "password": pw}, timeout=30)
        if r.status_code != 200:
            sys.exit(f"Login gagal ({r.status_code}): {r.text[:200]}")
        self.h = {"X-Metabase-Session": r.json()["id"]}

    def req(self, method, path, **kw):
        r = requests.request(method, f"{URL}/api{path}", headers=self.h, timeout=120, **kw)
        if r.status_code >= 300:
            raise RuntimeError(f"{method} {path} -> {r.status_code}: {r.text[:600]}")
        return r.json() if r.text else None


def parse_card(path):
    head, body = [], []
    for line in open(path, encoding="utf-8").read().splitlines():
        (head if line.startswith("-- ") and not body else body).append(line)
    meta = {"filters": {}}
    for line in head:
        k, _, v = line[3:].partition(": ")
        if k == "filter":
            p, _, col = v.partition(" = ")
            meta["filters"][p.strip()] = col.strip()
        elif k in ("viz", "click"):
            meta[k] = json.loads(v)
        elif k == "pos":
            meta["pos"] = [int(x.split("=")[1]) for x in v.split()]
        else:
            meta[k] = v
    meta["sql"] = "\n".join(body).strip()
    meta["key"] = os.path.splitext(os.path.basename(path))[0]
    return meta


def main():
    verify = "--verify" in sys.argv
    keep = "--keep" in sys.argv
    mb = MB()
    layout = json.load(open(os.path.join(HERE, "layout.json"), encoding="utf-8"))

    # ---- database dan metadata field
    dbs = mb.req("GET", "/database")["data"]
    want = os.environ.get("METABASE_DB_NAME")
    db = next((d for d in dbs if (d["name"] == want if want else d["engine"] == "duckdb")), None)
    if not db:
        sys.exit("Koneksi DuckDB tidak ditemukan di Metabase. Tambahkan di Admin > Databases (path /data/kirana.duckdb, read-only).")
    dbid = db["id"]
    mb.req("POST", f"/database/{dbid}/sync_schema")
    fields = {}
    for _ in range(60):
        meta = mb.req("GET", f"/database/{dbid}/metadata?include_hidden=true")
        fields = {(t["name"], f["name"]): f["id"] for t in meta["tables"] if t.get("schema") == "metrics" for f in t["fields"]}
        if ("v_sales_monthly", "net_sales_idr") in fields and ("v_store_performance_monthly", "store_code") in fields:
            break
        time.sleep(3)
    else:
        sys.exit("Schema metrics belum terbaca. Jalankan bash scripts/build.sh lalu restart Metabase, kemudian sync database.")
    print(f"Database '{db['name']}' (id {dbid}); {len(fields)} kolom metrics terbaca")

    # ---- koleksi (dikosongkan agar idempoten)
    cols = mb.req("GET", "/collection")
    col = next((c for c in cols if c["name"] == layout["collection"] and not c.get("archived") and c.get("personal_owner_id") is None), None)
    if not col:
        col = mb.req("POST", "/collection", json={"name": layout["collection"], "description": "Dashboard UAS BIS KIRANA (dibuat oleh dashboard/provision.py)"})
    elif not keep:
        for it in mb.req("GET", f"/collection/{col['id']}/items")["data"]:
            if it["model"] == "dashboard":
                mb.req("DELETE", f"/dashboard/{it['id']}")
            elif it["model"] in ("card", "dataset"):
                mb.req("PUT", f"/card/{it['id']}", json={"archived": True})
                try:
                    mb.req("DELETE", f"/card/{it['id']}")
                except RuntimeError:
                    pass
    cid = col["id"]

    # ---- kartu
    cards = {}
    for path in sorted(glob.glob(os.path.join(HERE, "questions", "*.sql"))):
        m = parse_card(path)
        tags = {}
        for tag in re.findall(r"\{\{(\w+)\}\}", m["sql"]):
            table, column = m["filters"][tag].split(".")
            tags[tag] = {"id": str(uuid.uuid4()), "name": tag, "display-name": layout["parameters"][tag]["name"], "type": "dimension",
                         "dimension": ["field", fields[(table, column)], None], "widget-type": WIDGET.get(tag, "string/="), "required": False}
        body = {"name": m["name"], "type": "question", "display": m["display"], "collection_id": cid, "description": m.get("note"),
                "visualization_settings": m.get("viz", {}),
                "dataset_query": {"database": dbid, "type": "native", "native": {"query": m["sql"], "template-tags": tags}}}
        c = mb.req("POST", "/card", json=body)
        m["card_id"] = c["id"]
        cards[m["key"]] = m
    print(f"{len(cards)} kartu dibuat")

    # ---- dashboard
    ids = {}
    for dkey in ["detail_toko", "kirana"]:
        spec = layout["dashboards"][dkey]
        params = [layout["parameters"][p] for p in spec["parameters"]]
        d = mb.req("POST", "/dashboard", json={"name": spec["name"], "description": spec["description"], "collection_id": cid, "parameters": params})
        ids[dkey] = d["id"]
        tabs, dashcards, n = [], [], -1
        for ti, tab in enumerate(spec["tabs"], start=1):
            tid = -ti
            tabs.append({"id": tid, "name": tab["name"]})
            for t in tab.get("texts", []):
                vs = {"virtual_card": {"name": None, "display": t["type"], "visualization_settings": {}, "dataset_query": {}, "archived": False}, "text": t["text"]}
                if t["type"] == "heading":
                    vs["dashcard.background"] = False
                dashcards.append({"id": n, "card_id": None, "dashboard_tab_id": tid, "row": t["row"], "col": t["col"], "size_x": t["w"], "size_y": t["h"],
                                  "visualization_settings": vs, "parameter_mappings": []}); n -= 1
            for m in cards.values():
                dash_key = {"kirana": "kirana", "detail_toko": "detail_toko"}[dkey]
                pos = None
                if m["tab"] == tab["key"] and m["dashboard"] == dash_key:
                    pos = m["pos"]
                elif m["tab"] == "*" and dkey == "kirana":
                    sh = layout["shared_cards"].get(m["key"].replace("all__", ""), {})
                    if sh.get("tabs") == "all":
                        pos = m["pos"]
                    elif tab["key"] in sh:
                        pos = sh[tab["key"]]
                if not pos:
                    continue
                vs = {}
                if m.get("click"):
                    click = json.loads(json.dumps(m["click"]).replace('"{{detail_dashboard_id}}"', str(ids.get("detail_toko", 0))))
                    vs["click_behavior"] = click
                maps = [{"parameter_id": p, "card_id": m["card_id"], "target": ["dimension", ["template-tag", p]]} for p in m["filters"] if p in spec["parameters"]]
                dashcards.append({"id": n, "card_id": m["card_id"], "dashboard_tab_id": tid, "row": pos[0], "col": pos[1], "size_x": pos[2], "size_y": pos[3],
                                  "visualization_settings": vs, "parameter_mappings": maps}); n -= 1
            # kartu yang dipakai ulang di tab lain (mis. Storyline) lewat layout.json "extra_placements"
            for ex in layout.get("extra_placements", {}).get(tab["key"], []) if dkey == "kirana" else []:
                m = cards[ex["card"]]
                maps = [{"parameter_id": p, "card_id": m["card_id"], "target": ["dimension", ["template-tag", p]]} for p in m["filters"] if p in spec["parameters"]]
                dashcards.append({"id": n, "card_id": m["card_id"], "dashboard_tab_id": tid, "row": ex["pos"][0], "col": ex["pos"][1], "size_x": ex["pos"][2],
                                  "size_y": ex["pos"][3], "visualization_settings": {}, "parameter_mappings": maps}); n -= 1
        mb.req("PUT", f"/dashboard/{d['id']}", json={"tabs": tabs, "dashcards": dashcards, "parameters": params, "width": "full"})
        print(f"Dashboard '{spec['name']}' -> {URL}/dashboard/{d['id']}  ({len(tabs)} tab, {len(dashcards)} elemen)")
    json.dump({"dashboards": ids, "collection": cid, "database": dbid}, open(os.path.join(HERE, ".state.json"), "w"))

    if verify:
        run_verify(mb, ids, cards)


def run_verify(mb, ids, cards):
    print("\nVERIFIKASI: baris hasil tiap kartu tanpa filter dan dengan satu filter dashboard (selisih = filter bekerja)")
    errors = 0
    for dkey, did in ids.items():
        dash = mb.req("GET", f"/dashboard/{did}")
        pnames = [p["id"] for p in dash["parameters"]]
        print(f"\n== {dash['name']}")
        print(f"{'kartu':55s} {'tanpa':>6s} " + " ".join(f"{p:>9s}" for p in pnames))
        seen = set()
        for dc in dash["dashcards"]:
            if not dc.get("card_id") or (dc["card_id"], dc.get("dashboard_tab_id")) in seen:
                continue
            seen.add((dc["card_id"], dc.get("dashboard_tab_id")))
            base = f"/dashboard/{did}/dashcard/{dc['id']}/card/{dc['card_id']}/query"
            row = []
            try:
                r0 = mb.req("POST", base, json={"parameters": []})
                n0 = len(r0["data"]["rows"]) if r0.get("status") == "completed" else None
                if n0 is None: errors += 1
            except RuntimeError as e:
                n0 = None; errors += 1; print("GALAT", dc["card_id"], str(e)[:200])
            mapped = {m["parameter_id"] for m in dc["parameter_mappings"]}
            for p in pnames:
                if p not in mapped:
                    row.append("-"); continue
                val = SAMPLE[p]
                typ = next(x["type"] for x in dash["parameters"] if x["id"] == p)
                try:
                    r = mb.req("POST", base, json={"parameters": [{"id": p, "type": typ, "value": [val] if typ != "date/all-options" else val, "target": next(m["target"] for m in dc["parameter_mappings"] if m["parameter_id"] == p)}]})
                    row.append(str(len(r["data"]["rows"])) if r.get("status") == "completed" else "GALAT")
                    if r.get("status") != "completed": errors += 1
                except RuntimeError as e:
                    row.append("GALAT"); errors += 1; print("GALAT", dc["card_id"], p, str(e)[:200])
            name = next(k for k, v in cards.items() if v["card_id"] == dc["card_id"])
            print(f"{name:55s} {str(n0):>6s} " + " ".join(f"{x:>9s}" for x in row))
    print(f"\nTotal galat: {errors}")
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
