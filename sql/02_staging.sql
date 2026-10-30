-- 02_staging: pembersihan, tipe data, normalisasi, dedup, pasangan void, quarantine.
-- Input : TEMP view raw_* (01_load)     Output: tabel stg.* (bebas PII)
-- Urutan perlakuan transaksi: normalisasi format -> dedup persis -> pasangan void -> disposition.
-- Tidak ada baris yang dibuang diam-diam: tiap baris mentah berakhir di kolom `disposition`
--   FACT | EXCLUDE_* (bukan penjualan: void, batal) | REJECT_* (karantina karena data bermasalah)
-- dan tiap salinan duplikat tercatat di `n_copies`. Rekonsiliasi (04) menutup semuanya sampai selisih 0.
-- Referensi isu: reports/A3_issue_log.md (kode DQ-xx).

-- ============================ Makro pembersih (sesi saja) ============================
-- DQ-08: 12 label sales_channel -> 4 channel resmi; label tak dikenal -> NULL (ditolak, diuji di 06_tests)
CREATE OR REPLACE TEMP MACRO map_channel(x) AS CASE upper(trim(x))
  WHEN 'STORE' THEN 'Store'
  WHEN 'WEBSITE' THEN 'Website' WHEN 'WEB' THEN 'Website' WHEN 'WEB STORE' THEN 'Website'
  WHEN 'MOBILE APP' THEN 'Mobile App' WHEN 'APP' THEN 'Mobile App' WHEN 'MOBILE_APP' THEN 'Mobile App'
  WHEN 'MARKETPLACE' THEN 'Marketplace' WHEN 'MP' THEN 'Marketplace' END;

-- DQ-09: hanya dua pola harga yang dikenali: "100900" dan "Rp100.900". Pola lain -> NULL (ditolak), tidak ditebak.
CREATE OR REPLACE TEMP MACRO parse_price(x) AS CASE
  WHEN regexp_matches(x, '^[0-9]+$') THEN x::BIGINT
  WHEN regexp_matches(x, '^Rp[0-9]{1,3}(\.[0-9]{3})*$') THEN replace(replace(x, 'Rp', ''), '.', '')::BIGINT END;

-- DQ-14: label kategori tidak baku
CREATE OR REPLACE TEMP MACRO fix_category(c) AS CASE c
  WHEN 'Home Décor' THEN 'Home Decor' WHEN 'kitchen & dining' THEN 'Kitchen & Dining' ELSE c END;

-- ============================ Referensi pemetaan ============================
-- Provinsi tujuan -> 6 region resmi; provinsi lain -> 'Lainnya' (dipetakan lewat COALESCE di bawah).
-- Banten -> Jabodetabek: satu-satunya kota di data adalah Tangerang (toko TGR-01 juga Jabodetabek).
CREATE OR REPLACE TABLE stg.ref_province_region AS
SELECT * FROM (VALUES
  ('DKI Jakarta', 'Jabodetabek'), ('Banten', 'Jabodetabek'),
  ('Jawa Barat', 'Jawa Barat'),
  ('Jawa Tengah', 'Jateng & DIY'), ('DI Yogyakarta', 'Jateng & DIY'),
  ('Jawa Timur', 'Jawa Timur'),
  ('Bali', 'Bali & Nusa Tenggara'), ('Nusa Tenggara Barat', 'Bali & Nusa Tenggara'), ('Nusa Tenggara Timur', 'Bali & Nusa Tenggara'),
  ('Sumatera Utara', 'Sumatera'), ('Sumatera Barat', 'Sumatera'), ('Sumatera Selatan', 'Sumatera'), ('Riau', 'Sumatera'),
  ('Kepulauan Riau', 'Sumatera'), ('Jambi', 'Sumatera'), ('Bengkulu', 'Sumatera'), ('Lampung', 'Sumatera'),
  ('Kepulauan Bangka Belitung', 'Sumatera'), ('Aceh', 'Sumatera')
) v(province, region);

-- DQ-16: label region di Excel target tidak baku -> nama resmi
CREATE OR REPLACE TABLE stg.ref_target_region AS
SELECT * FROM (VALUES
  ('Bali Nusra', 'Bali & Nusa Tenggara'), ('JABODETABEK', 'Jabodetabek'), ('Jabar', 'Jawa Barat'),
  ('Jateng-DIY', 'Jateng & DIY'), ('Jatim', 'Jawa Timur'), ('Sumatra', 'Sumatera')
) v(label, region);

-- ============================ Master ============================
CREATE OR REPLACE TABLE stg.store AS
SELECT upper(trim(store_code)) AS store_code, store_name, city, province, region, store_type,
       try_cast(open_date AS DATE) AS open_date, try_cast(selling_area_sqm AS INTEGER) AS selling_area_sqm, status
FROM raw_stores;

CREATE OR REPLACE TABLE stg.store_region_history AS
SELECT upper(trim(store_code)) AS store_code, region, try_cast(valid_from AS DATE) AS valid_from,
       try_cast(valid_to AS DATE) AS valid_to, is_current = 'Y' AS is_current
FROM raw_region_hist;

CREATE OR REPLACE TABLE stg.store_event AS
SELECT upper(trim(store_code)) AS store_code, event, try_cast(start_date AS DATE) AS start_date, try_cast(end_date AS DATE) AS end_date
FROM raw_events;

-- DQ-13: SKU ganda (varian "(old)"): pertahankan satu per SKU, baris "(old)" ke karantina. DQ-14: kategori dibakukan.
CREATE OR REPLACE TEMP TABLE product_ranked AS
SELECT upper(trim(sku)) AS sku, product_name, fix_category(trim(category)) AS category, subcategory, brand,
       try_cast(current_list_price AS BIGINT) AS current_list_price, try_cast(current_unit_cost AS BIGINT) AS current_unit_cost,
       try_cast(launch_date AS DATE) AS launch_date,
       row_number() OVER (PARTITION BY upper(trim(sku)) ORDER BY (product_name LIKE '%(old)%'), product_name) AS rn
FROM raw_products;
CREATE OR REPLACE TABLE stg.product AS
SELECT * EXCLUDE (rn) FROM product_ranked WHERE rn = 1;
CREATE OR REPLACE TABLE stg.product_rejected AS
SELECT * EXCLUDE (rn), 'DUPLICATE_SKU_OLD_VARIANT' AS reject_reason FROM product_ranked WHERE rn > 1;

CREATE OR REPLACE TABLE stg.product_cost AS
SELECT upper(trim(sku)) AS sku, try_cast(unit_cost AS BIGINT) AS unit_cost,
       try_cast(valid_from AS DATE) AS valid_from, try_cast(valid_to AS DATE) AS valid_to
FROM raw_cost;

CREATE OR REPLACE TABLE stg.channel_fee AS
SELECT map_channel(channel) AS channel, try_cast(fee_pct_of_net_sales AS DECIMAL(5, 2)) AS fee_pct,
       try_cast(valid_from AS DATE) AS valid_from, try_cast(valid_to AS DATE) AS valid_to
FROM raw_fees;

CREATE OR REPLACE TABLE stg.promo AS
SELECT promo_code, promo_name,
       coalesce(nullif(regexp_extract(promo_name, '^(Ramadan|Clearance|Member Day|App Payday|Mega Sale|Harbolnas)', 1), ''), 'Lainnya') AS promo_type,
       channel_scope, category_scope, try_cast(discount_pct AS INTEGER) AS discount_pct,
       try_cast(start_date AS DATE) AS start_date, try_cast(end_date AS DATE) AS end_date,
       try_cast(budget_idr AS BIGINT) AS budget_idr, lower(member_only) = 'true' AS member_only
FROM raw_promos;

-- Customer: PII (full_name, phone, email, birth_date, gender, city) TIDAK dibawa. Hanya turunan aman.
-- DQ-18: birth_date sentinel 1900-01-01 / kosong -> age_band 'Tidak diketahui'.  DQ-19: email ganda -> flag, tidak digabung.
CREATE OR REPLACE TABLE stg.customer AS
WITH c AS (
  SELECT upper(trim(customer_id)) AS customer_id, member_tier, try_cast(join_date AS DATE) AS join_date,
         map_channel(join_channel) AS join_channel, try_cast(birth_date AS DATE) AS birth_date, nullif(lower(trim(email)), '') AS email
  FROM raw_customers),
dup_email AS (SELECT email FROM c WHERE email IS NOT NULL GROUP BY email HAVING count(*) > 1)
SELECT customer_id, member_tier, join_date, join_channel,
       CASE WHEN birth_date IS NULL OR birth_date = DATE '1900-01-01' THEN 'Tidak diketahui'
            WHEN date_diff('year', birth_date, DATE '2026-06-30') < 25 THEN '<25'
            WHEN date_diff('year', birth_date, DATE '2026-06-30') < 35 THEN '25-34'
            WHEN date_diff('year', birth_date, DATE '2026-06-30') < 45 THEN '35-44'
            WHEN date_diff('year', birth_date, DATE '2026-06-30') < 55 THEN '45-54'
            ELSE '55+' END AS age_band,
       coalesce(email IN (SELECT email FROM dup_email), false) AS possible_duplicate_member
FROM c;

CREATE OR REPLACE TABLE stg.pos_sync AS
SELECT upper(trim(store_code)) AS store_code, try_cast(business_date AS DATE) AS business_date, sync_status,
       try_cast(rows_uploaded AS INTEGER) AS rows_uploaded, try_cast(synced_at AS TIMESTAMP) AS synced_at
FROM raw_sync;

-- ============================ Transaksi POS ============================
CREATE OR REPLACE TABLE stg.pos_line AS
WITH norm AS (
  SELECT trx_id, try_cast(line_no AS INTEGER) AS line_no, try_cast(trx_datetime AS TIMESTAMP) AS ts,
         upper(trim(store_code)) AS store_code,                         -- DQ-01
         nullif(upper(trim(member_id)), '') AS member_id, upper(trim(sku)) AS sku,   -- DQ-03
         try_cast(qty AS INTEGER) AS qty, try_cast(unit_price AS BIGINT) AS unit_price,
         try_cast(discount_amount AS BIGINT) AS discount, promo_code, payment_type, cashier_id
  FROM raw_pos),
dedup AS (                                                              -- DQ-04: salinan persis jadi satu baris + n_copies
  SELECT *, count(*)::INTEGER AS n_copies FROM norm GROUP BY ALL),
numbered AS (                                                           -- urutan total -> pos_rid deterministik
  SELECT *, row_number() OVER (ORDER BY trx_id, line_no, sku, qty, unit_price, discount, ts, cashier_id, payment_type,
                                        store_code, member_id NULLS FIRST, promo_code NULLS FIRST) AS pos_rid
  FROM dedup),
valid_store AS (SELECT * FROM numbered WHERE store_code IN (SELECT store_code FROM stg.store)),
orig AS (SELECT pos_rid, trx_id, sku, qty, row_number() OVER (PARTITION BY trx_id, sku, qty ORDER BY pos_rid) AS rn FROM valid_store WHERE qty > 0),
vd   AS (SELECT pos_rid, trx_id, sku, qty, row_number() OVER (PARTITION BY trx_id, sku, -qty ORDER BY pos_rid) AS rn FROM valid_store WHERE qty < 0),
pairs AS (                                                              -- DQ-06: void dipasangkan 1:1 dengan baris asli
  SELECT o.pos_rid AS orig_rid, v.pos_rid AS void_rid
  FROM orig o JOIN vd v ON v.trx_id = o.trx_id AND v.sku = o.sku AND v.qty = -o.qty AND v.rn = o.rn),
collide AS (SELECT trx_id, line_no FROM numbered GROUP BY trx_id, line_no HAVING count(*) > 1)   -- DQ-05
SELECT n.*, n.ts::DATE AS sale_date, n.qty * n.unit_price AS gross, n.qty * n.unit_price - n.discount AS net,
       CASE WHEN n.qty IS NULL OR n.unit_price IS NULL OR n.discount IS NULL OR n.ts IS NULL OR n.line_no IS NULL THEN 'REJECT_UNPARSEABLE'
            WHEN NOT EXISTS (SELECT 1 FROM stg.store s WHERE s.store_code = n.store_code) THEN 'REJECT_STORE_NOT_IN_MASTER'   -- DQ-02 (TRN-99; juga store_code kosong)
            WHEN n.pos_rid IN (SELECT void_rid FROM pairs) THEN 'EXCLUDE_VOID'                              -- DQ-06a
            WHEN n.pos_rid IN (SELECT orig_rid FROM pairs) THEN 'EXCLUDE_VOIDED_ORIGINAL'                   -- DQ-06b
            WHEN n.qty < 0 THEN 'REJECT_VOID_WITHOUT_ORIGINAL'                                              -- DQ-06c
            ELSE 'FACT' END AS disposition,
       coalesce(n.promo_code = 'B2B-CORP', false) AS is_b2b_bulk,                                           -- DQ-07: dipertahankan, ditandai (bukan NULL untuk baris tanpa promo)
       EXISTS (SELECT 1 FROM collide c WHERE c.trx_id = n.trx_id AND c.line_no = n.line_no) AS key_collision
FROM numbered n;

-- ============================ Transaksi online ============================
CREATE OR REPLACE TABLE stg.online_line AS
WITH norm AS (
  SELECT order_no, try_cast(line_no AS INTEGER) AS line_no, try_strptime(order_date, '%d/%m/%Y %H:%M') AS ts,
         map_channel(sales_channel) AS channel,                         -- DQ-08
         upper(trim(customer_id)) AS customer_id, trim(ship_city) AS ship_city, nullif(trim(ship_province), '') AS ship_province,
         upper(trim(sku)) AS sku, try_cast(qty AS INTEGER) AS qty,
         parse_price(item_price) AS price,                              -- DQ-09
         voucher_code, try_cast(voucher_amount AS BIGINT) AS voucher, payment_method, order_status
  FROM raw_online),
dedup AS (SELECT *, count(*)::INTEGER AS n_copies FROM norm GROUP BY ALL),   -- DQ-10
-- DQ-12: provinsi kosong disimpulkan dari kota bila kota itu hanya pernah berpasangan dengan satu provinsi
city_province AS (
  SELECT ship_city, min(ship_province) AS province FROM dedup WHERE ship_province IS NOT NULL
  GROUP BY ship_city HAVING count(DISTINCT ship_province) = 1),
numbered AS (
  SELECT *, row_number() OVER (ORDER BY order_no, line_no, sku, qty, price, voucher, ts, channel, customer_id, ship_city,
                                        ship_province NULLS FIRST, voucher_code NULLS FIRST, payment_method, order_status) AS online_rid
  FROM dedup)
SELECT n.*, n.ts::DATE AS sale_date, n.qty * n.price AS gross, n.qty * n.price - n.voucher AS net,
       coalesce(n.ship_province, cp.province) AS province,
       CASE WHEN n.ship_province IS NOT NULL THEN 'GIVEN' WHEN cp.province IS NOT NULL THEN 'INFERRED_FROM_CITY' ELSE 'MISSING' END AS province_source,
       coalesce(pr.region, 'Lainnya') AS region,
       CASE WHEN n.qty IS NULL OR n.price IS NULL OR n.voucher IS NULL OR n.ts IS NULL OR n.line_no IS NULL THEN 'REJECT_UNPARSEABLE'
            WHEN n.channel IS NULL THEN 'REJECT_UNMAPPED_CHANNEL'
            WHEN n.order_status = 'COMPLETED' THEN 'FACT'
            WHEN n.order_status = 'CANCELLED' THEN 'EXCLUDE_CANCELLED'                                       -- DQ-11
            ELSE 'REJECT_UNKNOWN_STATUS' END AS disposition
FROM numbered n
LEFT JOIN city_province cp ON cp.ship_city = n.ship_city
LEFT JOIN stg.ref_province_region pr ON pr.province = coalesce(n.ship_province, cp.province);

-- ============================ Retur ============================
CREATE OR REPLACE TABLE stg.return_line AS
WITH n AS (
  SELECT return_id, try_cast(return_date AS DATE) AS return_date, upper(trim(original_trx_id)) AS original_trx_id,
         map_channel(channel) AS channel, upper(trim(store_code)) AS store_code, upper(trim(sku)) AS sku,
         try_cast(return_qty AS INTEGER) AS return_qty, try_cast(refund_amount AS BIGINT) AS refund_amount,
         CASE return_reason WHEN 'Barang cacat / tidak berfungsi' THEN 'Barang cacat' ELSE return_reason END AS return_reason  -- DQ-22
  FROM raw_returns)
SELECT n.*,
       CASE WHEN n.return_date IS NULL OR n.return_qty IS NULL OR n.refund_amount IS NULL OR n.channel IS NULL THEN 'REJECT_UNPARSEABLE'
            WHEN EXISTS (SELECT 1 FROM stg.pos_line p WHERE p.trx_id = n.original_trx_id AND p.sku = n.sku AND p.disposition = 'FACT')
              OR EXISTS (SELECT 1 FROM stg.online_line o WHERE o.order_no = n.original_trx_id AND o.sku = n.sku AND o.disposition = 'FACT') THEN 'FACT'
            WHEN EXISTS (SELECT 1 FROM stg.pos_line p WHERE p.trx_id = n.original_trx_id AND p.sku = n.sku)
              OR EXISTS (SELECT 1 FROM stg.online_line o WHERE o.order_no = n.original_trx_id AND o.sku = n.sku) THEN 'REJECT_ORIGINAL_EXCLUDED'
            ELSE 'REJECT_ORPHAN' END AS disposition                                                          -- DQ-21
FROM n;

-- ============================ Target (unpivot dari format lebar) ============================
-- DQ-16: bulan melebar -> baris; label region dibakukan; Store = per region, online = nasional per channel.
CREATE OR REPLACE TABLE stg.target_month AS
WITH u AS (
  SELECT Channel, Region, m, t FROM (UNPIVOT raw_target_2025 ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t)
  UNION ALL
  SELECT Channel, Region, m, t FROM (UNPIVOT raw_target_2026 ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t))
SELECT strptime(u.m, '%b-%y')::DATE AS month_start,
       map_channel(u.Channel) AS channel,
       CASE WHEN u.Channel = 'Store' THEN 'REGION' ELSE 'NATIONAL' END AS target_scope,
       CASE WHEN u.Channel = 'Store' THEN r.region ELSE 'Nasional' END AS region,
       u.t::BIGINT AS target_net_sales,
       CASE WHEN year(strptime(u.m, '%b-%y')) = 2025 THEN g."Target Gross Margin % (2025)"
            ELSE g."Target Gross Margin % (H1 2026)" END::DECIMAL(5, 2) AS target_gm_pct
FROM u
LEFT JOIN stg.ref_target_region r ON r.label = u.Region AND u.Channel = 'Store'
LEFT JOIN raw_target_gm g ON g.Channel = u.Channel;
