-- Task 1 / profiling 2: kuantifikasi Data Quality Issue Log (baris + Rp terdampak) dan pengecekan yang lolos
-- Input : raw_data/*  (read-only). Output: hanya tampil di layar; tidak ada tabel permanen.
-- Jalankan dari root project:  duckdb -markdown < sql/profiling/02_issue_impact.sql
-- Definisi "Rp terdampak": nilai bersih baris terdampak = qty*harga - diskon/voucher (belum dikurangi retur,
-- tanpa pajak). Untuk isu retur = refund_amount. Untuk void = nilai absolut. Hitungan duplikat/void/B2B
-- dilakukan SETELAH normalisasi (urutan pipeline: normalisasi -> dedup -> void), sama dengan staging nanti.
-- Kode DQ-xx dipakai juga sebagai komentar di sql/02_staging.sql.
INSTALL excel; LOAD excel;

CREATE TEMP MACRO map_channel(x) AS CASE upper(trim(x))
  WHEN 'WEBSITE' THEN 'Website' WHEN 'WEB' THEN 'Website' WHEN 'WEB STORE' THEN 'Website'
  WHEN 'MOBILE APP' THEN 'Mobile App' WHEN 'APP' THEN 'Mobile App' WHEN 'MOBILE_APP' THEN 'Mobile App'
  WHEN 'MARKETPLACE' THEN 'Marketplace' WHEN 'MP' THEN 'Marketplace' END;

-- Harga online hanya dua pola yang dikenal: angka polos ("100900") dan "Rp100.900". Pola lain -> NULL
-- (tertangkap pengecekan "harga gagal di-parse"), bukan ditebak dengan membuang semua titik.
CREATE TEMP MACRO parse_price(x) AS CASE
  WHEN regexp_matches(x, '^[0-9]+$') THEN x::BIGINT
  WHEN regexp_matches(x, '^Rp[0-9]{1,3}(\.[0-9]{3})*$') THEN replace(replace(x, 'Rp', ''), '.', '')::BIGINT END;

-- try_cast (bukan ::) agar satu nilai rusak tidak menggagalkan skrip; jumlahnya dihitung di pengecekan "cast gagal".
CREATE TEMP VIEW pos AS
SELECT trx_id, try_cast(line_no AS INT) AS line_no, try_cast(trx_datetime AS TIMESTAMP) AS ts,
       store_code AS store_raw, upper(trim(store_code)) AS store_code,
       member_id, sku AS sku_raw, upper(trim(sku)) AS sku, try_cast(qty AS INT) AS qty,
       try_cast(unit_price AS BIGINT) AS unit_price, try_cast(discount_amount AS BIGINT) AS discount, promo_code, payment_type, cashier_id,
       try_cast(qty AS INT) * try_cast(unit_price AS BIGINT) - try_cast(discount_amount AS BIGINT) AS net
FROM read_csv('raw_data/sales_pos_transactions.csv', all_varchar = true);

-- dedup hanya pada kolom ternormalisasi (kolom *_raw dibuang agar beda format tidak mencegah dedup)
CREATE TEMP VIEW pos_dd AS
SELECT DISTINCT trx_id, line_no, ts, store_code, member_id, sku, qty, unit_price, discount, promo_code, payment_type, cashier_id, net
FROM pos;

CREATE TEMP VIEW onl AS
SELECT order_no, try_cast(line_no AS INT) AS line_no, try_strptime(order_date, '%d/%m/%Y %H:%M') AS ts,
       sales_channel AS channel_raw, map_channel(sales_channel) AS channel, customer_id, ship_province,
       upper(trim(sku)) AS sku, try_cast(qty AS INT) AS qty, item_price AS price_raw,
       parse_price(item_price) AS price,
       voucher_code, try_cast(voucher_amount AS BIGINT) AS voucher, order_status,
       try_cast(qty AS INT) * parse_price(item_price) - try_cast(voucher_amount AS BIGINT) AS net
FROM read_csv('raw_data/sales_online_orders.csv', all_varchar = true);

CREATE TEMP VIEW onl_dd AS
SELECT DISTINCT order_no, line_no, ts, channel, customer_id, ship_province, sku, qty, price, voucher_code, voucher, order_status, net
FROM onl;

-- pasangan void 1:1: tiap void dipasangkan dengan satu baris positif asli (trx_id, sku sama, qty berlawanan)
CREATE TEMP VIEW pos_rid AS
-- ORDER BY memuat SEMUA kolom pos_dd (urutan total) agar pasangan void tidak berubah antar-run
SELECT *, row_number() OVER (ORDER BY trx_id, line_no, sku, qty, unit_price, discount, cashier_id, payment_type, ts, store_code,
                                      member_id NULLS FIRST, promo_code NULLS FIRST) AS rid
FROM pos_dd;
CREATE TEMP VIEW pos_match AS
SELECT o.rid AS orig_rid, v.rid AS void_rid
FROM (SELECT *, row_number() OVER (PARTITION BY trx_id, sku, qty ORDER BY rid) AS rn FROM pos_rid WHERE qty > 0) o
JOIN (SELECT *, row_number() OVER (PARTITION BY trx_id, sku, -qty ORDER BY rid) AS rn FROM pos_rid WHERE qty < 0) v
  ON v.trx_id = o.trx_id AND v.sku = o.sku AND v.qty = -o.qty AND v.rn = o.rn;

CREATE TEMP VIEW prod AS SELECT * FROM read_csv('raw_data/products.csv');
CREATE TEMP VIEW dup_sku AS SELECT sku FROM prod GROUP BY sku HAVING count(*) > 1;
CREATE TEMP VIEW bad_cat_sku AS
SELECT DISTINCT sku FROM prod WHERE category NOT IN
  ('Fashion','Kitchen & Dining','Home Decor','Bedding & Bath','Beauty & Personal Care','Storage & Organizer','Elektronik Rumah Tangga');

-- Populasi "penjualan valid" = dedup, tanpa void dan baris asli yang di-void, tanpa TRN-99.
-- Dipakai untuk semua isu master/region (DQ-13/14/15/17) agar Rp-nya sama dengan basis rekonsiliasi Task 2.
CREATE TEMP VIEW pos_clean AS
SELECT d.* FROM pos_rid d
WHERE d.qty > 0 AND d.store_code <> 'TRN-99' AND d.rid NOT IN (SELECT orig_rid FROM pos_match);

-- Qty terjual per (id transaksi, sku): POS valid + online COMPLETED. Dipakai untuk uji retur.
CREATE TEMP VIEW sold AS
SELECT trx_id AS id, sku, sum(qty) AS sold_qty FROM pos_clean GROUP BY 1, 2
UNION ALL
SELECT order_no, sku, sum(qty) FROM onl_dd WHERE order_status = 'COMPLETED' GROUP BY 1, 2;

-- Pemakaian promo (POS promo_code + online voucher_code), tanpa B2B-CORP dan tanpa void. Untuk uji masa berlaku/scope.
CREATE TEMP MACRO fix_cat(c) AS CASE c WHEN 'Home Décor' THEN 'Home Decor' WHEN 'kitchen & dining' THEN 'Kitchen & Dining' ELSE c END;
CREATE TEMP VIEW promo_use AS
SELECT p.ts::DATE AS d, 'Store' AS channel, p.member_id AS who, p.sku, p.promo_code AS code, p.discount AS amt
FROM pos_dd p WHERE p.promo_code IS NOT NULL AND p.promo_code <> 'B2B-CORP' AND p.qty > 0
UNION ALL
SELECT o.ts::DATE, o.channel, o.customer_id, o.sku, o.voucher_code, o.voucher FROM onl_dd o WHERE o.voucher_code IS NOT NULL;

-- Dasar estimasi hari tak lengkap/tutup: penjualan harian valid per toko, TANPA B2B bulk (outlier),
-- dan hari SUCCESS tanpa baris POS dihitung 0 (bukan dibuang dari rata-rata).
CREATE TEMP VIEW store_day AS
SELECT l.store_code, l.business_date AS d, coalesce(sum(c.net), 0) AS net
FROM read_csv('raw_data/pos_sync_log.csv') l
LEFT JOIN pos_clean c ON c.store_code = l.store_code AND c.ts::DATE = l.business_date AND c.promo_code IS DISTINCT FROM 'B2B-CORP'
WHERE l.sync_status = 'SUCCESS'
GROUP BY 1, 2;

-- ============================ A. DAMPAK PER ISU ============================
CREATE TEMP TABLE impact AS
-- POS
SELECT 'DQ-01' AS id, 'POS' AS src, 'store_code huruf kecil (jkt-01) -> upper/trim' AS issue,
       count(*) AS rows_affected, sum(net) AS rp_affected, 'semua baris terdampak' AS basis
FROM pos WHERE store_raw <> upper(trim(store_raw))
UNION ALL SELECT 'DQ-02', 'POS', 'store_code TRN-99 tidak ada di stores.csv / sync log / target',
       count(*), sum(net), 'baris TRN-99 (setelah upper)'
FROM pos WHERE store_code = 'TRN-99'
UNION ALL SELECT 'DQ-03', 'POS', 'sku ber-spasi / huruf kecil (gagal join ke products & HPP)',
       count(*), sum(net), 'semua baris terdampak'
FROM pos WHERE sku_raw <> sku
UNION ALL SELECT 'DQ-04', 'POS', 'duplikat persis (trx_id,line_no) setelah normalisasi: baris ekstra',
       coalesce(sum(n - 1), 0), coalesce(sum((n - 1) * net1), 0), 'baris ekstra (1 salinan dipertahankan)'
FROM (SELECT trx_id, line_no, count(*) n, max(net) net1,
             count(DISTINCT (ts, store_code, cashier_id, member_id, sku, qty, unit_price, discount, promo_code, payment_type)) nd
      FROM pos GROUP BY 1, 2 HAVING count(*) > 1) WHERE nd = 1
UNION ALL SELECT 'DQ-05', 'POS', 'tabrakan nomor struk: (trx_id,line_no) sama tapi item/kasir/bayar beda (grup)',
       count(*), sum(rows_in_group), 'rows_affected = jumlah grup; Rp = nilai absolut semua baris dalam grup'
FROM (SELECT trx_id, line_no, sum(abs(net)) AS rows_in_group
      FROM pos_dd GROUP BY 1, 2 HAVING count(*) > 1)
UNION ALL SELECT 'DQ-06a', 'POS', 'void kasir (qty<0) setelah dedup',
       count(*), sum(-net), 'nilai absolut void'
FROM pos_rid WHERE qty < 0
UNION ALL SELECT 'DQ-06b', 'POS', 'baris asli yang dibatalkan void (dipasangkan 1:1)',
       count(*), sum(net), 'nilai baris asli'
FROM pos_rid WHERE rid IN (SELECT orig_rid FROM pos_match)
UNION ALL SELECT 'DQ-06c', 'POS', 'void tanpa pasangan baris asli',
       count(*), coalesce(sum(-net), 0), 'nilai absolut void'
FROM pos_rid WHERE qty < 0 AND rid NOT IN (SELECT void_rid FROM pos_match)
UNION ALL SELECT 'DQ-07', 'POS', 'pembelian B2B bulk (trx_id *-B2B*, promo B2B-CORP tak ada di promotions, qty 152-446)',
       count(*), sum(net), 'baris B2B'
FROM pos_dd WHERE promo_code = 'B2B-CORP'
-- ONLINE
UNION ALL SELECT 'DQ-08', 'ONLINE', '12 label sales_channel -> 3 channel resmi',
       count(*), sum(net), 'baris dengan label tidak baku (termasuk CANCELLED)'
FROM onl WHERE channel_raw NOT IN ('Website', 'Mobile App', 'Marketplace')
UNION ALL SELECT 'DQ-09', 'ONLINE', 'item_price berformat teks "Rp100.900"',
       count(*), sum(net), 'baris berformat Rp (termasuk CANCELLED)'
FROM onl WHERE price_raw LIKE 'Rp%'
UNION ALL SELECT 'DQ-10', 'ONLINE', 'duplikat persis (order_no,line_no): baris ekstra',
       sum(n - 1), sum((n - 1) * net1), 'baris ekstra (1 salinan dipertahankan)'
FROM (SELECT order_no, line_no, count(*) n, max(net) net1 FROM onl GROUP BY 1, 2 HAVING count(*) > 1)
UNION ALL SELECT 'DQ-11', 'ONLINE', 'order_status CANCELLED (setelah dedup)',
       count(*), sum(net), 'dikeluarkan dari Net Sales'
FROM onl_dd WHERE order_status = 'CANCELLED'
UNION ALL SELECT 'DQ-12', 'ONLINE', 'ship_province kosong -> region Lainnya',
       count(*), sum(net), 'baris COMPLETED setelah dedup'
FROM onl_dd WHERE ship_province IS NULL AND order_status = 'COMPLETED'
-- MASTER
UNION ALL SELECT 'DQ-13', 'PRODUCTS', 'SKU ganda di products.csv (varian "(old)") -> join menggandakan fakta',
       (SELECT count(*) FROM pos_clean WHERE sku IN (SELECT sku FROM dup_sku)) + (SELECT count(*) FROM onl_dd WHERE order_status = 'COMPLETED' AND sku IN (SELECT sku FROM dup_sku)),
       (SELECT coalesce(sum(net), 0) FROM pos_clean WHERE sku IN (SELECT sku FROM dup_sku)) + (SELECT coalesce(sum(net), 0) FROM onl_dd WHERE order_status = 'COMPLETED' AND sku IN (SELECT sku FROM dup_sku)),
       'baris penjualan pada 6 SKU ganda (akan terhitung 2x bila join naif)'
UNION ALL SELECT 'DQ-14', 'PRODUCTS', 'label kategori tidak baku (Home Décor, kitchen & dining)',
       (SELECT count(*) FROM pos_clean WHERE sku IN (SELECT sku FROM bad_cat_sku)) + (SELECT count(*) FROM onl_dd WHERE order_status = 'COMPLETED' AND sku IN (SELECT sku FROM bad_cat_sku)),
       (SELECT coalesce(sum(net), 0) FROM pos_clean WHERE sku IN (SELECT sku FROM bad_cat_sku)) + (SELECT coalesce(sum(net), 0) FROM onl_dd WHERE order_status = 'COMPLETED' AND sku IN (SELECT sku FROM bad_cat_sku)),
       'baris penjualan pada SKU berlabel tidak baku (kategori & scope promo salah)'
UNION ALL SELECT 'DQ-15', 'STORES', 'store_region_history hanya memuat BGR-01: penjualan BGR-01 sebelum 1 Jul 2025 harus di region Jawa Barat',
       count(*), sum(net), 'penjualan POS BGR-01 < 2025-07-01 (akan salah region bila pakai stores.region)'
FROM pos_clean WHERE store_code = 'BGR-01' AND ts < '2025-07-01'
UNION ALL SELECT 'DQ-16', 'TARGET', 'label region target tidak baku (Jabar, Jatim, Sumatra, Jateng-DIY, Bali Nusra, JABODETABEK) + format lebar',
       (SELECT count(*) FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet='Target Net Sales 2025', range='A3:N20', header=true) WHERE Channel='Store')
     + (SELECT count(*) FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet='Target Net Sales H1 2026', range='A3:H20', header=true) WHERE Channel='Store'),
       (SELECT sum(t) FROM (UNPIVOT (SELECT * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet='Target Net Sales 2025', range='A3:N20', header=true) WHERE Channel='Store') ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t)) +
            (SELECT sum(t) FROM (UNPIVOT (SELECT * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet='Target Net Sales H1 2026', range='A3:H20', header=true) WHERE Channel='Store') ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t)),
       'rows = baris region (6 x 2 sheet); Rp = total target Store 2025 + H1 2026'
UNION ALL SELECT 'DQ-17', 'PRODUCTS', 'baris penjualan sebelum launch_date produk: semuanya baris asli yang kemudian di-void (tercakup DQ-06b)',
       count(*), sum(net), 'OBSERVASI: penjualan valid pra-launch = 0 (lihat pengecekan bagian B)'
FROM pos_rid d JOIN (SELECT DISTINCT sku, launch_date FROM prod) p USING (sku)
WHERE d.qty > 0 AND d.ts::DATE < p.launch_date
-- CUSTOMERS (hanya hitungan; tidak ada nilai PII ditampilkan)
UNION ALL SELECT 'DQ-18', 'CUSTOMERS', 'birth_date sentinel 1900-01-01 (PII; diturunkan jadi age_band "Unknown")',
       count(*), NULL, 'member'
FROM read_csv('raw_data/customers.csv') WHERE birth_date = '1900-01-01'
UNION ALL SELECT 'DQ-19', 'CUSTOMERS', 'email ganda antar member (kandidat duplikat orang yang sama)',
       sum(n), (SELECT sum(net) FROM (SELECT member_id AS cid, net FROM pos_dd WHERE member_id IS NOT NULL UNION ALL SELECT customer_id, net FROM onl_dd WHERE order_status = 'COMPLETED')
                WHERE cid IN (SELECT customer_id FROM read_csv('raw_data/customers.csv') WHERE email IN
                  (SELECT email FROM read_csv('raw_data/customers.csv') WHERE email IS NOT NULL GROUP BY email HAVING count(*) > 1))),
       'rows = member dalam grup email ganda; Rp = net sales member tsb (risiko Repeat Rate tidak akurat)'
FROM (SELECT count(*) n FROM read_csv('raw_data/customers.csv') WHERE email IS NOT NULL GROUP BY email HAVING count(*) > 1)
UNION ALL SELECT 'DQ-20', 'CUSTOMERS', 'member tanpa transaksi apa pun',
       count(*), NULL, 'member'
FROM read_csv('raw_data/customers.csv') c
WHERE NOT EXISTS (SELECT 1 FROM pos_dd p WHERE p.member_id = c.customer_id)
  AND NOT EXISTS (SELECT 1 FROM onl_dd o WHERE o.customer_id = c.customer_id)
-- RETURNS
UNION ALL SELECT 'DQ-21', 'RETURNS', 'retur yatim: original_trx_id tidak ada di POS maupun online',
       count(*), sum(refund_amount), 'refund_amount'
FROM read_csv('raw_data/returns.csv') r
WHERE NOT EXISTS (SELECT 1 FROM pos_dd p WHERE p.trx_id = r.original_trx_id)
  AND NOT EXISTS (SELECT 1 FROM onl_dd o WHERE o.order_no = r.original_trx_id)
UNION ALL SELECT 'DQ-22', 'RETURNS', 'label alasan "Barang cacat / tidak berfungsi" = "Barang cacat"',
       count(*), sum(refund_amount), 'refund_amount baris berlabel varian'
FROM read_csv('raw_data/returns.csv') WHERE return_reason = 'Barang cacat / tidak berfungsi'
-- SYNC (estimasi = hari terdampak x rata-rata harian valid tanpa B2B pada jendela sebelum dan sesudah; hari kosong dihitung 0)
UNION ALL SELECT 'DQ-23', 'SYNC_LOG', 'sync FAILED BDG-02 3-9 Nov 2025 (data toko tidak terkirim, tidak ada baris POS)',
       (SELECT count(*) FROM read_csv('raw_data/pos_sync_log.csv') WHERE sync_status = 'FAILED' AND store_code = 'BDG-02'),
       (SELECT CAST(round((SELECT count(*) FROM read_csv('raw_data/pos_sync_log.csv') WHERE sync_status = 'FAILED' AND store_code = 'BDG-02') * avg(net)) AS BIGINT)
          FROM store_day WHERE store_code = 'BDG-02' AND (d BETWEEN '2025-10-06' AND '2025-11-02' OR d BETWEEN '2025-11-10' AND '2025-12-07')),
       'ESTIMASI penjualan hilang = hari FAILED x rata-rata harian 4 minggu sebelum+sesudah'
UNION ALL SELECT 'DQ-24', 'SYNC_LOG', 'STORE_CLOSED SBY-01 4 Agu-21 Sep 2025 = renovasi (kejadian bisnis, bukan masalah data)',
       (SELECT count(*) FROM read_csv('raw_data/pos_sync_log.csv') WHERE sync_status = 'STORE_CLOSED' AND store_code = 'SBY-01'),
       (SELECT CAST(round((SELECT count(*) FROM read_csv('raw_data/pos_sync_log.csv') WHERE sync_status = 'STORE_CLOSED' AND store_code = 'SBY-01') * avg(net)) AS BIGINT)
          FROM store_day WHERE store_code = 'SBY-01' AND (d BETWEEN '2025-06-09' AND '2025-08-03' OR d BETWEEN '2025-09-22' AND '2025-11-16')),
       'ESTIMASI penjualan tertahan = hari tutup x rata-rata harian 8 minggu sebelum+sesudah (indikatif)';

SELECT id, src, issue, rows_affected, rp_affected, basis FROM impact ORDER BY id;

-- ============================ B. PENGECEKAN YANG LOLOS (0 pelanggaran) ============================
SELECT check_name, n_violations FROM (
  SELECT 'POS: transaksi di luar 2024-01-01..2026-06-30' AS check_name, count(*) AS n_violations FROM pos WHERE ts < '2024-01-01' OR ts >= '2026-07-01'
  UNION ALL SELECT 'POS: unit_price <= 0', count(*) FROM pos WHERE unit_price <= 0
  UNION ALL SELECT 'POS: diskon > nilai kotor baris', count(*) FROM pos WHERE qty > 0 AND discount > qty * unit_price
  UNION ALL SELECT 'POS: member_id tidak ada di customers', count(*) FROM pos WHERE member_id IS NOT NULL AND member_id NOT IN (SELECT customer_id FROM read_csv('raw_data/customers.csv'))
  UNION ALL SELECT 'POS: sku tidak ada di products (setelah normalisasi)', count(*) FROM pos WHERE sku NOT IN (SELECT sku FROM prod)
  UNION ALL SELECT 'POS: prefix trx_id <> store_code', count(*) FROM pos WHERE upper(split_part(trx_id,'-',1) || '-' || split_part(trx_id,'-',2)) <> store_code
  UNION ALL SELECT 'POS: promo_code tidak ada di promotions (selain B2B-CORP)', count(*) FROM pos WHERE promo_code IS NOT NULL AND promo_code <> 'B2B-CORP' AND promo_code NOT IN (SELECT promo_code FROM read_csv('raw_data/promotions.csv'))
  UNION ALL SELECT 'POS: penjualan sebelum open_date toko', count(*) FROM pos p JOIN read_csv('raw_data/stores.csv') s USING (store_code) WHERE p.ts::DATE < s.open_date
  UNION ALL SELECT 'POS: penjualan pada hari FAILED/STORE_CLOSED', count(*) FROM pos p JOIN read_csv('raw_data/pos_sync_log.csv') l ON l.store_code = p.store_code AND l.business_date = p.ts::DATE WHERE l.sync_status <> 'SUCCESS'
  UNION ALL SELECT 'POS: penjualan pada hari tanpa catatan sync log (toko master)', count(*) FROM pos p WHERE p.store_code <> 'TRN-99' AND NOT EXISTS (SELECT 1 FROM read_csv('raw_data/pos_sync_log.csv') l WHERE l.store_code = p.store_code AND l.business_date = p.ts::DATE)
  UNION ALL SELECT 'ONLINE: tanggal di luar periode', count(*) FROM onl WHERE ts < '2024-01-01' OR ts >= '2026-07-01'
  UNION ALL SELECT 'ONLINE: harga gagal di-parse / <= 0', count(*) FROM onl WHERE price IS NULL OR price <= 0
  UNION ALL SELECT 'ONLINE: qty <= 0', count(*) FROM onl WHERE qty <= 0
  UNION ALL SELECT 'ONLINE: label channel tak terpetakan', count(*) FROM onl WHERE channel IS NULL
  UNION ALL SELECT 'ONLINE: order dengan >1 channel setelah mapping', count(*) FROM (SELECT order_no FROM onl GROUP BY 1 HAVING count(DISTINCT channel) > 1)
  UNION ALL SELECT 'ONLINE: customer_id tidak ada di customers', count(*) FROM onl WHERE customer_id NOT IN (SELECT customer_id FROM read_csv('raw_data/customers.csv'))
  UNION ALL SELECT 'ONLINE: sku tidak ada di products', count(*) FROM onl WHERE sku NOT IN (SELECT sku FROM prod)
  UNION ALL SELECT 'ONLINE: voucher > nilai kotor', count(*) FROM onl WHERE voucher > qty * price
  UNION ALL SELECT 'ONLINE: voucher_code tidak ada di promotions', count(*) FROM onl WHERE voucher_code IS NOT NULL AND voucher_code NOT IN (SELECT promo_code FROM read_csv('raw_data/promotions.csv'))
  UNION ALL SELECT 'ONLINE: voucher bernilai tanpa kode / kode tanpa nilai', count(*) FROM onl WHERE (voucher_code IS NULL) <> (voucher = 0)
  UNION ALL SELECT 'ONLINE: duplikat dengan nilai/status berbeda (konflik)', count(*) FROM (SELECT order_no, line_no FROM onl GROUP BY 1, 2 HAVING count(DISTINCT (ts, channel, customer_id, sku, qty, price, voucher, order_status)) > 1)
  UNION ALL SELECT 'HPP: periode tumpang tindih', count(*) FROM read_csv('raw_data/product_cost_history.csv') a JOIN read_csv('raw_data/product_cost_history.csv') b ON a.sku = b.sku AND a.valid_from < b.valid_from AND a.valid_to >= b.valid_from
  UNION ALL SELECT 'HPP: celah antar periode', count(*) FROM (SELECT valid_to, lead(valid_from) OVER (PARTITION BY sku ORDER BY valid_from) nxt FROM read_csv('raw_data/product_cost_history.csv')) WHERE nxt IS NOT NULL AND nxt <> valid_to + INTERVAL 1 DAY
  UNION ALL SELECT 'HPP: SKU products tanpa riwayat', count(*) FROM (SELECT DISTINCT sku FROM prod) WHERE sku NOT IN (SELECT sku FROM read_csv('raw_data/product_cost_history.csv'))
  UNION ALL SELECT 'HPP: current_unit_cost <> HPP aktif di riwayat', count(*) FROM (SELECT DISTINCT sku, current_unit_cost FROM prod) p JOIN read_csv('raw_data/product_cost_history.csv') h ON h.sku = p.sku AND h.valid_to = '9999-12-31' WHERE h.unit_cost <> p.current_unit_cost
  UNION ALL SELECT 'HPP: HPP >= harga jual', count(*) FROM (SELECT DISTINCT sku, current_list_price, current_unit_cost FROM prod) WHERE current_unit_cost >= current_list_price
  UNION ALL SELECT 'PROMO: tanggal mulai > selesai / budget <= 0', count(*) FROM read_csv('raw_data/promotions.csv') WHERE start_date > end_date OR budget_idr <= 0
  UNION ALL SELECT 'RETUR: return_id duplikat', count(*) - count(DISTINCT return_id) FROM read_csv('raw_data/returns.csv')
  UNION ALL SELECT 'RETUR: qty/refund <= 0', count(*) FROM read_csv('raw_data/returns.csv') WHERE return_qty <= 0 OR refund_amount <= 0
  UNION ALL SELECT 'RETUR: store_code tidak di master', count(*) FROM read_csv('raw_data/returns.csv') WHERE store_code IS NOT NULL AND store_code NOT IN (SELECT store_code FROM read_csv('raw_data/stores.csv'))
  UNION ALL SELECT 'RETUR: sku tidak cocok dgn baris asal (POS dan online)', count(*) FROM read_csv('raw_data/returns.csv') r
    WHERE (r.original_trx_id IN (SELECT trx_id FROM pos_dd) AND NOT EXISTS (SELECT 1 FROM pos_dd p WHERE p.trx_id = r.original_trx_id AND p.sku = upper(trim(r.sku))))
       OR (r.original_trx_id IN (SELECT order_no FROM onl_dd) AND NOT EXISTS (SELECT 1 FROM onl_dd o WHERE o.order_no = r.original_trx_id AND o.sku = upper(trim(r.sku))))
  UNION ALL SELECT 'RETUR: qty satu retur > qty terjual', count(*) FROM read_csv('raw_data/returns.csv') r JOIN sold s ON s.id = r.original_trx_id AND s.sku = upper(trim(r.sku)) WHERE r.return_qty > s.sold_qty
  UNION ALL SELECT 'RETUR: refund > nilai jual item (qty retur x harga satuan)', count(*) FROM read_csv('raw_data/returns.csv') r
    JOIN (SELECT trx_id AS id, sku, max(unit_price) AS price FROM pos_clean GROUP BY 1, 2 UNION ALL SELECT order_no, sku, max(price) FROM onl_dd WHERE order_status = 'COMPLETED' GROUP BY 1, 2) u
      ON u.id = r.original_trx_id AND u.sku = upper(trim(r.sku)) WHERE r.refund_amount > r.return_qty * u.price
  UNION ALL SELECT 'RETUR: tanggal retur < tanggal order (online)', count(*) FROM read_csv('raw_data/returns.csv') r JOIN (SELECT order_no, min(ts::DATE) d FROM onl_dd GROUP BY 1) o ON o.order_no = r.original_trx_id WHERE r.return_date < o.d
  UNION ALL SELECT 'RETUR: channel retur <> channel order (online)', count(*) FROM read_csv('raw_data/returns.csv') r JOIN (SELECT order_no, any_value(channel) AS channel FROM onl_dd GROUP BY 1) o ON o.order_no = r.original_trx_id WHERE r.channel <> o.channel
  UNION ALL SELECT 'RETUR: store_code retur <> toko transaksi (POS)', count(*) FROM read_csv('raw_data/returns.csv') r JOIN (SELECT trx_id, any_value(store_code) AS store_code FROM pos_dd GROUP BY 1) p ON p.trx_id = r.original_trx_id WHERE r.store_code <> p.store_code
  UNION ALL SELECT 'PROMO: dipakai di luar masa berlaku', count(*) FROM promo_use u JOIN read_csv('raw_data/promotions.csv') pr ON pr.promo_code = u.code WHERE u.d < pr.start_date OR u.d > pr.end_date
  UNION ALL SELECT 'PROMO: dipakai di luar channel_scope', count(*) FROM promo_use u JOIN read_csv('raw_data/promotions.csv') pr ON pr.promo_code = u.code WHERE pr.channel_scope <> 'ALL' AND pr.channel_scope <> u.channel
  UNION ALL SELECT 'PROMO: member_only dipakai non-member', count(*) FROM promo_use u JOIN read_csv('raw_data/promotions.csv') pr ON pr.promo_code = u.code WHERE pr.member_only AND u.who IS NULL
  UNION ALL SELECT 'PROMO: di luar category_scope (setelah normalisasi kategori, DQ-14)', count(*) FROM promo_use u JOIN read_csv('raw_data/promotions.csv') pr ON pr.promo_code = u.code
    JOIN (SELECT DISTINCT sku, fix_cat(category) AS category FROM prod) pd ON pd.sku = u.sku WHERE pr.category_scope <> 'ALL' AND NOT list_contains(string_split(pr.category_scope, ';'), pd.category)
  UNION ALL SELECT 'PROMO: kode promo terpakai tetapi diskon 0 (selain B2B-CORP)', count(*) FROM promo_use WHERE amt = 0
  UNION ALL SELECT 'RETUR: total qty retur per item > qty terjual (kumulatif)', count(*) FROM (
      SELECT sum(r.return_qty) AS rq, any_value(s.sold_qty) AS sq
      FROM (SELECT original_trx_id, upper(trim(sku)) AS sku, return_qty FROM read_csv('raw_data/returns.csv')) r
      JOIN sold s ON s.id = r.original_trx_id AND s.sku = r.sku GROUP BY r.original_trx_id, r.sku) WHERE rq > sq
  UNION ALL SELECT 'RETUR: refund <> qty retur x nilai bersih per unit (toleransi Rp 100, pembulatan)', count(*) FROM (
      SELECT r.return_id, r.refund_amount, r.return_qty * ((u.qty * u.price - u.disc)::DOUBLE / u.qty) AS expected
      FROM read_csv('raw_data/returns.csv') r
      JOIN (SELECT trx_id AS id, sku, line_no, qty, unit_price AS price, discount AS disc FROM pos_clean
            UNION ALL SELECT order_no, sku, line_no, qty, price, voucher FROM onl_dd WHERE order_status = 'COMPLETED') u
        ON u.id = r.original_trx_id AND u.sku = upper(trim(r.sku))
      QUALIFY count(*) OVER (PARTITION BY r.return_id) = 1) WHERE abs(refund_amount - expected) > 100
  UNION ALL SELECT 'PRODUK: penjualan valid sebelum launch_date',
    (SELECT count(*) FROM pos_clean d JOIN (SELECT DISTINCT sku, launch_date FROM prod) p USING (sku) WHERE d.ts::DATE < p.launch_date)
  + (SELECT count(*) FROM onl_dd d JOIN (SELECT DISTINCT sku, launch_date FROM prod) p USING (sku) WHERE d.order_status = 'COMPLETED' AND d.ts::DATE < p.launch_date)
  UNION ALL SELECT 'ID: trx_id / order_no / original_trx_id tidak ternormalisasi (huruf kecil/spasi)',
    (SELECT count(*) FROM pos WHERE trx_id <> upper(trim(trx_id))) + (SELECT count(*) FROM onl WHERE order_no <> upper(trim(order_no))) + (SELECT count(*) FROM read_csv('raw_data/returns.csv') WHERE original_trx_id <> upper(trim(original_trx_id)))
  UNION ALL SELECT 'POS: nilai gagal di-cast (line_no, ts, qty, harga, diskon)', count(*) FROM pos WHERE line_no IS NULL OR ts IS NULL OR qty IS NULL OR unit_price IS NULL OR discount IS NULL
  UNION ALL SELECT 'ONLINE: nilai gagal di-cast (line_no, ts, qty, voucher)', count(*) FROM onl WHERE line_no IS NULL OR ts IS NULL OR qty IS NULL OR voucher IS NULL
  UNION ALL SELECT 'RETUR: atas order CANCELLED', count(*) FROM read_csv('raw_data/returns.csv') r JOIN onl_dd o ON o.order_no = r.original_trx_id WHERE o.order_status = 'CANCELLED'
  UNION ALL SELECT 'RETUR: tanggal retur < tanggal transaksi asal (POS)', count(*) FROM read_csv('raw_data/returns.csv') r JOIN (SELECT trx_id, min(ts::DATE) d FROM pos_dd GROUP BY 1) p ON p.trx_id = r.original_trx_id WHERE r.return_date < p.d
  UNION ALL SELECT 'SYNC: store_code tidak di master', count(*) FROM read_csv('raw_data/pos_sync_log.csv') WHERE store_code NOT IN (SELECT store_code FROM read_csv('raw_data/stores.csv'))
  UNION ALL SELECT 'SYNC: FAILED padahal ada penjualan POS', count(*) FROM read_csv('raw_data/pos_sync_log.csv') l JOIN store_day s ON s.store_code = l.store_code AND s.d = l.business_date WHERE l.sync_status = 'FAILED'
  UNION ALL SELECT 'CUSTOMERS: transaksi sebelum join_date', count(*) FROM pos_dd p JOIN read_csv('raw_data/customers.csv') c ON c.customer_id = p.member_id WHERE p.ts::DATE < c.join_date
  UNION ALL SELECT 'CUSTOMERS: customer_id duplikat', count(*) - count(DISTINCT customer_id) FROM read_csv('raw_data/customers.csv')
) ORDER BY check_name;

-- ============================ C. KONTROL INDEPENDEN: rows_uploaded (sync log) vs baris POS bersih ============================
-- Baris bersih = pos_clean (didefinisikan di atas): dedup persis, tanpa void dan baris asli yang di-void, tanpa TRN-99.

SELECT (SELECT sum(rows_uploaded) FROM read_csv('raw_data/pos_sync_log.csv') WHERE sync_status = 'SUCCESS') AS rows_uploaded_sync_log,
       (SELECT count(*) FROM pos_clean) AS pos_clean_rows,
       (SELECT count(*) FROM pos_clean WHERE promo_code = 'B2B-CORP') AS of_which_b2b,
       (SELECT count(*) FILTER (WHERE ru = coalesce(n, 0)) FROM (
          SELECT l.rows_uploaded AS ru, c.n FROM read_csv('raw_data/pos_sync_log.csv') l
          LEFT JOIN (SELECT store_code, ts::DATE AS d, count(*) n FROM pos_clean GROUP BY 1, 2) c
            ON c.store_code = l.store_code AND c.d = l.business_date
          WHERE l.sync_status = 'SUCCESS')) AS store_days_cocok,
       (SELECT count(*) FROM read_csv('raw_data/pos_sync_log.csv') WHERE sync_status = 'SUCCESS') AS store_days_total;
