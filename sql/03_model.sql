-- 03_model: star schema (schema dw). Dimensi dulu, lalu fakta.
-- Input : tabel stg.*     Output: dw.dim_*, dw.fact_*  (bebas PII)
--
-- PERNYATAAN GRAIN
--   fact_sales          1 baris = 1 item baris transaksi VALID (POS: trx_id+line_no+sku; online: order_no+line_no+sku),
--                       setelah dedup, tanpa void/baris yang di-void, tanpa order CANCELLED, tanpa toko di luar master.
--   fact_sales_excluded 1 baris = 1 item baris yang BUKAN penjualan (void, baris asli yang di-void, order batal).
--   fact_returns        1 baris = 1 return_id (retur per item) yang terhubung ke penjualan valid.
--   fact_target         1 baris = (bulan, channel, region atau nasional).
--   fact_pos_sync       1 baris = (toko, tanggal bisnis) di sync log POS.
--
-- KEPUTUSAN SCD
--   (a) HPP: COGS memakai HPP as-of tanggal transaksi (dim_product_cost, SCD2). products.current_unit_cost TIDAK dipakai.
--   (b) Region toko: dim_store SCD2. Tiga kolom region di fakta: region_asof (region saat transaksi, deskriptif), region_current (saat ini),
--       dan region_target_basis = peta region pada AWAL TAHUN transaksi (Jan 1, atau open_date bila toko buka belakangan). Achievement vs target
--       dan filter Region dashboard memakai region_target_basis: target FP&A ditetapkan per tahun dan tidak disesuaikan saat BGR-01 pindah
--       Jawa Barat -> Jabodetabek pada 1 Jul 2025 (target Jawa Barat baru turun pada Jan 2026). Memakai region saat transaksi menciptakan
--       lonjakan palsu pada Jul 2025. Toko tanpa riwayat memakai stores.region sejak open_date (DQ-15).
--   (c) Tarif biaya channel: as-of tanggal transaksi (ref_channel_fee); fee dihitung per baris di fakta.

-- ============================ Dimensi ============================
CREATE OR REPLACE TABLE dw.dim_date AS
SELECT year(d) * 10000 + month(d) * 100 + day(d) AS date_key, d::DATE AS date, year(d) AS year, quarter(d) AS quarter,
       month(d) AS month, (['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'])[month(d)] AS month_name,
       strftime(d, '%Y-%m') AS year_month, date_trunc('month', d)::DATE AS month_start, day(d) AS day_of_month,
       isodow(d) AS day_of_week, (['Sen','Sel','Rab','Kam','Jum','Sab','Min'])[isodow(d)] AS day_name, isodow(d) >= 6 AS is_weekend,
       CASE WHEN month(d) <= 6 THEN 'H1' ELSE 'H2' END AS half, year(d)::VARCHAR || '-' || CASE WHEN month(d) <= 6 THEN 'H1' ELSE 'H2' END AS year_half
FROM generate_series(DATE '2024-01-01', DATE '2026-12-31', INTERVAL 1 DAY) t(d);

CREATE OR REPLACE TABLE dw.dim_channel AS
SELECT * FROM (VALUES (1, 'Store', 'Offline'), (2, 'Website', 'Online'), (3, 'Mobile App', 'Online'), (4, 'Marketplace', 'Online')) v(channel_key, channel_name, channel_type);

-- Tarif biaya channel as-of tanggal (Marketplace 9,0% -> 11,5% per 2025-04-01)
CREATE OR REPLACE TABLE dw.ref_channel_fee AS
SELECT c.channel_key, f.fee_pct, f.valid_from, f.valid_to
FROM stg.channel_fee f JOIN dw.dim_channel c ON c.channel_name = f.channel;

-- DQ-15: SCD2 region toko. Toko dengan riwayat memakai riwayatnya; toko lain satu baris dari stores.region.
CREATE OR REPLACE TABLE dw.dim_store AS
WITH periods AS (
  SELECT s.store_code, h.region, h.valid_from, h.valid_to FROM stg.store s JOIN stg.store_region_history h USING (store_code)
  UNION ALL
  SELECT s.store_code, s.region, s.open_date, DATE '9999-12-31' FROM stg.store s
  WHERE s.store_code NOT IN (SELECT store_code FROM stg.store_region_history)),
numbered AS (
  SELECT row_number() OVER (ORDER BY p.store_code, p.valid_from) AS store_key, p.store_code, s.store_name, s.city, s.province, s.store_type,
         s.open_date, s.selling_area_sqm, s.status, p.region, p.valid_from, p.valid_to, p.valid_to = DATE '9999-12-31' AS is_current
  FROM periods p JOIN stg.store s USING (store_code))
SELECT n.store_key, n.store_code, n.store_name, n.city, n.province, n.store_type, n.open_date, n.selling_area_sqm, n.status,
       n.region, max(n.region) FILTER (WHERE n.is_current) OVER (PARTITION BY n.store_code) AS region_current,
       n.valid_from, n.valid_to, n.is_current
FROM numbered n
UNION ALL
SELECT -1, 'ONLINE', 'Online (tanpa toko)', NULL, NULL, 'Online', NULL, NULL, 'Active', 'Tidak berlaku', 'Tidak berlaku', DATE '1900-01-01', DATE '9999-12-31', true;

CREATE OR REPLACE TABLE dw.dim_product AS
SELECT row_number() OVER (ORDER BY sku) AS product_key, sku, product_name, category, subcategory, brand,
       current_list_price AS list_price_current, launch_date
FROM stg.product;

-- DQ-13/SCD (a): HPP as-of
CREATE OR REPLACE TABLE dw.dim_product_cost AS
SELECT row_number() OVER (ORDER BY c.sku, c.valid_from) AS product_cost_key, p.product_key, c.sku, c.unit_cost,
       c.valid_from, c.valid_to, c.valid_to = DATE '9999-12-31' AS is_current
FROM stg.product_cost c LEFT JOIN dw.dim_product p USING (sku);

-- Tanpa PII. customer_key -1 = bukan member.
CREATE OR REPLACE TABLE dw.dim_customer AS
SELECT row_number() OVER (ORDER BY customer_id) AS customer_key, customer_id, member_tier, join_date, join_channel, age_band, possible_duplicate_member
FROM stg.customer
UNION ALL
SELECT -1, 'NON-MEMBER', 'Non-member', NULL, NULL, 'Tidak diketahui', false;

CREATE OR REPLACE TABLE dw.dim_promo AS
WITH p AS (
  SELECT promo_code, promo_name, promo_type, channel_scope, category_scope, discount_pct, start_date, end_date, budget_idr, member_only FROM stg.promo
  UNION ALL   -- DQ-07: kode korporat B2B dimasukkan agar tidak yatim
  SELECT 'B2B-CORP', 'Penjualan korporat B2B', 'B2B', 'Store', 'ALL', 0, NULL, NULL, NULL, false)
SELECT row_number() OVER (ORDER BY promo_code) AS promo_key, * FROM p
UNION ALL
SELECT -1, 'NONE', 'Tanpa promo', 'Tanpa promo', 'ALL', 'ALL', 0, NULL, NULL, NULL, false;

CREATE OR REPLACE TABLE dw.dim_store_event AS
SELECT row_number() OVER (ORDER BY store_code, start_date) AS event_key, store_code, event, start_date, end_date FROM stg.store_event;

-- ============================ Fakta penjualan ============================
CREATE OR REPLACE TABLE dw.fact_sales AS
WITH src AS (
  SELECT 'POS' AS source_system, 1 AS src_order, pos_rid AS src_rid, trx_id AS txn_id, line_no, ts AS sale_ts, sale_date,
         1 AS channel_key, store_code, member_id AS customer_id, sku, promo_code, payment_type AS payment_method,
         qty, unit_price, gross, discount, net, is_b2b_bulk, key_collision, CAST(NULL AS VARCHAR) AS online_region, 'GIVEN' AS province_source
  FROM stg.pos_line WHERE disposition = 'FACT'
  UNION ALL
  SELECT 'ONLINE', 2, o.online_rid, o.order_no, o.line_no, o.ts, o.sale_date, c.channel_key, NULL, o.customer_id, o.sku, o.voucher_code,
         o.payment_method, o.qty, o.price, o.gross, o.voucher, o.net, false, false, o.region, o.province_source
  FROM stg.online_line o LEFT JOIN dw.dim_channel c ON c.channel_name = o.channel WHERE o.disposition = 'FACT')
SELECT row_number() OVER (ORDER BY s.src_order, s.src_rid) AS sales_key,
       s.source_system, s.txn_id, s.line_no,
       year(s.sale_date) * 10000 + month(s.sale_date) * 100 + day(s.sale_date) AS date_key, s.sale_date, s.sale_ts,
       CASE WHEN s.source_system = 'ONLINE' THEN -1 ELSE st.store_key END AS store_key,
       s.channel_key, p.product_key,
       CASE WHEN s.customer_id IS NULL THEN -1 ELSE cu.customer_key END AS customer_key,
       CASE WHEN s.promo_code IS NULL THEN -1 ELSE pm.promo_key END AS promo_key,
       s.payment_method, s.qty, s.unit_price, s.gross AS gross_sales, s.discount, s.net AS net_sales,
       pc.unit_cost, s.qty * pc.unit_cost AS cogs, s.net - s.qty * pc.unit_cost AS gross_margin,
       fee.fee_pct AS channel_fee_pct, (s.net * fee.fee_pct / 100)::DECIMAL(18, 4) AS channel_fee,
       CASE WHEN s.source_system = 'POS' THEN st.region ELSE s.online_region END AS region_asof,
       CASE WHEN s.source_system = 'POS' THEN st.region_current ELSE s.online_region END AS region_current,
       CASE WHEN s.source_system = 'POS' THEN sb.region ELSE s.online_region END AS region_target_basis,
       s.customer_id IS NOT NULL AS is_member, s.is_b2b_bulk, s.key_collision, s.province_source
FROM src s
LEFT JOIN dw.dim_store st ON s.source_system = 'POS' AND st.store_code = s.store_code AND s.sale_date BETWEEN st.valid_from AND st.valid_to
LEFT JOIN dw.dim_store sb ON s.source_system = 'POS' AND sb.store_code = s.store_code
       AND greatest(make_date(year(s.sale_date), 1, 1), sb.open_date) BETWEEN sb.valid_from AND sb.valid_to
LEFT JOIN dw.dim_product p ON p.sku = s.sku
LEFT JOIN dw.dim_customer cu ON cu.customer_id = s.customer_id
LEFT JOIN dw.dim_promo pm ON pm.promo_code = s.promo_code
LEFT JOIN dw.dim_product_cost pc ON pc.product_key = p.product_key AND s.sale_date BETWEEN pc.valid_from AND pc.valid_to
LEFT JOIN dw.ref_channel_fee fee ON fee.channel_key = s.channel_key AND s.sale_date BETWEEN fee.valid_from AND fee.valid_to;

-- Baris yang bukan penjualan: dipakai untuk cancellation rate dan void rate; tidak ikut Net Sales.
CREATE OR REPLACE TABLE dw.fact_sales_excluded AS
WITH src AS (
  SELECT 'POS' AS source_system, 1 AS src_order, pos_rid AS src_rid, trx_id AS txn_id, line_no, sale_date, 1 AS channel_key,
         store_code, member_id AS customer_id, sku, qty, gross, discount, net, NULL AS online_region, replace(disposition, 'EXCLUDE_', '') AS exclude_reason
  FROM stg.pos_line WHERE disposition LIKE 'EXCLUDE\_%' ESCAPE '\'
  UNION ALL
  SELECT 'ONLINE', 2, o.online_rid, o.order_no, o.line_no, o.sale_date, c.channel_key, NULL, o.customer_id, o.sku, o.qty, o.gross, o.voucher, o.net,
         o.region, replace(o.disposition, 'EXCLUDE_', '')
  FROM stg.online_line o LEFT JOIN dw.dim_channel c ON c.channel_name = o.channel WHERE o.disposition LIKE 'EXCLUDE\_%' ESCAPE '\')
SELECT row_number() OVER (ORDER BY s.src_order, s.src_rid) AS excluded_key, s.source_system, s.txn_id, s.line_no,
       year(s.sale_date) * 10000 + month(s.sale_date) * 100 + day(s.sale_date) AS date_key, s.sale_date,
       CASE WHEN s.source_system = 'ONLINE' THEN -1 ELSE st.store_key END AS store_key, s.channel_key, p.product_key,
       CASE WHEN s.customer_id IS NULL THEN -1 ELSE cu.customer_key END AS customer_key,
       s.qty, s.gross AS gross_sales, s.discount, s.net AS net_sales,
       CASE WHEN s.source_system = 'POS' THEN st.region ELSE s.online_region END AS region_asof,
       CASE WHEN s.source_system = 'POS' THEN sb.region ELSE s.online_region END AS region_target_basis, s.exclude_reason
FROM src s
LEFT JOIN dw.dim_store st ON s.source_system = 'POS' AND st.store_code = s.store_code AND s.sale_date BETWEEN st.valid_from AND st.valid_to
LEFT JOIN dw.dim_store sb ON s.source_system = 'POS' AND sb.store_code = s.store_code
       AND greatest(make_date(year(s.sale_date), 1, 1), sb.open_date) BETWEEN sb.valid_from AND sb.valid_to
LEFT JOIN dw.dim_product p ON p.sku = s.sku
LEFT JOIN dw.dim_customer cu ON cu.customer_id = s.customer_id;

-- ============================ Fakta retur ============================
-- Atribut penjualan (toko, region as-of, pelanggan, tanggal jual) diambil dari penjualan asal pada grain (txn, produk).
CREATE OR REPLACE TABLE dw.fact_returns AS
WITH sale_ref AS (
  SELECT txn_id, product_key, min(sale_date) AS sale_date, min(store_key) AS store_key, min(region_asof) AS region_asof, min(region_target_basis) AS region_target_basis,
         min(customer_key) AS customer_key, min(channel_key) AS sale_channel_key
  FROM dw.fact_sales GROUP BY txn_id, product_key)
SELECT row_number() OVER (ORDER BY r.return_id) AS return_key, r.return_id,
       year(r.return_date) * 10000 + month(r.return_date) * 100 + day(r.return_date) AS return_date_key, r.return_date,
       sr.sale_date, date_diff('day', sr.sale_date, r.return_date) AS days_to_return,
       c.channel_key, sr.sale_channel_key, sr.store_key, sr.region_asof, sr.region_target_basis, p.product_key, sr.customer_key,
       r.original_trx_id AS original_txn_id, r.return_qty, r.refund_amount, r.return_reason
FROM stg.return_line r
LEFT JOIN dw.dim_channel c ON c.channel_name = r.channel
LEFT JOIN dw.dim_product p ON p.sku = r.sku
LEFT JOIN sale_ref sr ON sr.txn_id = r.original_trx_id AND sr.product_key = p.product_key
WHERE r.disposition = 'FACT';

-- ============================ Fakta target & sync ============================
CREATE OR REPLACE TABLE dw.fact_target AS
SELECT row_number() OVER (ORDER BY t.month_start, c.channel_key, t.region) AS target_key, t.month_start,
       year(t.month_start) * 10000 + month(t.month_start) * 100 + 1 AS date_key, c.channel_key, t.target_scope, t.region,
       t.target_net_sales, t.target_gm_pct
FROM stg.target_month t LEFT JOIN dw.dim_channel c ON c.channel_name = t.channel;

CREATE OR REPLACE TABLE dw.fact_pos_sync AS
SELECT row_number() OVER (ORDER BY s.store_code, s.business_date) AS sync_key, st.store_key, s.store_code, s.business_date,
       year(s.business_date) * 10000 + month(s.business_date) * 100 + day(s.business_date) AS date_key,
       s.sync_status, s.rows_uploaded, s.synced_at, s.sync_status = 'SUCCESS' AS is_complete
FROM stg.pos_sync s
LEFT JOIN dw.dim_store st ON st.store_code = s.store_code AND s.business_date BETWEEN st.valid_from AND st.valid_to;
