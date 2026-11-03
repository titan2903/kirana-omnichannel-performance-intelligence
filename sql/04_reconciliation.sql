-- 04_reconciliation: rekonsiliasi baris dan Rupiah dari raw ke tabel bersih.
-- Input : TEMP view raw_* (sisi mentah dihitung langsung dari file), stg.*, dw.*     Output: dq.reconciliation, dq.net_sales_bridge
-- Rumus tiap baris:  raw = salinan duplikat + ditolak (karantina) + dikeluarkan (bukan penjualan) + fakta  ->  selisih harus 0.
-- Sisi mentah dihitung dari raw_* (bukan dari stg) supaya rekonsiliasi benar-benar independen dari logika pembersihan.
-- Basis Rp transaksi = nilai bersih baris = qty x harga - diskon/voucher (belum dikurangi retur, tanpa pajak).

CREATE OR REPLACE TABLE dq.reconciliation AS
WITH r AS (
  -- POS
  SELECT 'POS (sales_pos_transactions)' AS source_name, 1 AS ord,
         (SELECT count(*) FROM raw_pos) AS raw_rows,
         (SELECT sum(try_cast(qty AS BIGINT) * try_cast(unit_price AS BIGINT) - try_cast(discount_amount AS BIGINT)) FROM raw_pos) AS raw_rp,
         (SELECT sum(n_copies - 1) FROM stg.pos_line) AS dup_dropped_rows,
         (SELECT sum((n_copies - 1) * net) FROM stg.pos_line) AS dup_dropped_rp,
         (SELECT count(*) FROM stg.pos_line WHERE disposition LIKE 'REJECT%') AS rejected_rows,
         (SELECT coalesce(sum(net), 0) FROM stg.pos_line WHERE disposition LIKE 'REJECT%') AS rejected_rp,
         (SELECT count(*) FROM stg.pos_line WHERE disposition LIKE 'EXCLUDE%') AS excluded_rows,
         (SELECT coalesce(sum(net), 0) FROM stg.pos_line WHERE disposition LIKE 'EXCLUDE%') AS excluded_rp,
         (SELECT count(*) FROM dw.fact_sales WHERE source_system = 'POS') AS fact_rows,
         (SELECT sum(net_sales) FROM dw.fact_sales WHERE source_system = 'POS') AS fact_rp,
         'ditolak = TRN-99 (DQ-02); dikeluarkan = void + baris asli yang di-void (DQ-06)' AS note
  UNION ALL
  -- Online
  SELECT 'Online (sales_online_orders)', 2,
         (SELECT count(*) FROM raw_online),
         (SELECT sum(try_cast(qty AS BIGINT) * parse_price(item_price) - try_cast(voucher_amount AS BIGINT)) FROM raw_online),
         (SELECT sum(n_copies - 1) FROM stg.online_line),
         (SELECT sum((n_copies - 1) * net) FROM stg.online_line),
         (SELECT count(*) FROM stg.online_line WHERE disposition LIKE 'REJECT%'),
         (SELECT coalesce(sum(net), 0) FROM stg.online_line WHERE disposition LIKE 'REJECT%'),
         (SELECT count(*) FROM stg.online_line WHERE disposition LIKE 'EXCLUDE%'),
         (SELECT coalesce(sum(net), 0) FROM stg.online_line WHERE disposition LIKE 'EXCLUDE%'),
         (SELECT count(*) FROM dw.fact_sales WHERE source_system = 'ONLINE'),
         (SELECT sum(net_sales) FROM dw.fact_sales WHERE source_system = 'ONLINE'),
         'dikeluarkan = order CANCELLED (DQ-11)'
  UNION ALL
  -- Retur (Rp = refund)
  SELECT 'Retur (returns)', 3,
         (SELECT count(*) FROM raw_returns), (SELECT sum(try_cast(refund_amount AS BIGINT)) FROM raw_returns),
         0, 0,
         (SELECT count(*) FROM stg.return_line WHERE disposition LIKE 'REJECT%'),
         (SELECT coalesce(sum(refund_amount), 0) FROM stg.return_line WHERE disposition LIKE 'REJECT%'),
         0, 0,
         (SELECT count(*) FROM dw.fact_returns), (SELECT sum(refund_amount) FROM dw.fact_returns),
         'ditolak = retur yatim (DQ-21)'
  UNION ALL
  -- Target (satu sel bulan = satu baris)
  SELECT 'Target (sales_targets xlsx, sel bulan)', 4,
         (SELECT count(*) FROM (UNPIVOT raw_target_2025 ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t))
           + (SELECT count(*) FROM (UNPIVOT raw_target_2026 ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t)),
         (SELECT sum(t) FROM (UNPIVOT raw_target_2025 ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t))
           + (SELECT sum(t) FROM (UNPIVOT raw_target_2026 ON COLUMNS(* EXCLUDE (Channel, Region)) INTO NAME m VALUE t)),
         0, 0, 0, 0, 0, 0,
         (SELECT count(*) FROM dw.fact_target), (SELECT sum(target_net_sales) FROM dw.fact_target),
         'unpivot 9 baris x 12 bulan (2025) + 9 baris x 6 bulan (H1 2026)'
  UNION ALL
  SELECT 'Sync log POS (pos_sync_log)', 5, (SELECT count(*) FROM raw_sync), NULL, 0, NULL, 0, NULL, 0, NULL,
         (SELECT count(*) FROM dw.fact_pos_sync), NULL, 'Rp tidak berlaku'
  -- Dimensi (jumlah kunci alami)
  UNION ALL
  SELECT 'Dim produk (products)', 6, (SELECT count(*) FROM raw_products), NULL, 0, NULL,
         (SELECT count(*) FROM stg.product_rejected), NULL, 0, NULL,
         (SELECT count(*) FROM dw.dim_product), NULL, 'ditolak = varian SKU "(old)" (DQ-13)'
  UNION ALL
  SELECT 'Dim pelanggan (customers)', 7, (SELECT count(*) FROM raw_customers), NULL, 0, NULL, 0, NULL, 0, NULL,
         (SELECT count(*) FROM dw.dim_customer WHERE customer_key > 0), NULL, 'PII dibuang di staging; baris "Non-member" (-1) tidak dihitung'
  UNION ALL
  SELECT 'Dim toko (stores)', 8, (SELECT count(*) FROM raw_stores), NULL, 0, NULL, 0, NULL, 0, NULL,
         (SELECT count(DISTINCT store_code) FROM dw.dim_store WHERE store_key > 0), NULL, 'dim_store SCD2 punya >1 baris per toko yang pindah region; dihitung per store_code'
  UNION ALL
  SELECT 'Dim promo (promotions)', 9, (SELECT count(*) FROM raw_promos), NULL, 0, NULL, 0, NULL, 0, NULL,
         (SELECT count(*) FROM dw.dim_promo WHERE promo_key > 0 AND promo_code <> 'B2B-CORP'), NULL, 'B2B-CORP dan NONE ditambahkan manual, tidak dihitung')
SELECT source_name, raw_rows, dup_dropped_rows, rejected_rows, excluded_rows, fact_rows,
       raw_rows - dup_dropped_rows - rejected_rows - excluded_rows - fact_rows AS diff_rows,
       -- uang tidak boleh DOUBLE: target Excel terbaca DOUBLE sehingga kolom gabungan ikut DOUBLE; DECIMAL(18,2) menjaga nilai pecahan bila ada
       raw_rp::DECIMAL(18, 2) AS raw_rp, dup_dropped_rp, rejected_rp, excluded_rp, fact_rp,
       CASE WHEN raw_rp IS NULL THEN NULL ELSE raw_rp::DECIMAL(18, 2) - dup_dropped_rp - rejected_rp - excluded_rp - fact_rp END AS diff_rp,
       note
FROM r ORDER BY ord;

-- Jembatan dari nilai mentah ke Net Sales di fact_sales (POS + online)
CREATE OR REPLACE TABLE dq.net_sales_bridge AS
WITH t AS (
  SELECT
    (SELECT sum(raw_rp) FROM dq.reconciliation WHERE source_name LIKE 'POS%' OR source_name LIKE 'Online%') AS raw_total,
    (SELECT sum(dup_dropped_rp) FROM dq.reconciliation WHERE source_name LIKE 'POS%' OR source_name LIKE 'Online%') AS dup_total,
    (SELECT coalesce(sum(net), 0) FROM stg.pos_line WHERE disposition = 'REJECT_STORE_NOT_IN_MASTER') AS trn99,
    (SELECT coalesce(sum(net), 0) FROM stg.pos_line WHERE disposition LIKE 'EXCLUDE%') AS void_pairs,
    (SELECT coalesce(sum(net), 0) FROM stg.online_line WHERE disposition = 'EXCLUDE_CANCELLED') AS cancelled,
    (SELECT coalesce(sum(net), 0) FROM stg.pos_line WHERE disposition LIKE 'REJECT%' AND disposition <> 'REJECT_STORE_NOT_IN_MASTER')
      + (SELECT coalesce(sum(net), 0) FROM stg.online_line WHERE disposition LIKE 'REJECT%') AS other_rejects,
    (SELECT sum(net_sales) FROM dw.fact_sales) AS fact_net,
    (SELECT sum(gross_sales) FROM dw.fact_sales) AS fact_gross,
    (SELECT sum(discount) FROM dw.fact_sales) AS fact_discount)
SELECT * FROM (
  SELECT 1 AS step_no, 'Nilai bersih mentah POS + online (qty x harga - diskon/voucher)' AS step, raw_total AS rp FROM t
  UNION ALL SELECT 2, 'dikurangi salinan duplikat persis (DQ-04, DQ-10)', -dup_total FROM t
  UNION ALL SELECT 3, 'dikurangi TRN-99, toko di luar master (DQ-02)', -trn99 FROM t
  UNION ALL SELECT 4, 'dikurangi void kasir dan baris asli yang di-void (DQ-06; efek bersih kecil karena saling meniadakan)', -void_pairs FROM t
  UNION ALL SELECT 5, 'dikurangi order online CANCELLED (DQ-11)', -cancelled FROM t
  UNION ALL SELECT 6, 'dikurangi penolakan lain (harus 0)', -other_rejects FROM t
  UNION ALL SELECT 7, '= Net Sales hasil jembatan', raw_total - dup_total - trn99 - void_pairs - cancelled - other_rejects FROM t
  UNION ALL SELECT 8, 'Net Sales di dw.fact_sales', fact_net FROM t
  UNION ALL SELECT 9, 'Selisih jembatan vs fact_sales (harus 0)', raw_total - dup_total - trn99 - void_pairs - cancelled - other_rejects - fact_net FROM t
  UNION ALL SELECT 10, 'Rincian fact_sales: gross sales (qty x harga)', fact_gross FROM t
  UNION ALL SELECT 11, 'Rincian fact_sales: diskon POS + voucher online', -fact_discount FROM t
) ORDER BY step_no;
