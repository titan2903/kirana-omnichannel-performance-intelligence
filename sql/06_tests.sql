-- 06_tests: uji kualitas data pada model akhir.
-- Output: dq.test_results (produksi) dan dq.test_results_demo (uji yang SENGAJA gagal pada salinan yang disuntik cacat).
-- BLOCKING = bila diabaikan angka akan salah -> build berhenti (gerbang di 00_main.sql).
-- WARNING  = angka tetap valid, tetapi ada kondisi sumber yang harus dicatat; baris ditandai/dikarantina, bukan dibuang.
-- Status FAIL pada WARNING adalah temuan yang SUDAH DIKETAHUI dan ditangani (lihat kolom rationale), bukan cacat model.

-- Uji khusus tabel fakta penjualan; dibuat sebagai macro agar sama persis dijalankan pada fakta produksi dan pada salinan cacat.
CREATE OR REPLACE TEMP MACRO fact_tests(tbl) AS TABLE
SELECT 'T01' AS test_id, 'Grain fact_sales unik (source, txn_id, line_no, produk)' AS test_name, 'BLOCKING' AS severity,
       (SELECT count(*) FROM (SELECT 1 FROM query_table(tbl) GROUP BY source_system, txn_id, line_no, product_key HAVING count(*) > 1))::BIGINT AS rows_failed,
       'Duplikat grain menggandakan revenue dan transaksi' AS rationale
UNION ALL SELECT 'T02', 'Tidak ada FK yatim di fact_sales (tanggal, produk, toko, channel, pelanggan, promo)', 'BLOCKING',
       (SELECT count(*) FROM query_table(tbl) f WHERE
          NOT EXISTS (SELECT 1 FROM dw.dim_date d WHERE d.date_key = f.date_key)
          OR NOT EXISTS (SELECT 1 FROM dw.dim_product d WHERE d.product_key = f.product_key)
          OR NOT EXISTS (SELECT 1 FROM dw.dim_store d WHERE d.store_key = f.store_key)
          OR NOT EXISTS (SELECT 1 FROM dw.dim_channel d WHERE d.channel_key = f.channel_key)
          OR NOT EXISTS (SELECT 1 FROM dw.dim_customer d WHERE d.customer_key = f.customer_key)
          OR NOT EXISTS (SELECT 1 FROM dw.dim_promo d WHERE d.promo_key = f.promo_key))::BIGINT,
       'Baris yatim hilang dari semua agregat yang memakai dimensi tersebut'
UNION ALL SELECT 'T03', 'Channel, toko, dan region hanya bernilai resmi (POS=Store+toko; online=non-Store tanpa toko)', 'BLOCKING',
       (SELECT count(*) FROM query_table(tbl) f WHERE f.channel_key IS NULL OR f.channel_key NOT BETWEEN 1 AND 4
          OR (f.source_system = 'POS' AND (f.channel_key <> 1 OR f.store_key = -1))
          OR (f.source_system = 'ONLINE' AND (f.channel_key = 1 OR f.store_key <> -1))
          OR f.region_asof IS NULL
          OR f.region_asof NOT IN ('Jabodetabek', 'Jawa Barat', 'Jateng & DIY', 'Jawa Timur', 'Bali & Nusa Tenggara', 'Sumatera', 'Lainnya'))::BIGINT,
       'Nilai di luar domain memecah agregat per channel, toko, dan region (DQ-01, DQ-08)'
UNION ALL SELECT 'T04', 'Tiap baris punya tepat satu HPP as-of tanggal transaksi dan sama dengan nilai di fakta', 'BLOCKING',
       (SELECT count(*) FROM (
          SELECT f.sales_key FROM query_table(tbl) f
          LEFT JOIN dw.dim_product_cost c ON c.product_key = f.product_key AND f.sale_date BETWEEN c.valid_from AND c.valid_to
          GROUP BY f.sales_key, f.unit_cost
          HAVING count(c.unit_cost) <> 1 OR f.unit_cost IS NULL OR min(c.unit_cost) <> f.unit_cost))::BIGINT,
       'HPP kosong, ganda, atau salah periode membuat COGS dan gross margin salah (SCD HPP)'
UNION ALL SELECT 'T05', 'Tiap baris punya tarif biaya channel as-of tanggal transaksi', 'BLOCKING',
       (SELECT count(*) FROM query_table(tbl) f WHERE f.channel_fee_pct IS NULL OR f.channel_fee IS NULL)::BIGINT,
       'Tarif kosong membuat contribution margin menyimpang'
UNION ALL SELECT 'T20', 'Net sales >= 0 dan diskon <= gross sales', 'WARNING',
       (SELECT count(*) FROM query_table(tbl) f WHERE f.net_sales < 0 OR f.discount > f.gross_sales)::BIGINT,
       'Anomali nilai; angka tetap dapat dihitung tetapi perlu ditelaah';

CREATE OR REPLACE TABLE dq.test_results AS
SELECT test_id, test_name, severity, rows_failed, CASE WHEN rows_failed = 0 THEN 'PASS' ELSE 'FAIL' END AS status, rationale
FROM (
  SELECT * FROM fact_tests('dw.fact_sales')

  UNION ALL SELECT 'T10', 'Rekonsiliasi raw -> fakta: baris dan Rp selisih 0 untuk semua sumber', 'BLOCKING',
    (SELECT count(*) FROM dq.reconciliation WHERE diff_rows <> 0 OR coalesce(diff_rp, 0) <> 0)::BIGINT,
    'Selisih berarti ada data hilang atau terhitung ganda tanpa jejak'
  UNION ALL SELECT 'T11', 'Jembatan Net Sales dari nilai mentah ke fact_sales menutup (selisih 0)', 'BLOCKING',
    (SELECT count(*) FROM dq.net_sales_bridge WHERE step_no = 9 AND rp <> 0)::BIGINT,
    'Net Sales di laporan harus dapat ditelusuri ke nilai mentah'
  UNION ALL SELECT 'T12', 'Tidak ada kolom PII langsung di schema stg/dw/dq/metrics', 'BLOCKING',
    (SELECT count(*) FROM information_schema.columns
      WHERE table_schema IN ('stg', 'dw', 'dq', 'metrics')
        AND (lower(column_name) IN ('full_name', 'phone', 'email', 'birth_date', 'gender')
             OR (table_name LIKE '%customer%' AND lower(column_name) = 'city')))::BIGINT,
    'PII member tidak boleh sampai ke dashboard'
  UNION ALL SELECT 'T13', 'Kontrol sync log: SUM(rows_uploaded) = jumlah baris POS valid tanpa B2B', 'BLOCKING',
    abs((SELECT sum(rows_uploaded) FROM dw.fact_pos_sync WHERE sync_status = 'SUCCESS')
      - (SELECT count(*) FROM dw.fact_sales WHERE source_system = 'POS' AND NOT is_b2b_bulk))::BIGINT,
    'Total kontrol independen dari IT; membuktikan dedup dan void benar (B2B berada di luar sync POS)'
  UNION ALL SELECT 'T14', 'dim_store SCD2: satu region per toko per tanggal sejak open_date, tanpa tumpang tindih, region saat ini = master', 'BLOCKING',
    (SELECT count(*) FROM dw.dim_store a JOIN dw.dim_store b ON a.store_code = b.store_code AND a.store_key < b.store_key
        AND a.valid_from <= b.valid_to AND b.valid_from <= a.valid_to WHERE a.store_key > 0)
    + (SELECT count(*) FROM (SELECT store_code, min(valid_from) AS mn, max(valid_to) AS mx FROM dw.dim_store WHERE store_key > 0 GROUP BY store_code) d
        JOIN stg.store s USING (store_code) WHERE d.mn > s.open_date OR d.mx <> DATE '9999-12-31')
    + (SELECT count(*) FROM dw.dim_store d JOIN stg.store s USING (store_code) WHERE d.is_current AND d.region <> s.region)::BIGINT,
    'Region salah memindahkan penjualan ke target yang keliru (DQ-15)'
  UNION ALL SELECT 'T15', 'Kunci alami dimensi unik (sku, customer_id, promo_code, channel)', 'BLOCKING',
    ((SELECT count(*) - count(DISTINCT sku) FROM dw.dim_product) + (SELECT count(*) - count(DISTINCT customer_id) FROM dw.dim_customer)
     + (SELECT count(*) - count(DISTINCT promo_code) FROM dw.dim_promo) + (SELECT count(*) - count(DISTINCT channel_name) FROM dw.dim_channel))::BIGINT,
    'Kunci ganda di dimensi menggandakan fakta saat join (DQ-13)'
  UNION ALL SELECT 'T16', 'fact_target lengkap: tanpa region/channel/GM kosong, unik per (bulan, channel, region), total = Excel', 'BLOCKING',
    ((SELECT count(*) FROM dw.fact_target WHERE channel_key IS NULL OR region IS NULL OR target_gm_pct IS NULL OR target_net_sales IS NULL)
     + (SELECT count(*) FROM (SELECT 1 FROM dw.fact_target GROUP BY month_start, channel_key, region HAVING count(*) > 1))
     + (CASE WHEN (SELECT sum(target_net_sales) FROM dw.fact_target) = (SELECT raw_rp FROM dq.reconciliation WHERE source_name LIKE 'Target%') THEN 0 ELSE 1 END))::BIGINT,
    'Label region atau channel yang tak terpetakan membuat achievement kosong (DQ-16)'
  UNION ALL SELECT 'T17', 'Retur terhubung ke penjualan asal: tanggal jual, toko, dan channel ada dan konsisten', 'BLOCKING',
    (SELECT count(*) FROM dw.fact_returns WHERE sale_date IS NULL OR store_key IS NULL OR product_key IS NULL OR channel_key IS NULL OR channel_key <> sale_channel_key)::BIGINT,
    'Retur tanpa penjualan asal tidak dapat dihitung per kategori, channel, atau region'
  UNION ALL SELECT 'T18', 'Tidak ada baris sumber yang ditolak karena format/label tak dikenal (tipe, channel, status)', 'BLOCKING',
    ((SELECT count(*) FROM stg.pos_line WHERE disposition = 'REJECT_UNPARSEABLE')
     + (SELECT count(*) FROM stg.online_line WHERE disposition IN ('REJECT_UNPARSEABLE', 'REJECT_UNMAPPED_CHANNEL', 'REJECT_UNKNOWN_STATUS'))
     + (SELECT count(*) FROM stg.return_line WHERE disposition = 'REJECT_UNPARSEABLE'))::BIGINT,
    'Label atau format baru dari sumber harus ditangani eksplisit, bukan hilang diam-diam (DQ-08, DQ-09)'

  UNION ALL SELECT 'T19', 'return_id unik di fact_returns', 'BLOCKING',
    (SELECT count(*) FROM (SELECT 1 FROM dw.fact_returns GROUP BY return_id HAVING count(*) > 1))::BIGINT,
    'Retur ganda menggandakan refund; rekonsiliasi tidak mendeteksinya karena raw dan fakta sama-sama memuat duplikat'

  UNION ALL SELECT 'T21', 'Retur yatim (original_trx_id tidak ditemukan)', 'WARNING',
    (SELECT count(*) FROM stg.return_line WHERE disposition = 'REJECT_ORPHAN')::BIGINT,
    'DQ-21: dikarantina (stg.return_line, REJECT_ORPHAN), tidak masuk fact_returns'
  UNION ALL SELECT 'T22', 'Hari sync POS FAILED (data toko tidak terkirim)', 'WARNING',
    (SELECT count(*) FROM dw.fact_pos_sync WHERE sync_status = 'FAILED')::BIGINT,
    'DQ-23: tidak diimputasi; ditandai sebagai data tidak lengkap di dashboard (BDG-02, 3-9 Nov 2025)'
  UNION ALL SELECT 'T23', 'Tabrakan nomor struk POS (trx_id + line_no sama, item berbeda)', 'WARNING',
    (SELECT count(*) FROM (SELECT txn_id, line_no FROM dw.fact_sales WHERE key_collision GROUP BY txn_id, line_no))::BIGINT,
    'DQ-05: kedua baris dipertahankan, flag key_collision; grain memakai produk'
  UNION ALL SELECT 'T24', 'Void tanpa baris asli di toko master', 'WARNING',
    (SELECT count(*) FROM stg.pos_line WHERE disposition = 'REJECT_VOID_WITHOUT_ORIGINAL')::BIGINT,
    'DQ-06c: dikarantina; void tunggal yang ditemukan di profiling berada di TRN-99 (DQ-02)'
  UNION ALL SELECT 'T25', 'Provinsi order online tidak dapat ditentukan (kosong dan kota tidak dikenal)', 'WARNING',
    (SELECT count(*) FROM stg.online_line WHERE disposition = 'FACT' AND province_source = 'MISSING')::BIGINT,
    'DQ-12: provinsi kosong disimpulkan dari kota (province_source = INFERRED_FROM_CITY); sisanya masuk Lainnya'
  UNION ALL SELECT 'T26', 'Pemakaian promo di luar masa berlaku, channel_scope, member_only, atau category_scope', 'WARNING',
    (SELECT count(*) FROM dw.fact_sales f JOIN dw.dim_promo p USING (promo_key) JOIN dw.dim_product pr USING (product_key)
      JOIN dw.dim_channel c USING (channel_key)
      WHERE f.promo_key > 0 AND p.promo_type <> 'B2B'
        AND (f.sale_date < p.start_date OR f.sale_date > p.end_date
             OR (p.channel_scope <> 'ALL' AND p.channel_scope <> c.channel_name)
             OR (p.member_only AND NOT f.is_member)
             OR (p.category_scope <> 'ALL' AND NOT list_contains(string_split(p.category_scope, ';'), pr.category))))::BIGINT,
    'Promo yang dipakai di luar ketentuan menyesatkan analisis efektivitas promo (DQ-14 menormalkan kategori)'
  UNION ALL SELECT 'T27', 'Penjualan valid sebelum launch_date produk', 'WARNING',
    (SELECT count(*) FROM dw.fact_sales f JOIN dw.dim_product p USING (product_key) WHERE f.sale_date < p.launch_date)::BIGINT,
    'DQ-17: semua penjualan pra-launch sudah berupa baris yang di-void'
  UNION ALL SELECT 'T28', 'Target ada untuk semua (bulan, channel/region) 2025-01 s.d. 2026-06 (18 bulan x 9 baris)', 'WARNING',
    abs(162 - (SELECT count(*) FROM dw.fact_target WHERE month_start BETWEEN DATE '2025-01-01' AND DATE '2026-06-01'))::BIGINT,
    'Target kosong membuat Achievement NULL; tahun 2024 memang tidak memiliki target'
  UNION ALL SELECT 'T30', 'Retur atas penjualan yang sudah dikeluarkan (void/batal)', 'WARNING',
    (SELECT count(*) FROM stg.return_line WHERE disposition = 'REJECT_ORIGINAL_EXCLUDED')::BIGINT,
    'Dikarantina (REJECT_ORIGINAL_EXCLUDED); retur atas penjualan yang tidak pernah terjadi tidak boleh mengurangi Net Sales'
  UNION ALL SELECT 'T31', 'Refund = qty retur x nilai bersih per unit penjualan asal (toleransi Rp 100)', 'WARNING',
    (SELECT count(*) FROM (
        SELECT r.return_key, r.refund_amount, r.return_qty * (sum(f.net_sales)::DOUBLE / sum(f.qty)) AS expected
        FROM dw.fact_returns r JOIN dw.fact_sales f ON f.txn_id = r.original_txn_id AND f.product_key = r.product_key
        GROUP BY r.return_key, r.refund_amount, r.return_qty) WHERE abs(refund_amount - expected) > 100)::BIGINT,
    'Refund menyimpang dari nilai yang dibayar pelanggan; Return Rate (Rp) menjadi bias'
  UNION ALL SELECT 'T32', 'promo_type dikenali (tidak jatuh ke Lainnya)', 'WARNING',
    (SELECT count(*) FROM dw.dim_promo WHERE promo_type = 'Lainnya')::BIGINT,
    'Jenis promo baru akan membentuk kelompok kosong/Lainnya di analisis promo'
  UNION ALL SELECT 'T29', 'Transaksi B2B bulk yang dipertahankan di fact_sales', 'WARNING',
    (SELECT count(*) FROM dw.fact_sales WHERE is_b2b_bulk)::BIGINT,
    'DQ-07: dipertahankan dan ditandai is_b2b_bulk; ditampilkan dengan dan tanpa B2B pada kinerja toko'

  -- ---------- Semantic layer (schema metrics): tiap view harus menutup ke fakta ----------
  UNION ALL SELECT 'T40', 'Kamus metrik memuat >= 8 KPI dan semua view yang dirujuk ada', 'BLOCKING',
    ((SELECT CASE WHEN count(*) >= 8 THEN 0 ELSE 1 END FROM metrics.kpi_dictionary)
     + (SELECT count(*) FROM (SELECT DISTINCT trim(unnest(string_split(source_view, ' / '))) AS v FROM metrics.kpi_dictionary) k
         WHERE NOT EXISTS (SELECT 1 FROM information_schema.tables t WHERE t.table_schema || '.' || t.table_name = k.v)))::BIGINT,
    'KPI tanpa view atau rumus yang hidup di luar semantic layer membuat angka dashboard tidak dapat ditelusuri'
  UNION ALL SELECT 'T41', 'v_sales_monthly = fact_sales (Net Sales, gross margin, COGS, qty, diskon, fee)', 'BLOCKING',
    (SELECT count(*) FROM (SELECT sum(net_sales_idr) n, sum(gross_margin_idr) g, sum(cogs_idr) c, sum(qty) q, sum(discount_idr) d, sum(channel_fee_idr) fe FROM metrics.v_sales_monthly) v,
        (SELECT sum(net_sales) n, sum(gross_margin) g, sum(cogs) c, sum(qty) q, sum(discount) d, sum(channel_fee) fe FROM dw.fact_sales) f
      WHERE v.n <> f.n OR v.g <> f.g OR v.c <> f.c OR v.q <> f.q OR v.d <> f.d OR abs(v.fe - f.fe) > 0.5)::BIGINT,
    'Selisih berarti baris hilang/ganda saat agregasi ke grain view'
  UNION ALL SELECT 'T42', 'v_txn_monthly = fact_sales (jumlah struk distinct dan Net Sales)', 'BLOCKING',
    (SELECT count(*) FROM (SELECT sum(transactions) t, sum(net_sales_idr) n FROM metrics.v_txn_monthly) v,
        (SELECT count(DISTINCT (source_system, txn_id)) t, sum(net_sales) n FROM dw.fact_sales) f WHERE v.t <> f.t OR v.n <> f.n)::BIGINT,
    'transactions hanya valid bila satu struk jatuh di tepat satu baris grain (channel, toko, tanggal, member)'
  UNION ALL SELECT 'T43', 'v_target_achievement: aktual dan target menutup ke fakta (tidak ada target hilang atau ganda)', 'BLOCKING',
    (SELECT count(*) FROM (SELECT sum(net_sales_idr) n, sum(target_net_sales_idr) t FROM metrics.v_target_achievement) v,
        (SELECT (SELECT sum(net_sales) FROM dw.fact_sales) n, (SELECT sum(target_net_sales) FROM dw.fact_target) t) f WHERE v.n <> f.n OR v.t <> f.t)::BIGINT,
    'Join target yang gagal (label region/channel) membuat Achievement kosong atau terhitung ganda'
  UNION ALL SELECT 'T44', 'v_store_target_alloc: pangsa toko berjumlah 1 dan target toko berjumlah target region', 'BLOCKING',
    (SELECT count(*) FROM (SELECT month_start, region, sum(alloc_share) s, sum(store_target_idr) t, any_value(region_target_idr) r
                           FROM metrics.v_store_target_alloc GROUP BY 1, 2) WHERE abs(s - 1) > 1e-9 OR r IS NULL OR abs(t - r) > 0.05)::BIGINT,
    'Alokasi yang tidak menutup membuat achievement toko tidak konsisten dengan achievement region'
  UNION ALL SELECT 'T45', 'v_return_rate_monthly dan v_return_reason_monthly = fact_returns (refund, jumlah retur)', 'BLOCKING',
    (SELECT count(*) FROM (SELECT sum(refund_idr) r, sum(returns) n FROM metrics.v_return_rate_monthly) a,
        (SELECT sum(refund_idr) r, sum(returns) n FROM metrics.v_return_reason_monthly) b,
        (SELECT sum(refund_amount) r, count(*) n FROM dw.fact_returns) f
      WHERE a.r <> f.r OR a.n <> f.n OR b.r <> f.r OR b.n <> f.n)::BIGINT,
    'Retur yang hilang saat join penjualan membuat Return Rate terlalu rendah'
  UNION ALL SELECT 'T46', 'v_members_period: Active Members tahunan (Semua channel) = member unik langsung dari fakta', 'BLOCKING',
    (SELECT count(*) FROM metrics.v_members_period m
      WHERE m.period_type = 'Tahun' AND m.channel_name = 'Semua channel'
        AND m.active_members <> (SELECT count(DISTINCT f.customer_key) FROM dw.fact_sales f
                                  WHERE f.customer_key > 0 AND NOT f.is_b2b_bulk AND year(f.sale_date) = year(m.period_start)))::BIGINT,
    'Member unik tidak boleh dijumlahkan antar bulan; view harus menghitung distinct pada tiap tipe periode'
  UNION ALL SELECT 'T47', 'v_margin_vs_target: Net Sales dan gross margin = fakta; target GM ada untuk semua channel 2025-01 s.d. 2026-06', 'BLOCKING',
    ((SELECT count(*) FROM (SELECT sum(net_sales_idr) n, sum(gross_margin_idr) g FROM metrics.v_margin_vs_target) v,
          (SELECT sum(net_sales) n, sum(gross_margin) g FROM dw.fact_sales) f WHERE v.n <> f.n OR v.g <> f.g)
     + (SELECT count(*) FROM metrics.v_margin_vs_target WHERE month_start BETWEEN DATE '2025-01-01' AND DATE '2026-06-01' AND (target_gm_pct IS NULL OR channel_fee_pct IS NULL)))::BIGINT,
    'Status margin yang salah menyesatkan keputusan promo; target/tarif kosong menandakan join gagal'
  UNION ALL SELECT 'T48', 'v_cancellation_void_monthly = fact (valid, dibatalkan, void)', 'BLOCKING',
    (SELECT count(*) FROM (SELECT sum(valid_net_sales_idr) v, sum(cancelled_net_sales_idr) c, sum(voided_net_sales_idr) o FROM metrics.v_cancellation_void_monthly) a,
        (SELECT (SELECT sum(net_sales) FROM dw.fact_sales) v,
                (SELECT sum(net_sales) FROM dw.fact_sales_excluded WHERE exclude_reason = 'CANCELLED') c,
                (SELECT sum(net_sales) FROM dw.fact_sales_excluded WHERE exclude_reason = 'VOIDED_ORIGINAL') o) f
      WHERE a.v <> f.v OR a.c <> f.c OR a.o <> f.o)::BIGINT,
    'Rate pembatalan/void harus berasal dari baris yang sama dengan rekonsiliasi'
  UNION ALL SELECT 'T49', 'v_promo_performance: 73 promo dan total diskon = diskon baris berkode promo di fakta', 'BLOCKING',
    ((SELECT CASE WHEN count(*) = 73 THEN 0 ELSE 1 END FROM metrics.v_promo_performance)
     + (SELECT count(*) FROM (SELECT sum(discount_idr) d FROM metrics.v_promo_performance) v,
          (SELECT sum(discount) d FROM dw.fact_sales WHERE promo_key > 0 AND NOT is_b2b_bulk) f WHERE v.d <> f.d))::BIGINT,
    'Promo hilang atau diskon tidak menutup membuat analisis efektivitas promo tidak dapat dipercaya'
  UNION ALL SELECT 'T50', 'Baseline Promo Lift memadai (tidak ada promo dengan baseline TIDAK_CUKUP)', 'WARNING',
    (SELECT count(*) FROM metrics.v_promo_performance WHERE baseline_quality = 'TIDAK_CUKUP')::BIGINT,
    'Promo tanpa baseline bersih tidak memiliki lift (NULL); tidak boleh dibandingkan dengan promo lain'
  UNION ALL SELECT 'T51', 'v_data_completeness konsisten dengan sync log (hari FAILED dan STORE_CLOSED)', 'BLOCKING',
    (SELECT count(*) FROM (SELECT sum(failed_days) f, sum(closed_days) c FROM metrics.v_data_completeness) v,
        (SELECT count(*) FILTER (WHERE sync_status = 'FAILED') f, count(*) FILTER (WHERE sync_status = 'STORE_CLOSED') c FROM dw.fact_pos_sync) s
      WHERE v.f <> s.f OR v.c <> s.c)::BIGINT,
    'Penanda data tidak lengkap di dashboard harus sama dengan sumber sync POS'
) ORDER BY test_id;

-- ============================ Uji yang SENGAJA gagal ============================
-- Salinan fact_sales disuntik tiga cacat; macro yang sama dijalankan pada salinan itu. Model produksi tidak berubah.
CREATE OR REPLACE TEMP TABLE fact_sales_bad AS
SELECT * FROM dw.fact_sales
UNION ALL (SELECT * REPLACE ((SELECT max(sales_key) + 1 FROM dw.fact_sales) AS sales_key)
           FROM dw.fact_sales ORDER BY sales_key LIMIT 1)                                                   -- (1) duplikat grain persis
UNION ALL (SELECT * REPLACE ((SELECT max(sales_key) + 2 FROM dw.fact_sales) AS sales_key, 'DEMO-FK-' || txn_id AS txn_id, 999999 AS product_key)
           FROM dw.fact_sales ORDER BY sales_key LIMIT 1 OFFSET 1)                                          -- (2) FK produk yatim
UNION ALL (SELECT * REPLACE ((SELECT max(sales_key) + 3 FROM dw.fact_sales) AS sales_key, 'DEMO-NEG-' || txn_id AS txn_id, -5000 AS net_sales)
           FROM dw.fact_sales ORDER BY sales_key LIMIT 1 OFFSET 2);                                         -- (3) net sales negatif

CREATE OR REPLACE TABLE dq.test_results_demo AS
SELECT t.test_id, t.test_name, t.severity, t.rows_failed, CASE WHEN t.rows_failed = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
       CASE t.test_id WHEN 'T01' THEN '1 baris duplikat persis disuntik' WHEN 'T02' THEN '1 baris dengan product_key 999999 disuntik'
                      WHEN 'T04' THEN 'akibat samping baris FK yatim: tidak ada HPP untuk produk 999999'
                      WHEN 'T20' THEN '1 baris dengan net_sales -5000 disuntik' ELSE '' END AS injected_defect
FROM fact_tests('fact_sales_bad') t ORDER BY t.test_id;
