#!/usr/bin/env python3
"""Hak akses Metabase (Task 6, reports/C2_tata_kelola.md bagian 3). Jalankan SETELAH provision.py; aman dijalankan ulang.
  METABASE_USER=... METABASE_PASSWORD=... python3 dashboard/access.py

  All Users             : tidak melihat koleksi KIRANA, tidak dapat membuat query di KIRANA DB (hanya admin yang membangun)
  Finance               : koleksi KIRANA BI (baca); query builder pada schema metrics dan dw (tanpa SQL native)
  Direktur Komersial    : koleksi KIRANA BI (baca), dashboard saja
  Store Manager <region>: hanya koleksi regionnya (dashboard dari acc_<region>); query builder hanya pada schema acc_<region>
Metabase OSS tidak punya row-level security, jadi batas baris ada di view acc_<region> (diuji T54); Metabase membatasi
koleksi dan schema yang boleh dibuka. Anggota grup ditambahkan admin lewat Admin > People."""
import json
import os

from provision import HERE, MB

REGIONS = {"jabodetabek": "Jabodetabek", "jawa_barat": "Jawa Barat", "jateng_diy": "Jateng & DIY",
           "jawa_timur": "Jawa Timur", "bali_nusra": "Bali & Nusa Tenggara", "sumatera": "Sumatera"}
CARDS = [  # (judul, SQL dengan {s} = schema acc_<region>)
    ("Kinerja toko per bulan (target alokasi)",
     "SELECT month_start AS bulan, store_code AS toko, net_sales_idr, store_target_idr AS target_alokasi_idr, achievement_pct,\n"
     "       completeness_status AS kelengkapan_data, completeness_note AS keterangan\n"
     "FROM {s}.v_store_performance_monthly ORDER BY month_start DESC, store_code"),
    ("Net Sales dan margin toko per kategori per bulan",
     "SELECT month_start AS bulan, category AS kategori, sum(net_sales_idr) AS net_sales_idr,\n"
     "       round(100.0 * sum(gross_margin_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS gross_margin_pct\n"
     "FROM {s}.v_sales_monthly WHERE channel_name = 'Store' GROUP BY ALL ORDER BY bulan DESC, kategori"),
]


def group(mb, name, existing):
    g = existing.get(name) or mb.req("POST", "/permissions/group", json={"name": name})
    return g["id"]


def main():
    mb = MB()
    state = json.load(open(os.path.join(HERE, ".state.json")))
    dbid, main_col = state["database"], state["collection"]
    groups = {g["name"]: g for g in mb.req("GET", "/permissions/group")}
    all_users = groups["All Users"]["id"]
    fin, dir_ = group(mb, "Finance", groups), group(mb, "Direktur Komersial", groups)

    cols = {c["name"]: c for c in mb.req("GET", "/collection") if isinstance(c["id"], int) and not c.get("archived")}
    sm = {}  # schema -> (group id, collection id, dashboard id)
    for key, region in REGIONS.items():
        schema, name = f"acc_{key}", f"KIRANA Store Manager - {region}"
        gid = group(mb, f"Store Manager {region}", groups)
        col = cols.get(name) or mb.req("POST", "/collection", json={"name": name, "description": f"Dashboard Store Manager region {region} (dashboard/access.py)"})
        for it in mb.req("GET", f"/collection/{col['id']}/items")["data"]:  # bangun ulang isi koleksi agar idempoten
            mb.req("PUT", f"/{'dashboard' if it['model'] == 'dashboard' else 'card'}/{it['id']}", json={"archived": True})
        dash = mb.req("POST", "/dashboard", json={"name": name, "collection_id": col["id"],
                                                  "description": f"Hanya data region {region} (view {schema}.*). Target toko = alokasi (asumsi)."})
        dcs, row = [], 0
        for i, (title, sql) in enumerate(CARDS):
            c = mb.req("POST", "/card", json={"name": f"{title} - {region}", "type": "question", "display": "table", "collection_id": col["id"],
                                              "visualization_settings": {}, "dataset_query": {"database": dbid, "type": "native",
                                                                                              "native": {"query": sql.format(s=schema), "template-tags": {}}}})
            dcs.append({"id": -1 - i, "card_id": c["id"], "row": row, "col": 0, "size_x": 24, "size_y": 8, "parameter_mappings": [], "visualization_settings": {}})
            row += 8
        mb.req("PUT", f"/dashboard/{dash['id']}", json={"dashcards": dcs, "width": "full"})
        sm[schema] = (gid, col["id"], dash["id"])

    # izin koleksi: hanya grup yang disebut yang dapat membaca
    cg = mb.req("GET", "/collection/graph")
    g = cg["groups"]
    g.setdefault(str(all_users), {}).update({"root": "none", str(main_col): "none", **{str(c): "none" for _, c, _ in sm.values()}})
    for gid in (fin, dir_):
        g.setdefault(str(gid), {}).update({"root": "none", str(main_col): "read"})
    for gid, c, _ in sm.values():
        g.setdefault(str(gid), {}).update({"root": "none", str(main_col): "none", str(c): "read"})
    mb.req("PUT", "/collection/graph", json={"revision": cg["revision"], "groups": g})

    # izin data pada KIRANA DB: tidak ada SQL native selain admin; query builder dibatasi per schema.
    # Peta granular harus menyebut SEMUA schema: schema yang tidak disebut diisi Metabase dengan "query-builder".
    schemas = mb.req("GET", f"/database/{dbid}/schemas")
    only = lambda allowed: {s: "query-builder" if s in allowed else "no" for s in schemas}
    pg = mb.req("GET", "/permissions/graph")
    base = {"view-data": "unrestricted", "download": {"schemas": "full"}}
    upd = {str(all_users): {str(dbid): {**base, "create-queries": "no"}},
           str(fin): {str(dbid): {**base, "create-queries": only({"metrics", "dw"})}},
           str(dir_): {str(dbid): {**base, "create-queries": "no"}}}
    for schema, (gid, _, _) in sm.items():
        upd[str(gid)] = {str(dbid): {**base, "create-queries": only({schema})}}
    mb.req("PUT", "/permissions/graph", json={"revision": pg["revision"], "groups": upd})

    for schema, (gid, c, d) in sm.items():
        print(f"{schema:18s} grup {gid:3d}  koleksi {c:3d}  dashboard {d}")
    print(f"Finance grup {fin}, Direktur Komersial grup {dir_}; All Users tanpa akses koleksi KIRANA dan tanpa query.")
    state["access"] = {k: {"group": v[0], "collection": v[1], "dashboard": v[2]} for k, v in sm.items()} | {"finance": fin, "direktur": dir_}
    json.dump(state, open(os.path.join(HERE, ".state.json"), "w"))


if __name__ == "__main__":
    main()
