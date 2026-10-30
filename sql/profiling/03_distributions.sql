-- Task 1 / profiling 3: sebaran nilai dan statistik yang dikutip di reports/A2_profiling.md
-- Input : raw_data/*  (read-only). Output: hanya tampil di layar.
-- Jalankan dari root project:  duckdb -markdown < sql/profiling/03_distributions.sql
-- Tidak ada nilai PII yang ditampilkan (customers hanya agregat).

-- ---------- POS ----------
SELECT 'POS qty' AS topik, CASE WHEN qty < 0 THEN 'negatif (void)' WHEN qty <= 3 THEN qty::VARCHAR ELSE '>3 (B2B bulk)' END AS nilai, count(*) AS n
FROM (SELECT try_cast(qty AS INT) AS qty FROM read_csv('raw_data/sales_pos_transactions.csv', all_varchar = true)) GROUP BY 2 ORDER BY 2;
SELECT 'POS payment_type' AS topik, payment_type AS nilai, count(*) AS n FROM read_csv('raw_data/sales_pos_transactions.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'POS member / non-member' AS topik, (member_id IS NOT NULL) AS is_member, count(*) AS n, round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM read_csv('raw_data/sales_pos_transactions.csv') GROUP BY 2;
SELECT 'POS distinct' AS topik, count(DISTINCT trx_id) AS trx_id_mentah FROM read_csv('raw_data/sales_pos_transactions.csv');

-- ---------- ONLINE ----------
SELECT 'ONLINE qty' AS topik, qty AS nilai, count(*) AS n FROM read_csv('raw_data/sales_online_orders.csv') GROUP BY 2 ORDER BY 2;
SELECT 'ONLINE order_status' AS topik, order_status AS nilai, count(*) AS n, round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM read_csv('raw_data/sales_online_orders.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'ONLINE payment_method' AS topik, payment_method AS nilai, count(*) AS n FROM read_csv('raw_data/sales_online_orders.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'ONLINE ship_province' AS topik, coalesce(ship_province, '<kosong>') AS nilai, count(*) AS n FROM read_csv('raw_data/sales_online_orders.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'ONLINE format item_price' AS topik, CASE WHEN item_price LIKE 'Rp%' THEN 'Rp...' ELSE 'angka polos' END AS nilai, count(*) AS n
FROM read_csv('raw_data/sales_online_orders.csv', all_varchar = true) GROUP BY 2;
SELECT 'ONLINE distinct' AS topik, count(DISTINCT order_no) AS order_no_mentah FROM read_csv('raw_data/sales_online_orders.csv');

-- ---------- Harga transaksi vs harga master (rasio harga transaksi / current_list_price) ----------
SELECT 'harga vs master' AS topik, src, round(avg(rasio), 3) AS rata2, round(min(rasio), 3) AS minimum, round(max(rasio), 3) AS maksimum
FROM (SELECT 'POS' AS src, t.unit_price::DOUBLE / p.current_list_price AS rasio
        FROM read_csv('raw_data/sales_pos_transactions.csv') t JOIN (SELECT DISTINCT upper(trim(sku)) AS sku, current_list_price FROM read_csv('raw_data/products.csv')) p ON p.sku = upper(trim(t.sku))
      UNION ALL
      SELECT 'ONLINE', try_cast(replace(replace(o.item_price, 'Rp', ''), '.', '') AS BIGINT)::DOUBLE / p.current_list_price
        FROM read_csv('raw_data/sales_online_orders.csv', all_varchar = true) o JOIN (SELECT DISTINCT upper(trim(sku)) AS sku, current_list_price FROM read_csv('raw_data/products.csv')) p ON p.sku = upper(trim(o.sku)))
GROUP BY src;

-- ---------- HPP ----------
SELECT 'HPP periode per SKU' AS topik, n_periode, count(*) AS n_sku
FROM (SELECT sku, count(*) AS n_periode FROM read_csv('raw_data/product_cost_history.csv') GROUP BY sku) GROUP BY 2 ORDER BY 2;
SELECT 'HPP perubahan' AS topik, valid_from AS tanggal_berlaku, count(*) AS n_sku, round(avg(pct_naik), 4) AS rata2_kenaikan
FROM (SELECT valid_from, unit_cost::DOUBLE / lag(unit_cost) OVER (PARTITION BY sku ORDER BY valid_from) - 1 AS pct_naik FROM read_csv('raw_data/product_cost_history.csv'))
WHERE pct_naik IS NOT NULL GROUP BY 2 ORDER BY 2;
SELECT 'HPP perubahan total' AS topik, count(*) FILTER (WHERE pct_naik > 0) AS naik, count(*) FILTER (WHERE pct_naik < 0) AS turun, round(avg(pct_naik), 4) AS rata2
FROM (SELECT unit_cost::DOUBLE / lag(unit_cost) OVER (PARTITION BY sku ORDER BY valid_from) - 1 AS pct_naik FROM read_csv('raw_data/product_cost_history.csv')) WHERE pct_naik IS NOT NULL;

-- ---------- Customers (agregat) ----------
SELECT 'CUST member_tier' AS topik, member_tier AS nilai, count(*) AS n FROM read_csv('raw_data/customers.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'CUST join_channel' AS topik, join_channel AS nilai, count(*) AS n FROM read_csv('raw_data/customers.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'CUST rentang lahir (selain sentinel)' AS topik, min(birth_date) AS paling_tua, max(birth_date) AS paling_muda
FROM read_csv('raw_data/customers.csv') WHERE birth_date <> '1900-01-01';
SELECT 'CUST telepon berulang (baris)' AS topik, count(*) - count(DISTINCT phone) AS n FROM read_csv('raw_data/customers.csv');

-- ---------- Retur ----------
SELECT 'RETUR channel' AS topik, channel AS nilai, count(*) AS n, sum(refund_amount) AS refund_rp FROM read_csv('raw_data/returns.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'RETUR alasan' AS topik, return_reason AS nilai, count(*) AS n FROM read_csv('raw_data/returns.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'RETUR total' AS topik, count(*) AS n, sum(refund_amount) AS refund_rp FROM read_csv('raw_data/returns.csv');

-- ---------- Promo ----------
SELECT 'PROMO channel_scope' AS topik, channel_scope AS nilai, count(*) AS n FROM read_csv('raw_data/promotions.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'PROMO member_only' AS topik, member_only AS nilai, count(*) AS n FROM read_csv('raw_data/promotions.csv') GROUP BY 2;
SELECT 'PROMO jenis' AS topik, regexp_extract(promo_name, '^(Ramadan|Clearance|Member Day|App Payday|Mega Sale|Harbolnas)', 1) AS jenis, count(*) AS n_kode, sum(budget_idr) AS anggaran_rp
FROM read_csv('raw_data/promotions.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'PROMO diskon_pct' AS topik, min(discount_pct) AS minimum, max(discount_pct) AS maksimum FROM read_csv('raw_data/promotions.csv');

-- ---------- Sync log ----------
SELECT 'SYNC status' AS topik, sync_status AS nilai, count(*) AS toko_hari, count(DISTINCT store_code) AS n_toko, min(business_date) AS dari, max(business_date) AS sampai
FROM read_csv('raw_data/pos_sync_log.csv') GROUP BY 2 ORDER BY 3 DESC;
SELECT 'SYNC cakupan' AS topik, count(*) AS toko_hari_ada,
       (SELECT count(*) FROM generate_series(DATE '2024-01-01', DATE '2026-06-30', INTERVAL 1 DAY)) * 18 AS toko_hari_seharusnya,
       (SELECT count(*) FROM generate_series(DATE '2024-01-01', DATE '2025-01-14', INTERVAL 1 DAY)) AS hari_sebelum_DPS01_buka
FROM read_csv('raw_data/pos_sync_log.csv');
SELECT 'SYNC SUCCESS tanpa baris (rows_uploaded=0)' AS topik, count(*) AS toko_hari, count(DISTINCT store_code) AS n_toko
FROM read_csv('raw_data/pos_sync_log.csv') WHERE sync_status = 'SUCCESS' AND rows_uploaded = 0;
SELECT 'SYNC FAILED' AS topik, store_code, min(business_date) AS dari, max(business_date) AS sampai, count(*) AS hari
FROM read_csv('raw_data/pos_sync_log.csv') WHERE sync_status = 'FAILED' GROUP BY 2;

-- ---------- Target ----------
INSTALL excel; LOAD excel;
SELECT 'TARGET total 2025' AS topik, sum(t) AS rp FROM (UNPIVOT (SELECT * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target Net Sales 2025', range = 'A3:N20', header = true) WHERE Channel IS NOT NULL) ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t);
SELECT 'TARGET total H1 2026' AS topik, sum(t) AS rp FROM (UNPIVOT (SELECT * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target Net Sales H1 2026', range = 'A3:H20', header = true) WHERE Channel IS NOT NULL) ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t);
-- UNPIVOT membuang sel kosong, jadi sel terisi harus sama dengan baris x bulan (9x12 dan 9x6) bila tidak ada sel kosong.
SELECT 'TARGET sel terisi vs seharusnya' AS topik,
       (SELECT count(*) FROM (UNPIVOT (SELECT * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target Net Sales 2025', range = 'A3:N20', header = true) WHERE Channel IS NOT NULL) ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t)) AS terisi_2025,
       9 * 12 AS seharusnya_2025,
       (SELECT count(*) FROM (UNPIVOT (SELECT * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target Net Sales H1 2026', range = 'A3:H20', header = true) WHERE Channel IS NOT NULL) ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t)) AS terisi_2026,
       9 * 6 AS seharusnya_2026;
SELECT 'TARGET GM' AS topik, * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target GM', header = true);
