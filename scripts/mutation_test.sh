#!/usr/bin/env bash
# Mutation test untuk uji kualitas data: suntik satu cacat ke SALINAN database, jalankan ulang 04+05, dan pastikan
# uji yang tepat gagal. Membuktikan uji punya "gigi" (bukan sekadar selalu lolos). Database asli tidak diubah.
#   bash scripts/mutation_test.sh              (DB=path untuk database lain; default kirana.duckdb). Termasuk 12 mutasi semantic layer.
# Exit 1 bila ada cacat yang tidak terdeteksi.
set -uo pipefail
cd "$(dirname "$0")/.."
DB=${DB:-kirana.duckdb}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
cat > "$W/head.sql" <<'E'
.read sql/01_load.sql
CREATE OR REPLACE TEMP MACRO parse_price(x) AS CASE
  WHEN regexp_matches(x, '^[0-9]+$') THEN x::BIGINT
  WHEN regexp_matches(x, '^Rp[0-9]{1,3}(\.[0-9]{3})*$') THEN replace(replace(x, 'Rp', ''), '.', '')::BIGINT END;
E
KNOWN="'T21','T22','T29'"   # WARNING yang memang sudah diketahui (retur yatim, sync FAILED, B2B)
miss=0; n=0
run_mut() { # $1=nama  $2=uji yang harus ikut gagal  $3=SQL mutasi
  n=$((n+1)); cp "$DB" "$W/m.duckdb"; rm -f "$W/m.duckdb.wal"
  { cat "$W/head.sql"; echo "$3"; echo ".read sql/04_reconciliation.sql"; echo ".read sql/06_tests.sql"; } | duckdb "$W/m.duckdb" > "$W/out.txt" 2>&1
  err=$(grep -i -m1 "error" "$W/out.txt" || true)
  got=$(duckdb -readonly "$W/m.duckdb" -noheader -list -c "select coalesce(string_agg(test_id, ',' order by test_id),'') from dq.test_results where status='FAIL' and test_id not in ($KNOWN)" 2>&1 | tail -1)
  case ",$got," in *",$2,"*) ok="terdeteksi";; *) ok="TIDAK TERDETEKSI"; miss=$((miss+1));; esac
  printf "%-48s harapan=%-4s gagal=%-16s %s %s\n" "$1" "$2" "${got:-<tidak ada>}" "$ok" "${err:+[ERR: $err]}"
}
run_mut "M01 hapus 1 baris fact_sales (POS)"          T10 "DELETE FROM dw.fact_sales WHERE sales_key = 5;"
run_mut "M02 channel_key target NULL"                  T16 "UPDATE dw.fact_target SET channel_key = NULL WHERE target_key = 1;"
run_mut "M03 dim_store tumpang tindih (BGR-01)"        T14 "UPDATE dw.dim_store SET valid_to = DATE '9999-12-31' WHERE store_code = 'BGR-01';"
run_mut "M04 fact_returns tanpa tanggal jual"          T17 "UPDATE dw.fact_returns SET sale_date = NULL WHERE return_key = 1;"
run_mut "M05 baris stg ditolak diam-diam"              T18 "UPDATE stg.pos_line SET disposition = 'REJECT_UNPARSEABLE' WHERE pos_rid = (SELECT min(pos_rid) FROM stg.pos_line WHERE disposition = 'FACT');"
run_mut "M06 kolom PII (email) masuk dim_customer"     T12 "ALTER TABLE dw.dim_customer ADD COLUMN email VARCHAR;"
run_mut "M07 flag B2B salah pada 1 baris"              T13 "UPDATE dw.fact_sales SET is_b2b_bulk = true WHERE sales_key = (SELECT min(sales_key) FROM dw.fact_sales WHERE source_system = 'POS' AND NOT is_b2b_bulk);"
run_mut "M08 HPP ganda untuk 1 produk"                 T04 "INSERT INTO dw.dim_product_cost SELECT 99999, product_key, sku, unit_cost + 1, valid_from, valid_to, is_current FROM dw.dim_product_cost WHERE product_cost_key = 1;"
run_mut "M09 FK toko yatim"                            T02 "UPDATE dw.fact_sales SET store_key = 999 WHERE sales_key = 5;"
run_mut "M10 promo dipakai di luar channel_scope"      T26 "UPDATE dw.dim_promo SET channel_scope = 'Mobile App' WHERE promo_code = 'RMDN24';"
run_mut "M11 hapus 1 baris target"                     T28 "DELETE FROM dw.fact_target WHERE target_key = 20;"
run_mut "M12 sku ganda di dim_product"                 T15 "INSERT INTO dw.dim_product SELECT 99999, sku, product_name, category, subcategory, brand, list_price_current, launch_date FROM dw.dim_product WHERE product_key = 1;"
run_mut "M13 region POS tak resmi"                     T03 "UPDATE dw.fact_sales SET region_asof = 'Jabar' WHERE sales_key = 5;"
run_mut "M14 tarif channel hilang"                     T05 "UPDATE dw.fact_sales SET channel_fee_pct = NULL WHERE sales_key = 5;"
run_mut "M15 penjualan sebelum launch_date"            T27 "UPDATE dw.dim_product SET launch_date = DATE '2030-01-01' WHERE product_key = 1;"
run_mut "M16 retur duplikat di fact_returns"           T19 "INSERT INTO dw.fact_returns SELECT * FROM dw.fact_returns WHERE return_key = 1;"
run_mut "M17 retur atas penjualan yang dikeluarkan"    T30 "UPDATE stg.return_line SET disposition = 'REJECT_ORIGINAL_EXCLUDED' WHERE return_id = (SELECT min(return_id) FROM stg.return_line WHERE disposition = 'FACT');"
run_mut "M18 refund menyimpang dari nilai bersih"      T31 "UPDATE dw.fact_returns SET refund_amount = refund_amount + 5000 WHERE return_key = 1;"
run_mut "M19 jenis promo tak dikenal"                  T32 "UPDATE dw.dim_promo SET promo_type = 'Lainnya' WHERE promo_code = 'RMDN24';"
run_mut "M20 net sales negatif di fakta"               T20 "UPDATE dw.fact_sales SET net_sales = -1000 WHERE sales_key = 5;"
# --- semantic layer: rusak definisi view dengan membungkusnya (rename -> view baru yang salah) ---
wrap() { # $1=nama view  $2=SELECT yang membaca metrics.$1_orig
  echo "ALTER VIEW metrics.$1 RENAME TO $1_orig; CREATE VIEW metrics.$1 AS $2;"; }
run_mut "M21 v_sales_monthly kehilangan 1 kategori"    T41 "$(wrap v_sales_monthly "SELECT * FROM metrics.v_sales_monthly_orig WHERE category <> 'Fashion'")"
run_mut "M22 v_txn_monthly kehilangan baris B2B"       T42 "$(wrap v_txn_monthly "SELECT * FROM metrics.v_txn_monthly_orig WHERE NOT is_b2b_bulk")"
run_mut "M23 v_target_achievement kehilangan Website"  T43 "$(wrap v_target_achievement "SELECT * FROM metrics.v_target_achievement_orig WHERE channel_name <> 'Website'")"
run_mut "M24 alokasi target toko membengkak 10%"       T44 "$(wrap v_store_target_alloc "SELECT * REPLACE (store_target_idr * 1.1 AS store_target_idr) FROM metrics.v_store_target_alloc_orig")"
run_mut "M25 v_return_reason kehilangan 1 alasan"      T45 "$(wrap v_return_reason_monthly "SELECT * FROM metrics.v_return_reason_monthly_orig WHERE return_reason <> 'Salah kirim'")"
run_mut "M26 Active Members tahunan salah hitung"      T46 "$(wrap v_members_period "SELECT * REPLACE (CASE WHEN period_type = 'Tahun' THEN active_members + 1 ELSE active_members END AS active_members) FROM metrics.v_members_period_orig")"
run_mut "M27 tarif channel kosong di v_margin"         T47 "$(wrap v_margin_vs_target "SELECT * REPLACE (NULL::DECIMAL(5,2) AS channel_fee_pct) FROM metrics.v_margin_vs_target_orig")"
run_mut "M28 pembatalan terhitung dua kali"            T48 "$(wrap v_cancellation_void_monthly "SELECT * REPLACE (cancelled_net_sales_idr * 2 AS cancelled_net_sales_idr) FROM metrics.v_cancellation_void_monthly_orig")"
run_mut "M29 v_promo_performance kehilangan 1 promo"   T49 "$(wrap v_promo_performance "SELECT * FROM metrics.v_promo_performance_orig WHERE promo_code <> 'RMDN24'")"
run_mut "M30 baseline promo tidak memadai"             T50 "$(wrap v_promo_performance "SELECT * REPLACE (CASE WHEN promo_code = 'RMDN24' THEN 'TIDAK_CUKUP' ELSE baseline_quality END AS baseline_quality) FROM metrics.v_promo_performance_orig")"
run_mut "M31 penanda data tidak lengkap hilang"        T51 "$(wrap v_data_completeness "SELECT * REPLACE (0 AS failed_days) FROM metrics.v_data_completeness_orig")"
run_mut "M32 kamus merujuk view yang tidak ada"        T40 "UPDATE metrics.kpi_dictionary SET source_view = 'metrics.v_tidak_ada' WHERE kpi_id = 1;"
echo "---"
echo "$((n - miss)) dari $n cacat terdeteksi"
[ "$miss" -eq 0 ]
