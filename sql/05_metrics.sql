-- 05_metrics: semantic layer KPI (schema metrics). SATU-SATUNYA tempat rumus KPI hidup; Metabase hanya SELECT dari sini.
-- Input : tabel dw.*     Output: metrics.ref_*, metrics.v_*, metrics.kpi_dictionary
--
-- ATURAN PENGGUNAAN (juga di reports/A7_kamus_metrik.md)
--  * Kolom *_idr, qty, lines, transactions adalah ukuran ADITIF: boleh di-SUM setelah filter apa pun.
--  * Kolom *_pct dan *_rate ada untuk kenyamanan pada grain view; JANGAN di-AVG. Hitung ulang dari pembilang/penyebut:
--      Gross Margin % = SUM(gross_margin_idr) / NULLIF(SUM(net_sales_idr), 0)
--  * transactions hanya aditif pada grain tanpa kategori/promo (satu struk memiliki satu channel, toko, tanggal, dan status member,
--    tetapi 39% struk memuat >1 kategori dan sebagian memuat >1 promo).
--  * Nilai NULL pada target/achievement = tidak ada target (mis. seluruh 2024), bukan nol.
--  * Net Sales tidak dikurangi retur; retur ada di metrics.v_return_rate_monthly. Net Sales termasuk B2B bulk (kolom is_b2b_bulk
--    / b2b_net_sales_idr tersedia agar dapat dikeluarkan).

-- ============================ Referensi ambang status ============================
-- Satu sumber untuk warna status di semua kartu Metabase (palet status tetap skill dataviz: good/warning/critical; selalu dipasangkan
-- dengan label teks Hijau/Kuning/Merah agar warna tidak menjadi satu-satunya pembawa makna). basis: 'ASUMSI' = usulan analis, perlu disetujui pemilik metrik.
CREATE OR REPLACE TABLE metrics.ref_status_threshold AS
SELECT * FROM (VALUES
  ('ACHIEVEMENT_PCT', 'Hijau',  100.0, 1, '#0ca30c', 'Net Sales >= target', 'ASUMSI'),
  ('ACHIEVEMENT_PCT', 'Kuning',  90.0, 2, '#fab219', '90% sampai <100% dari target', 'ASUMSI'),
  ('ACHIEVEMENT_PCT', 'Merah',   NULL, 3, '#d03b3b', '<90% dari target', 'ASUMSI'),
  ('MARGIN_GAP_PT',   'Hijau',     0.0, 1, '#0ca30c', 'Margin >= target', 'ASUMSI'),
  ('MARGIN_GAP_PT',   'Kuning',   -2.0, 2, '#fab219', 'Di bawah target hingga 2 poin persentase', 'ASUMSI'),
  ('MARGIN_GAP_PT',   'Merah',    NULL, 3, '#d03b3b', 'Lebih dari 2 poin persentase di bawah target', 'ASUMSI')
) v(kpi, status, min_value, sort_order, color_hex, meaning, basis);

-- ============================ Penjualan & margin ============================
-- Grain: bulan x channel x region x toko x kategori x flag B2B. Filter dashboard: periode, channel, region (= region_target_basis), kategori.
-- region_target_basis = peta region awal tahun (dasar penetapan target); region_asof = region saat transaksi; region_current = saat ini.
CREATE OR REPLACE VIEW metrics.v_sales_monthly AS
SELECT d.month_start, c.channel_name, f.region_target_basis, f.region_asof, f.region_current, s.store_code, p.category, f.is_b2b_bulk,
       count(*) AS lines, sum(f.qty)::BIGINT AS qty,
       sum(f.gross_sales)::BIGINT AS gross_sales_idr, sum(f.discount)::BIGINT AS discount_idr, sum(f.net_sales)::BIGINT AS net_sales_idr,
       sum(f.cogs)::BIGINT AS cogs_idr, sum(f.gross_margin)::BIGINT AS gross_margin_idr,
       sum(f.channel_fee)::DECIMAL(18, 2) AS channel_fee_idr,
       (sum(f.gross_margin) - sum(f.channel_fee))::DECIMAL(18, 2) AS contribution_margin_idr
FROM dw.fact_sales f
JOIN dw.dim_date d USING (date_key) JOIN dw.dim_channel c USING (channel_key)
JOIN dw.dim_store s USING (store_key) JOIN dw.dim_product p USING (product_key)
GROUP BY ALL;

-- Grain: bulan x channel x region x toko x member x B2B. Tanpa kategori/promo supaya transactions aditif -> AOV = SUM(net)/SUM(transactions).
CREATE OR REPLACE VIEW metrics.v_txn_monthly AS
SELECT d.month_start, c.channel_name, f.region_target_basis, s.store_code, f.is_member, f.is_b2b_bulk,
       count(DISTINCT (f.source_system, f.txn_id)) AS transactions, count(*) AS lines, sum(f.qty)::BIGINT AS qty,
       sum(f.net_sales)::BIGINT AS net_sales_idr
FROM dw.fact_sales f
JOIN dw.dim_date d USING (date_key) JOIN dw.dim_channel c USING (channel_key) JOIN dw.dim_store s USING (store_key)
GROUP BY ALL;

-- ============================ Achievement vs target ============================
-- Grain target: Store = bulan x region (peta region AWAL TAHUN = dasar penetapan target, bukan region saat transaksi); online = bulan x channel
-- nasional. Kategori tidak berlaku (target tidak per kategori).
CREATE OR REPLACE VIEW metrics.v_target_achievement AS
WITH actual AS (
  SELECT d.month_start, c.channel_name, CASE WHEN c.channel_name = 'Store' THEN f.region_target_basis ELSE 'Nasional' END AS region,
         sum(f.net_sales)::BIGINT AS net_sales_idr,
         coalesce(sum(f.net_sales) FILTER (WHERE f.is_b2b_bulk), 0)::BIGINT AS b2b_net_sales_idr
  FROM dw.fact_sales f JOIN dw.dim_date d USING (date_key) JOIN dw.dim_channel c USING (channel_key)
  GROUP BY ALL),
tgt AS (
  SELECT t.month_start, c.channel_name, t.region, t.target_scope, t.target_net_sales AS target_net_sales_idr
  FROM dw.fact_target t JOIN dw.dim_channel c USING (channel_key)),
j AS (
  SELECT coalesce(a.month_start, t.month_start) AS month_start, coalesce(a.channel_name, t.channel_name) AS channel_name,
         coalesce(a.region, t.region) AS region, t.target_scope,
         coalesce(a.net_sales_idr, 0) AS net_sales_idr, coalesce(a.b2b_net_sales_idr, 0) AS b2b_net_sales_idr,
         t.target_net_sales_idr
  FROM actual a FULL OUTER JOIN tgt t ON t.month_start = a.month_start AND t.channel_name = a.channel_name AND t.region = a.region)
SELECT month_start, channel_name, region, coalesce(target_scope, CASE WHEN channel_name = 'Store' THEN 'REGION' ELSE 'NATIONAL' END) AS target_scope,
       net_sales_idr, b2b_net_sales_idr, net_sales_idr - b2b_net_sales_idr AS net_sales_ex_b2b_idr, target_net_sales_idr,
       round(100.0 * net_sales_idr / NULLIF(target_net_sales_idr, 0), 2) AS achievement_pct,
       net_sales_idr - target_net_sales_idr AS gap_to_target_idr,
       CASE WHEN target_net_sales_idr IS NULL THEN 'Tanpa target'
            WHEN 100.0 * net_sales_idr / target_net_sales_idr >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Hijau') THEN 'Hijau'
            WHEN 100.0 * net_sales_idr / target_net_sales_idr >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Kuning') THEN 'Kuning'
            ELSE 'Merah' END AS status
FROM j;

-- Achievement per toko. Target hanya ada per region, jadi target toko = ALOKASI (ASUMSI, bukan target resmi):
-- target region bulan itu x pangsa toko dalam region. Pangsa = penjualan toko (tanpa B2B) pada bulan yang sama tahun lalu dibagi total
-- penjualan seluruh toko yang menjadi anggota region menurut peta awal tahun target (SCD2: BGR-01 di Jawa Barat sepanjang 2025, Jabodetabek 2026).
-- Bila region tidak punya penjualan tahun lalu (toko baru) -> dibagi rata (alloc_basis = MERATA).
CREATE OR REPLACE VIEW metrics.v_store_target_alloc AS
WITH store_month AS (
  SELECT d.month_start, s.store_code, sum(f.net_sales)::BIGINT AS net_sales_idr,
         coalesce(sum(f.net_sales) FILTER (WHERE NOT f.is_b2b_bulk), 0)::BIGINT AS net_sales_ex_b2b_idr
  FROM dw.fact_sales f JOIN dw.dim_date d USING (date_key) JOIN dw.dim_store s USING (store_key)
  WHERE f.channel_key = 1 GROUP BY ALL),
months AS (SELECT DISTINCT month_start FROM dw.fact_target WHERE target_scope = 'REGION'),
member AS (
  SELECT m.month_start, s.store_code, s.region
  FROM months m JOIN dw.dim_store s ON s.store_key > 0 AND s.open_date <= last_day(m.month_start)
   AND greatest(make_date(year(m.month_start), 1, 1), s.open_date) BETWEEN s.valid_from AND s.valid_to),
basis AS (
  SELECT mb.month_start, mb.store_code, mb.region, coalesce(py.net_sales_ex_b2b_idr, 0) AS basis_idr
  FROM member mb LEFT JOIN store_month py ON py.store_code = mb.store_code AND py.month_start = (mb.month_start - INTERVAL 1 YEAR)::DATE),
share AS (
  SELECT *, sum(basis_idr) OVER (PARTITION BY month_start, region) AS region_basis_idr, count(*) OVER (PARTITION BY month_start, region) AS n_members
  FROM basis)
SELECT sh.month_start, sh.store_code, sh.region,
       CASE WHEN sh.region_basis_idr > 0 THEN sh.basis_idr::DOUBLE / sh.region_basis_idr ELSE 1.0 / sh.n_members END AS alloc_share,
       CASE WHEN sh.region_basis_idr > 0 THEN 'PENJUALAN_TAHUN_LALU' ELSE 'MERATA' END AS alloc_basis,
       t.target_net_sales AS region_target_idr,
       round(t.target_net_sales * CASE WHEN sh.region_basis_idr > 0 THEN sh.basis_idr::DOUBLE / sh.region_basis_idr ELSE 1.0 / sh.n_members END, 2)::DECIMAL(18, 2) AS store_target_idr,
       coalesce(sm.net_sales_idr, 0) AS net_sales_idr, coalesce(sm.net_sales_ex_b2b_idr, 0) AS net_sales_ex_b2b_idr
FROM share sh
LEFT JOIN dw.fact_target t ON t.month_start = sh.month_start AND t.channel_key = 1 AND t.region = sh.region
LEFT JOIN store_month sm ON sm.store_code = sh.store_code AND sm.month_start = sh.month_start;

-- Margin vs target: GM% vs Target GM (FP&A, per channel); CM% vs target turunan = Target GM - tarif biaya channel berlaku (ASUMSI).
CREATE OR REPLACE VIEW metrics.v_margin_vs_target AS
WITH m AS (
  SELECT month_start, channel_name, sum(net_sales_idr) AS net_sales_idr, sum(gross_margin_idr) AS gross_margin_idr,
         sum(channel_fee_idr) AS channel_fee_idr, sum(contribution_margin_idr) AS contribution_margin_idr
  FROM metrics.v_sales_monthly GROUP BY ALL),
tg AS (SELECT t.month_start, c.channel_name, min(t.target_gm_pct) AS target_gm_pct
       FROM dw.fact_target t JOIN dw.dim_channel c USING (channel_key) GROUP BY ALL),
fee AS (SELECT c.channel_name, f.fee_pct, f.valid_from, f.valid_to FROM dw.ref_channel_fee f JOIN dw.dim_channel c USING (channel_key))
SELECT m.month_start, m.channel_name, m.net_sales_idr, m.gross_margin_idr, m.channel_fee_idr, m.contribution_margin_idr,
       round(100.0 * m.gross_margin_idr / NULLIF(m.net_sales_idr, 0), 2) AS gross_margin_pct,
       round(100.0 * m.contribution_margin_idr / NULLIF(m.net_sales_idr, 0), 2) AS contribution_margin_pct,
       tg.target_gm_pct, fee.fee_pct AS channel_fee_pct,
       tg.target_gm_pct - fee.fee_pct AS target_cm_pct,
       round(100.0 * m.gross_margin_idr / NULLIF(m.net_sales_idr, 0) - tg.target_gm_pct, 2) AS gm_gap_pt,
       round(100.0 * m.contribution_margin_idr / NULLIF(m.net_sales_idr, 0) - (tg.target_gm_pct - fee.fee_pct), 2) AS cm_gap_pt,
       CASE WHEN tg.target_gm_pct IS NULL THEN 'Tanpa target'
            WHEN 100.0 * m.gross_margin_idr / m.net_sales_idr - tg.target_gm_pct >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'MARGIN_GAP_PT' AND status = 'Hijau') THEN 'Hijau'
            WHEN 100.0 * m.gross_margin_idr / m.net_sales_idr - tg.target_gm_pct >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'MARGIN_GAP_PT' AND status = 'Kuning') THEN 'Kuning'
            ELSE 'Merah' END AS gm_status
FROM m
LEFT JOIN tg ON tg.month_start = m.month_start AND tg.channel_name = m.channel_name
LEFT JOIN fee ON fee.channel_name = m.channel_name AND last_day(m.month_start) BETWEEN fee.valid_from AND fee.valid_to;

-- ============================ Retur ============================
-- Basis: retur dikelompokkan menurut TANGGAL RETUR (pandangan arus kas); penjualan menurut tanggal jual. Rentang retur 2-20 hari,
-- jadi selisih basis hanya terasa di batas bulan. Atribut region/kategori/channel retur mengikuti penjualan asal.
-- Return Rate (Rp) = refund / Net Sales; Return Rate (unit) = qty retur / qty terjual. Net Sales sendiri TIDAK dikurangi retur.
CREATE OR REPLACE VIEW metrics.v_return_rate_monthly AS
WITH s AS (
  SELECT month_start, channel_name, region_target_basis, category, sum(net_sales_idr)::BIGINT AS net_sales_idr, sum(qty)::BIGINT AS qty_sold
  FROM metrics.v_sales_monthly GROUP BY ALL),
r AS (
  SELECT d.month_start, c.channel_name, r.region_target_basis, p.category, count(*) AS returns, sum(r.return_qty)::BIGINT AS return_qty,
         sum(r.refund_amount)::BIGINT AS refund_idr
  FROM dw.fact_returns r JOIN dw.dim_date d ON d.date_key = r.return_date_key
  JOIN dw.dim_channel c ON c.channel_key = r.channel_key JOIN dw.dim_product p USING (product_key)
  GROUP BY ALL)
SELECT month_start, channel_name, region_target_basis, category,
       coalesce(s.net_sales_idr, 0) AS net_sales_idr, coalesce(s.qty_sold, 0) AS qty_sold,
       coalesce(r.returns, 0) AS returns, coalesce(r.return_qty, 0) AS return_qty, coalesce(r.refund_idr, 0) AS refund_idr,
       round(100.0 * r.refund_idr / NULLIF(s.net_sales_idr, 0), 2) AS return_rate_pct,
       round(100.0 * r.return_qty / NULLIF(s.qty_sold, 0), 2) AS return_rate_qty_pct
FROM s FULL OUTER JOIN r USING (month_start, channel_name, region_target_basis, category);

-- Alasan retur (label sudah dibakukan, DQ-22). Pangsa alasan = SUM(refund_idr) alasan / SUM(refund_idr) total pada filter yang sama.
CREATE OR REPLACE VIEW metrics.v_return_reason_monthly AS
SELECT d.month_start, c.channel_name, r.region_target_basis, p.category, r.return_reason,
       count(*) AS returns, sum(r.return_qty)::BIGINT AS return_qty, sum(r.refund_amount)::BIGINT AS refund_idr
FROM dw.fact_returns r JOIN dw.dim_date d ON d.date_key = r.return_date_key
JOIN dw.dim_channel c ON c.channel_key = r.channel_key JOIN dw.dim_product p USING (product_key)
GROUP BY ALL;

-- ============================ Pembatalan & void ============================
-- Cancellation Rate (online) = Rp order CANCELLED / (Rp COMPLETED + Rp CANCELLED). Void Rate (POS) = Rp baris asli yang di-void /
-- (Rp penjualan valid + Rp yang di-void). Baris void itu sendiri (negatif) tidak dihitung agar tidak mengurangi dua kali.
CREATE OR REPLACE VIEW metrics.v_cancellation_void_monthly AS
WITH v AS (
  SELECT month_start, channel_name, region_target_basis, sum(net_sales_idr)::BIGINT AS valid_net_sales_idr FROM metrics.v_sales_monthly GROUP BY ALL),
x AS (
  SELECT d.month_start, c.channel_name, e.region_target_basis,
         coalesce(sum(e.net_sales) FILTER (WHERE e.exclude_reason = 'CANCELLED'), 0)::BIGINT AS cancelled_net_sales_idr,
         coalesce(sum(e.net_sales) FILTER (WHERE e.exclude_reason = 'VOIDED_ORIGINAL'), 0)::BIGINT AS voided_net_sales_idr
  FROM dw.fact_sales_excluded e JOIN dw.dim_date d USING (date_key) JOIN dw.dim_channel c USING (channel_key)
  GROUP BY ALL)
SELECT month_start, channel_name, region_target_basis, coalesce(v.valid_net_sales_idr, 0) AS valid_net_sales_idr,
       coalesce(x.cancelled_net_sales_idr, 0) AS cancelled_net_sales_idr, coalesce(x.voided_net_sales_idr, 0) AS voided_net_sales_idr,
       round(100.0 * x.cancelled_net_sales_idr / NULLIF(v.valid_net_sales_idr + x.cancelled_net_sales_idr, 0), 2) AS cancellation_rate_pct,
       round(100.0 * x.voided_net_sales_idr / NULLIF(v.valid_net_sales_idr + x.voided_net_sales_idr, 0), 2) AS void_rate_pct
FROM v FULL OUTER JOIN x USING (month_start, channel_name, region_target_basis);

-- ============================ Member: Active Members & Repeat Rate ============================
-- Active Members = member (customer_key > 0) dengan >= 1 struk pada periode. Repeat = member dengan >= 2 struk DISTINCT pada periode
-- yang sama. Repeat Rate = repeat_members / active_members. Struk B2B bulk dikecualikan (pembelian korporat bukan perilaku member).
-- Menghitung member DISTINCT tidak aditif lintas periode/channel, maka view ini dihitung per tipe periode; channel 'Semua channel'
-- = member unik lintas channel. Kartu Metabase memilih SATU period_type dan memfilter period_start/channel_name.
CREATE OR REPLACE VIEW metrics.v_members_period AS
WITH t AS (
  SELECT f.customer_key, c.channel_name, f.source_system, f.txn_id, f.sale_date
  FROM dw.fact_sales f JOIN dw.dim_channel c USING (channel_key)
  WHERE f.customer_key > 0 AND NOT f.is_b2b_bulk
  GROUP BY ALL),
p AS (
  SELECT pt.period_type,
         CASE pt.period_type WHEN 'Bulan' THEN date_trunc('month', t.sale_date)
                             WHEN 'Kuartal' THEN date_trunc('quarter', t.sale_date)
                             WHEN 'Semester' THEN make_date(year(t.sale_date), CASE WHEN month(t.sale_date) <= 6 THEN 1 ELSE 7 END, 1)
                             ELSE make_date(year(t.sale_date), 1, 1) END::DATE AS period_start,
         t.customer_key, t.channel_name, t.source_system, t.txn_id
  FROM t CROSS JOIN (VALUES ('Bulan'), ('Kuartal'), ('Semester'), ('Tahun')) pt(period_type)),
per_channel AS (SELECT period_type, period_start, channel_name, customer_key, count(*) AS n_txn FROM p GROUP BY ALL),
per_all AS (SELECT period_type, period_start, 'Semua channel' AS channel_name, customer_key, count(*) AS n_txn FROM p GROUP BY period_type, period_start, customer_key)
SELECT period_type, period_start,
       CASE period_type WHEN 'Bulan' THEN strftime(period_start, '%Y-%m')
                        WHEN 'Kuartal' THEN year(period_start)::VARCHAR || '-Q' || quarter(period_start)::VARCHAR
                        WHEN 'Semester' THEN year(period_start)::VARCHAR || '-H' || CASE WHEN month(period_start) <= 6 THEN '1' ELSE '2' END
                        ELSE year(period_start)::VARCHAR END AS period_label,
       channel_name, count(*) AS active_members, count(*) FILTER (WHERE n_txn >= 2) AS repeat_members, sum(n_txn)::BIGINT AS member_transactions,
       round(100.0 * count(*) FILTER (WHERE n_txn >= 2) / count(*), 2) AS repeat_rate_pct
FROM (SELECT * FROM per_channel UNION ALL SELECT * FROM per_all)
GROUP BY ALL;

-- ============================ Promo Lift & dampak margin ============================
-- Unit analisis: satu kode promo (73 kode; B2B-CORP dikecualikan). Scope penjualan = channel_scope, category_scope, dan (bila member_only)
-- hanya penjualan member; semua tanpa B2B bulk. Penjualan scope dihitung untuk SEMUA baris dalam scope (bukan hanya yang memakai kode),
-- karena promo juga menggeser pembelian non-kode.
--
-- BASELINE (utama): untuk tiap hari h dalam jendela promo, hari pembanding SIMETRIS h-28, h-21, h-14, h-7 dan h+7, h+14, h+21, h+28
--   (kelipatan 7 hari menjaga komposisi hari kerja identik; dua sisi meredam tren/musiman satu arah, mis. puncak Desember sebelum
--   Clearance Januari). Hari pembanding dibuang bila tercakup promo mana pun (termasuk promo ini sendiri) yang scope-nya beririsan
--   (channel dan kategori), atau di luar rentang data (2024-01-01 s.d. 2026-06-30). baseline_harian = total Net Sales hari bersih /
--   jumlah hari bersih.
-- PEMBANDING (YoY): hari h-364 dan h+364 (52 minggu), aturan kebersihan sama.
--   Promo Lift (Net Sales) = Net Sales jendela promo / (baseline_harian x jumlah hari) - 1
--   Promo Lift (unit)      = qty jendela promo / (baseline_qty_harian x jumlah hari) - 1
--   Dampak margin          = GM% jendela promo - GM% baseline (poin persentase); incremental_* = aktual - baseline_harian x jumlah hari.
--   Net Sales sudah NET dari diskon, sehingga incremental_gross_margin_idr sudah memperhitungkan biaya diskon.
-- Kualitas baseline: cakupan = persentase hari jendela yang punya >= 1 hari pembanding bersih. >= 75% BAIK, 50-<75% TERBATAS,
--   < 50% TIDAK_CUKUP (lift tidak dihitung/NULL). Keterbatasan: baseline tidak mengendalikan musiman (Ramadan, Harbolnas, gajian).
CREATE OR REPLACE VIEW metrics.v_promo_performance AS
WITH promo AS (
  SELECT promo_key, promo_code, promo_name, promo_type, channel_scope, category_scope, discount_pct, start_date, end_date, budget_idr, member_only,
         date_diff('day', start_date, end_date) + 1 AS n_days
  FROM dw.dim_promo WHERE promo_key > 0 AND promo_type <> 'B2B'),
daily AS (
  SELECT f.sale_date, c.channel_name, pr.category, f.is_member,
         sum(f.net_sales) AS net, sum(f.qty) AS qty, sum(f.gross_margin) AS gm, sum(f.channel_fee) AS fee
  FROM dw.fact_sales f JOIN dw.dim_channel c USING (channel_key) JOIN dw.dim_product pr USING (product_key)
  WHERE NOT f.is_b2b_bulk GROUP BY ALL),
scope_daily AS (
  SELECT p.promo_key, d.sale_date, sum(d.net) AS net, sum(d.qty) AS qty, sum(d.gm) AS gm, sum(d.fee) AS fee
  FROM promo p JOIN daily d
    ON (p.channel_scope = 'ALL' OR p.channel_scope = d.channel_name)
   AND (p.category_scope = 'ALL' OR list_contains(string_split(p.category_scope, ';'), d.category))
   AND (NOT p.member_only OR d.is_member)
  GROUP BY ALL),
overlap AS (   -- jendela semua promo yang scope-nya beririsan dengan promo a (termasuk a sendiri)
  SELECT a.promo_key, b.start_date, b.end_date
  FROM promo a JOIN promo b
    ON (a.channel_scope = 'ALL' OR b.channel_scope = 'ALL' OR a.channel_scope = b.channel_scope)
   AND (a.category_scope = 'ALL' OR b.category_scope = 'ALL'
        OR list_has_any(string_split(a.category_scope, ';'), string_split(b.category_scope, ';')))),
pairs AS (
  SELECT p.promo_key, dd.date AS window_day, o.kind, (dd.date + o.offset_days)::DATE AS base_day
  FROM promo p JOIN dw.dim_date dd ON dd.date BETWEEN p.start_date AND p.end_date
  CROSS JOIN (VALUES (-28, 'P'), (-21, 'P'), (-14, 'P'), (-7, 'P'), (7, 'P'), (14, 'P'), (21, 'P'), (28, 'P'), (-364, 'Y'), (364, 'Y')) o(offset_days, kind)),
clean AS (
  SELECT pr.* FROM pairs pr
  WHERE pr.base_day BETWEEN DATE '2024-01-01' AND DATE '2026-06-30'
    AND NOT EXISTS (SELECT 1 FROM overlap q WHERE q.promo_key = pr.promo_key AND pr.base_day BETWEEN q.start_date AND q.end_date)),
base AS (
  SELECT cl.promo_key, cl.kind, count(*) AS n_obs, count(DISTINCT cl.window_day) AS n_window_days_covered,
         sum(coalesce(sd.net, 0)) AS net, sum(coalesce(sd.qty, 0)) AS qty, sum(coalesce(sd.gm, 0)) AS gm, sum(coalesce(sd.fee, 0)) AS fee
  FROM clean cl LEFT JOIN scope_daily sd ON sd.promo_key = cl.promo_key AND sd.sale_date = cl.base_day
  GROUP BY ALL),
win AS (
  SELECT p.promo_key, sum(coalesce(sd.net, 0)) AS net, sum(coalesce(sd.qty, 0)) AS qty, sum(coalesce(sd.gm, 0)) AS gm, sum(coalesce(sd.fee, 0)) AS fee
  FROM promo p LEFT JOIN scope_daily sd ON sd.promo_key = p.promo_key AND sd.sale_date BETWEEN p.start_date AND p.end_date
  GROUP BY ALL),
coded AS (   -- baris yang benar-benar memakai kode promo ini
  SELECT f.promo_key, sum(f.net_sales) AS coded_net, sum(f.discount) AS discount, sum(f.qty) AS coded_qty
  FROM dw.fact_sales f WHERE f.promo_key > 0 AND NOT f.is_b2b_bulk GROUP BY ALL),
m AS (
  SELECT p.*, w.net AS win_net, w.qty AS win_qty, w.gm AS win_gm, w.fee AS win_fee,
         bp.n_obs AS p_obs, bp.net AS p_net, bp.qty AS p_qty, bp.gm AS p_gm, bp.fee AS p_fee,
         100.0 * coalesce(bp.n_window_days_covered, 0) / p.n_days AS p_coverage_pct,
         yo.n_obs AS y_obs, yo.net AS y_net, yo.qty AS y_qty, 100.0 * coalesce(yo.n_window_days_covered, 0) / p.n_days AS y_coverage_pct,
         coalesce(c.coded_net, 0) AS coded_net, coalesce(c.discount, 0) AS discount, coalesce(c.coded_qty, 0) AS coded_qty
  FROM promo p JOIN win w USING (promo_key)
  LEFT JOIN base bp ON bp.promo_key = p.promo_key AND bp.kind = 'P'
  LEFT JOIN base yo ON yo.promo_key = p.promo_key AND yo.kind = 'Y'
  LEFT JOIN coded c ON c.promo_key = p.promo_key),
q AS (
  SELECT *, CASE WHEN p_coverage_pct >= 75 THEN 'BAIK' WHEN p_coverage_pct >= 50 THEN 'TERBATAS' ELSE 'TIDAK_CUKUP' END AS baseline_quality,
         CASE WHEN p_coverage_pct >= 50 THEN p_net::DOUBLE / p_obs * n_days END AS exp_net,
         CASE WHEN p_coverage_pct >= 50 THEN p_qty::DOUBLE / p_obs * n_days END AS exp_qty,
         CASE WHEN p_coverage_pct >= 50 THEN p_gm::DOUBLE / p_obs * n_days END AS exp_gm,
         CASE WHEN p_coverage_pct >= 50 THEN (p_gm - p_fee)::DOUBLE / p_obs * n_days END AS exp_cm,
         CASE WHEN y_coverage_pct >= 50 THEN y_net::DOUBLE / y_obs * n_days END AS exp_net_yoy
  FROM m)
SELECT promo_key, promo_code, promo_name, promo_type, channel_scope, category_scope, member_only, discount_pct, start_date, end_date, n_days,
       win_net::BIGINT AS net_sales_idr, win_qty::BIGINT AS qty, win_gm::BIGINT AS gross_margin_idr, (win_gm - win_fee)::DECIMAL(18, 2) AS contribution_margin_idr,
       baseline_quality, round(p_coverage_pct, 1) AS baseline_coverage_pct,
       round(exp_net)::BIGINT AS baseline_net_sales_idr, round(exp_qty)::BIGINT AS baseline_qty, round(exp_gm)::BIGINT AS baseline_gross_margin_idr,
       round(100.0 * (win_net / NULLIF(exp_net, 0) - 1), 1) AS lift_net_pct,
       round(100.0 * (win_qty / NULLIF(exp_qty, 0) - 1), 1) AS lift_qty_pct,
       round(win_net - exp_net)::BIGINT AS incremental_net_sales_idr,
       round(100.0 * win_gm / NULLIF(win_net, 0), 2) AS gm_pct_promo,
       round(100.0 * exp_gm / NULLIF(exp_net, 0), 2) AS gm_pct_baseline,
       round(100.0 * win_gm / NULLIF(win_net, 0) - 100.0 * exp_gm / NULLIF(exp_net, 0), 2) AS gm_change_pt,
       round(win_gm - exp_gm)::BIGINT AS incremental_gross_margin_idr,
       round((win_gm - win_fee) - exp_cm)::BIGINT AS incremental_contribution_margin_idr,
       round(100.0 * (win_net / NULLIF(exp_net_yoy, 0) - 1), 1) AS lift_net_yoy_pct,
       coded_net::BIGINT AS promo_coded_net_sales_idr, discount::BIGINT AS discount_idr, budget_idr,
       round(100.0 * discount / NULLIF(budget_idr, 0), 1) AS budget_utilization_pct,
       round(100.0 * coded_net / NULLIF(win_net, 0), 1) AS promo_coded_share_pct
FROM q;

-- ============================ Kesegaran dan kelengkapan data ============================
-- Acuan waktu = data (bukan jam sistem) agar hasil idempoten: "data sampai" = tanggal bisnis terakhir di sync log POS.
CREATE OR REPLACE VIEW metrics.v_data_freshness AS
WITH s AS (SELECT max(business_date) AS last_sync_date, min(business_date) AS first_sync_date FROM dw.fact_pos_sync),
f AS (SELECT max(sale_date) AS last_sale_date, min(sale_date) AS first_sale_date FROM dw.fact_sales),
q AS (
  SELECT count(*) FILTER (WHERE sync_status = 'FAILED') AS failed_store_days, count(*) FILTER (WHERE sync_status = 'STORE_CLOSED') AS closed_store_days,
         count(*) FILTER (WHERE sync_status = 'SUCCESS') AS success_store_days, count(*) AS total_store_days,
         max(business_date) FILTER (WHERE sync_status = 'FAILED') AS last_failed_date,
         count(DISTINCT store_code) FILTER (WHERE sync_status = 'FAILED') AS stores_with_failed_sync,
         round(100.0 * count(*) FILTER (WHERE sync_status = 'SUCCESS') / count(*), 2) AS sync_success_pct,
         round(100.0 * count(*) FILTER (WHERE sync_status = 'SUCCESS' AND business_date > (SELECT max(business_date) FROM dw.fact_pos_sync) - 30)
               / NULLIF(count(*) FILTER (WHERE business_date > (SELECT max(business_date) FROM dw.fact_pos_sync) - 30), 0), 2) AS sync_success_last_30d_pct
  FROM dw.fact_pos_sync)
SELECT f.first_sale_date AS data_from_date, f.last_sale_date AS data_through_date, s.last_sync_date, q.sync_success_pct, q.sync_success_last_30d_pct,
       q.success_store_days, q.failed_store_days, q.closed_store_days, q.total_store_days, q.stores_with_failed_sync, q.last_failed_date,
       'Data sampai ' || strftime(s.last_sync_date, '%d %b %Y') || '; sync POS berhasil ' || q.sync_success_pct::VARCHAR || '% ('
         || q.failed_store_days::VARCHAR || ' toko-hari gagal, ' || q.closed_store_days::VARCHAR || ' toko-hari tutup)' AS freshness_label
FROM s, f, q;

-- Status sinkronisasi POS terakhir per toko
CREATE OR REPLACE VIEW metrics.v_pos_sync_status AS
SELECT st.store_code, st.store_name, max(sy.business_date) AS last_business_date,
       arg_max(sy.sync_status, sy.business_date) AS last_status, max(sy.synced_at) AS last_synced_at,
       count(*) FILTER (WHERE sy.sync_status = 'FAILED') AS failed_days, count(*) FILTER (WHERE sy.sync_status = 'STORE_CLOSED') AS closed_days,
       max(sy.business_date) FILTER (WHERE sy.sync_status = 'FAILED') AS last_failed_date
FROM dw.fact_pos_sync sy JOIN dw.dim_store st ON st.store_key = sy.store_key
GROUP BY st.store_code, st.store_name;

-- Penanda data tidak lengkap per toko-bulan: sync GAGAL (data hilang, bukan nol) atau toko TUTUP (kejadian bisnis, mis. renovasi).
CREATE OR REPLACE VIEW metrics.v_data_completeness AS
WITH d AS (
  SELECT dd.month_start, sy.store_code, count(*) AS days_logged,
         count(*) FILTER (WHERE sy.sync_status = 'SUCCESS') AS success_days,
         count(*) FILTER (WHERE sy.sync_status = 'FAILED') AS failed_days,
         count(*) FILTER (WHERE sy.sync_status = 'STORE_CLOSED') AS closed_days
  FROM dw.fact_pos_sync sy JOIN dw.dim_date dd USING (date_key) GROUP BY ALL),
ev AS (SELECT store_code, string_agg(event, '; ') AS event_name, min(start_date) AS ev_start, max(end_date) AS ev_end FROM dw.dim_store_event GROUP BY store_code)
SELECT d.month_start, d.store_code, d.days_logged, d.success_days, d.failed_days, d.closed_days,
       CASE WHEN d.failed_days > 0 THEN 'Tidak lengkap'
            WHEN d.closed_days > 0 THEN 'Toko tutup'
            ELSE 'Lengkap' END AS completeness_status,
       CASE WHEN d.failed_days > 0 THEN 'Sync POS gagal ' || d.failed_days::VARCHAR || ' hari: penjualan hari itu TIDAK tercatat (bukan nol)'
            WHEN d.closed_days > 0 THEN coalesce(ev.event_name, 'Toko tutup') || ' (' || d.closed_days::VARCHAR || ' hari tutup)'
            ELSE 'Seluruh hari tersinkronisasi' END AS note
FROM d LEFT JOIN ev ON ev.store_code = d.store_code AND d.month_start <= date_trunc('month', ev.ev_end) AND date_trunc('month', ev.ev_start) <= d.month_start;

-- ============================ Kamus metrik ============================
-- Satu sumber definisi KPI. Dokumen reports/A7_kamus_metrik.md dihasilkan dari tabel ini (scripts/export_reports.sh).
-- Tiap source_view harus ada (diuji di 06_tests.sql, T40).
CREATE OR REPLACE TABLE metrics.kpi_dictionary AS
SELECT * FROM (VALUES
 (1, 'Net Sales', 'Nilai penjualan bersih: harga x qty dikurangi diskon POS atau voucher online, tanpa pajak, sebelum dikurangi retur.',
  'SUM(net_sales_idr)', 'bulan x channel x region (dasar target, region_target_basis) x toko x kategori x flag B2B', 'metrics.v_sales_monthly',
  'Termasuk: POS valid dan order online COMPLETED, B2B bulk (dapat dikeluarkan lewat is_b2b_bulk). Dikecualikan: void dan baris asli yang di-void, order CANCELLED, duplikat, toko di luar master (TRN-99). Retur dan biaya channel TIDAK dikurangkan.',
  'Finance Controller', 'Target bulanan FP&A per channel/region (FY2025 Rp 44,181 miliar; H1 2026 Rp 23,820 miliar, semua channel). Tidak ada target 2024.'),
 (2, 'Achievement vs Target %', 'Net Sales aktual dibagi target Net Sales pada grain target (Store per region, online per channel nasional).',
  '100 * SUM(net_sales_idr) / NULLIF(SUM(target_net_sales_idr), 0)', 'bulan x channel x region (Store) atau nasional (online)', 'metrics.v_target_achievement',
  'Aktual dikelompokkan menurut peta region AWAL TAHUN (dasar penetapan target; BGR-01 di Jawa Barat sepanjang 2025, di Jabodetabek mulai 2026), bukan region saat transaksi: target FY2025 tidak disesuaikan saat BGR-01 pindah (Jul 2025), sehingga region saat transaksi menciptakan lonjakan palsu. B2B bulk termasuk (net_sales_ex_b2b_idr tersedia). Kategori tidak berlaku karena target tidak per kategori. NULL = tidak ada target. Per toko: v_store_target_alloc dengan target ALOKASI (asumsi).',
  'Direktur Komersial', 'Hijau >= 100%; Kuning 90 sampai <100%; Merah < 90% (ASUMSI analis, ref_status_threshold).'),
 (3, 'Gross Margin %', '(Net Sales - COGS) / Net Sales. COGS = qty x HPP yang berlaku pada tanggal transaksi.',
  '100 * SUM(gross_margin_idr) / NULLIF(SUM(net_sales_idr), 0)', 'bulan x channel x region x toko x kategori', 'metrics.v_sales_monthly',
  'Basis baris sama dengan Net Sales: tanpa void dan baris asli yang di-void, tanpa order CANCELLED, tanpa TRN-99; retur tidak dikurangkan. HPP as-of dari product_cost_history (bukan HPP terkini). Margin dihitung setelah diskon/voucher dan sebelum biaya channel.',
  'Finance Controller', 'Target GM FP&A per channel: Store 46%, Website 45%, Mobile App 43%, Marketplace 42%. Hijau: selisih >= 0 pt; Kuning: sampai -2 pt; Merah: lebih dari 2 pt di bawah target (ASUMSI).'),
 (4, 'Contribution Margin %', '(Gross Margin - biaya channel) / Net Sales. Biaya channel = Net Sales x tarif channel yang berlaku pada tanggal transaksi.',
  '100 * SUM(contribution_margin_idr) / NULLIF(SUM(net_sales_idr), 0)', 'bulan x channel x region x toko x kategori', 'metrics.v_sales_monthly / metrics.v_margin_vs_target',
  'Basis baris sama dengan Net Sales: tanpa void dan baris asli yang di-void, tanpa order CANCELLED, tanpa TRN-99; retur tidak dikurangkan. Tarif: Store 0,7%; Website dan Mobile App 2,2%; Marketplace 9,0% sampai 31 Mar 2025 lalu 11,5%. Biaya operasional toko dan biaya marketing di luar promo tidak tersedia di data.',
  'Finance Controller', 'Target turunan = Target GM - tarif channel berlaku (ASUMSI; FP&A tidak menetapkan target CM). Status memakai ambang selisih yang sama dengan Gross Margin.'),
 (5, 'Return Rate', 'Nilai refund retur dibagi Net Sales (Rp), dan qty retur dibagi qty terjual (unit).',
  '100 * SUM(refund_idr) / NULLIF(SUM(net_sales_idr), 0); 100 * SUM(return_qty) / NULLIF(SUM(qty_sold), 0)', 'bulan x channel x region x kategori', 'metrics.v_return_rate_monthly',
  'Retur dikelompokkan menurut tanggal retur; penjualan menurut tanggal jual. Atribut retur mengikuti penjualan asal. Retur yatim dikarantina. Alasan retur: v_return_reason_monthly.',
  'Head of Store Operations (Store); Head of E-Commerce (online)', 'Tidak ada target resmi. Pembanding: tahun lalu dan rata-rata channel; pemilik menetapkan ambang.'),
 (6, 'Average Order Value (AOV)', 'Net Sales per struk/order.',
  'SUM(net_sales_idr) / NULLIF(SUM(transactions), 0)', 'bulan x channel x region x toko x member x B2B', 'metrics.v_txn_monthly',
  'Struk = (sumber, trx_id/order_no) distinct. Struk void dan order CANCELLED tidak dihitung; retur tidak dikurangkan. Hanya pada view tanpa kategori/promo karena 39% struk memuat lebih dari satu kategori.',
  'Direktur Komersial', 'Tidak ada target resmi. Pembanding: bulan yang sama tahun lalu.'),
 (7, 'Jumlah Transaksi', 'Banyaknya struk POS atau order online valid.',
  'SUM(transactions)', 'bulan x channel x region x toko x member x B2B', 'metrics.v_txn_monthly',
  'Tidak termasuk void dan order CANCELLED. Aditif lintas channel, toko, region, dan bulan (satu struk hanya punya satu nilai tiap atribut itu). TIDAK aditif lintas kategori atau promo.',
  'Direktur Komersial', 'Tidak ada target resmi. Pembanding: tahun lalu.'),
 (8, 'Active Members', 'Member (customer_key > 0) yang memiliki minimal satu struk pada periode.',
  'active_members (pilih satu period_type, filter period_start dan channel_name)', 'tipe periode (Bulan, Kuartal, Semester, Tahun) x periode x channel (+ Semua channel)', 'metrics.v_members_period',
  'Struk B2B bulk dikecualikan. Member unik tidak aditif lintas periode atau channel, maka dihitung per tipe periode. Dua customer_id dengan email sama dihitung sebagai dua member (DQ-19).',
  'Head of E-Commerce (online); Head of Store Operations (Store)', 'Tidak ada target resmi. Pembanding: periode yang sama tahun lalu.'),
 (9, 'Repeat Rate', 'Persentase Active Members yang bertransaksi minimal dua kali (dua struk berbeda) pada periode yang sama.',
  '100 * repeat_members / NULLIF(active_members, 0)', 'tipe periode x periode x channel (+ Semua channel)', 'metrics.v_members_period',
  'Dihitung dalam periode dan channel yang dipilih; repeat di channel A dan satu kali di channel B tidak dihitung repeat pada channel masing-masing, tetapi dihitung repeat pada Semua channel. Nilai bergantung pada panjang periode: bandingkan hanya periode sama panjang (H1 2026 dengan H1 2025, bukan dengan FY2025).',
  'Head of E-Commerce (online); Head of Store Operations (Store)', 'Tidak ada target resmi. Pembanding: periode yang sama tahun lalu.'),
 (10, 'Promo Lift dan Dampak Margin', 'Kenaikan Net Sales (dan unit) pada jendela promo terhadap baseline, beserta perubahan margin dan margin tambahan dalam Rupiah.',
  'lift_net_pct = 100 * (net_sales_idr / baseline_net_sales_idr - 1); incremental_gross_margin_idr = gross_margin_idr - baseline_gross_margin_idr', 'satu kode promo (73)', 'metrics.v_promo_performance',
  'Scope = channel, kategori, dan (bila member-only) penjualan member; B2B bulk dikecualikan. Baseline = hari yang sama pada +/-1 sampai 4 minggu, tanpa hari yang tercakup promo beririsan; pembanding YoY +/-364 hari. Net Sales sudah dikurangi diskon. Tidak mengendalikan musiman. Ringkasan per jenis promo memakai rasio gabungan (jumlah pembilang / jumlah penyebut), bukan rata-rata lift per kode.',
  'Direktur Komersial (Marketing)', 'Tidak ada target resmi. Kriteria usulan: promo menguntungkan bila incremental_gross_margin_idr > 0; baseline_quality harus BAIK.'),
 (11, 'Cancellation Rate dan Void Rate', 'Cancellation Rate: Rp order CANCELLED dibagi (COMPLETED + CANCELLED) pada online. Void Rate: Rp baris asli yang di-void dibagi (valid + di-void) pada POS.',
  '100 * SUM(cancelled_net_sales_idr) / NULLIF(SUM(valid_net_sales_idr) + SUM(cancelled_net_sales_idr), 0)', 'bulan x channel x region', 'metrics.v_cancellation_void_monthly',
  'Baris void bernilai negatif tidak dihitung agar tidak mengurangi dua kali. Hanya channel yang relevan: pembatalan untuk online, void untuk Store.',
  'Head of E-Commerce (pembatalan); Head of Store Operations (void)', 'Tidak ada target resmi. Pembanding: tahun lalu.'),
 (12, 'Promo Budget Utilization', 'Diskon yang benar-benar diberikan lewat kode promo dibagi anggaran promo (budget_idr).',
  '100 * SUM(discount_idr) / NULLIF(SUM(budget_idr), 0)', 'satu kode promo', 'metrics.v_promo_performance',
  'Diskon = jumlah discount pada baris yang memakai kode promo (POS promo_code, online voucher). Anggaran dari promotions.csv; biaya non-diskon (iklan, dll.) tidak tersedia.',
  'Finance Controller; Direktur Komersial (Marketing)', 'Batas atas 100% dari anggaran promo.')
) v(kpi_id, kpi_name, business_definition, sql_formula, grain, source_view, inclusion_exclusion, owner, target_threshold);

-- Kinerja toko bulanan = achievement (target ALOKASI) + status kelengkapan data pada grain yang sama (bulan x toko), supaya satu filter
-- periode di dashboard berlaku untuk keduanya. Hasil join harus 1 baris per bulan x toko (diuji T52).
CREATE OR REPLACE VIEW metrics.v_store_performance_monthly AS
SELECT a.month_start, a.store_code, a.region, a.alloc_basis, a.alloc_share, a.region_target_idr, a.store_target_idr,
       a.net_sales_idr, a.net_sales_ex_b2b_idr,
       round(100.0 * a.net_sales_idr / NULLIF(a.store_target_idr, 0), 2) AS achievement_pct,
       c.days_logged, c.failed_days, c.closed_days, c.completeness_status, c.note AS completeness_note
FROM metrics.v_store_target_alloc a
LEFT JOIN metrics.v_data_completeness c ON c.month_start = a.month_start AND c.store_code = a.store_code;


-- ============================ Akses per region (Task 6) ============================
-- Store Manager hanya boleh melihat region-nya. Metabase OSS tidak punya row-level sandbox, jadi pembatasan dibuat di data:
-- satu schema acc_<region> per region berisi view yang sudah difilter (region = region_target_basis, konsisten dengan dashboard).
-- Group Metabase "Store Manager <region>" diberi izin data HANYA pada schema itu (lihat reports/C2_tata_kelola.md). Tanpa kolom PII.
-- Region 'Lainnya' (pesanan online di luar 6 region resmi) sengaja tidak punya schema: hanya Finance dan Direktur Komersial.
-- Kelengkapan diuji T54: tiap view hanya memuat regionnya dan gabungan semua region = view induk.
CREATE SCHEMA IF NOT EXISTS acc_jabodetabek;
CREATE OR REPLACE VIEW acc_jabodetabek.v_sales_monthly AS SELECT * FROM metrics.v_sales_monthly WHERE region_target_basis = 'Jabodetabek';
CREATE OR REPLACE VIEW acc_jabodetabek.v_store_performance_monthly AS SELECT * FROM metrics.v_store_performance_monthly WHERE region = 'Jabodetabek';
CREATE SCHEMA IF NOT EXISTS acc_jawa_barat;
CREATE OR REPLACE VIEW acc_jawa_barat.v_sales_monthly AS SELECT * FROM metrics.v_sales_monthly WHERE region_target_basis = 'Jawa Barat';
CREATE OR REPLACE VIEW acc_jawa_barat.v_store_performance_monthly AS SELECT * FROM metrics.v_store_performance_monthly WHERE region = 'Jawa Barat';
CREATE SCHEMA IF NOT EXISTS acc_jateng_diy;
CREATE OR REPLACE VIEW acc_jateng_diy.v_sales_monthly AS SELECT * FROM metrics.v_sales_monthly WHERE region_target_basis = 'Jateng & DIY';
CREATE OR REPLACE VIEW acc_jateng_diy.v_store_performance_monthly AS SELECT * FROM metrics.v_store_performance_monthly WHERE region = 'Jateng & DIY';
CREATE SCHEMA IF NOT EXISTS acc_jawa_timur;
CREATE OR REPLACE VIEW acc_jawa_timur.v_sales_monthly AS SELECT * FROM metrics.v_sales_monthly WHERE region_target_basis = 'Jawa Timur';
CREATE OR REPLACE VIEW acc_jawa_timur.v_store_performance_monthly AS SELECT * FROM metrics.v_store_performance_monthly WHERE region = 'Jawa Timur';
CREATE SCHEMA IF NOT EXISTS acc_bali_nusra;
CREATE OR REPLACE VIEW acc_bali_nusra.v_sales_monthly AS SELECT * FROM metrics.v_sales_monthly WHERE region_target_basis = 'Bali & Nusa Tenggara';
CREATE OR REPLACE VIEW acc_bali_nusra.v_store_performance_monthly AS SELECT * FROM metrics.v_store_performance_monthly WHERE region = 'Bali & Nusa Tenggara';
CREATE SCHEMA IF NOT EXISTS acc_sumatera;
CREATE OR REPLACE VIEW acc_sumatera.v_sales_monthly AS SELECT * FROM metrics.v_sales_monthly WHERE region_target_basis = 'Sumatera';
CREATE OR REPLACE VIEW acc_sumatera.v_store_performance_monthly AS SELECT * FROM metrics.v_store_performance_monthly WHERE region = 'Sumatera';
