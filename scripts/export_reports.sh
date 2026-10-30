#!/usr/bin/env bash
# Hasilkan dokumen yang angkanya HARUS sama dengan dashboard langsung dari kirana.duckdb (tanpa ketik tangan):
#   reports/A7_kamus_metrik.md   dari metrics.kpi_dictionary + metrics.ref_status_threshold
#   reports/number_registry.md   angka FY2024 / FY2025 / H1 2026 per channel dan region, dihitung ulang dari view metrics
#   bash scripts/export_reports.sh        (DB=path untuk database lain)
# Rasio selalu dihitung ulang dari pembilang/penyebut (SUM/SUM), tidak pernah AVG kolom persen.
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${DB:-kirana.duckdb}
q() { duckdb -readonly "$DB" -markdown -c "$1"; }
P="CASE WHEN month_start < DATE '2025-01-01' THEN 'FY2024' WHEN month_start < DATE '2026-01-01' THEN 'FY2025' ELSE 'H1 2026' END"

# ------------------------------------------------------------------ A7 kamus metrik
{
cat <<'E'
# A7. Kamus Metrik

Dihasilkan otomatis oleh `scripts/export_reports.sh` dari tabel `metrics.kpi_dictionary` di `kirana.duckdb`; definisi di sini
sama persis dengan yang dipakai view. Semua kartu Metabase hanya `SELECT` dari schema `metrics`; tidak ada rumus KPI di Metabase.

## Aturan pakai (wajib)

1. **Ukuran aditif** (`*_idr`, `qty`, `lines`, `transactions`, `returns`) boleh di-`SUM` setelah filter apa pun.
2. **Kolom persen** (`*_pct`, `*_rate`) hanya kenyamanan pada grain view; **jangan di-AVG**. Hitung ulang dari pembilang dan penyebut,
   mis. Gross Margin % = `SUM(gross_margin_idr) / NULLIF(SUM(net_sales_idr), 0)`.
3. `transactions` aditif hanya pada view tanpa kategori/promo: satu struk punya tepat satu channel, toko, tanggal, dan status member,
   tetapi 39% struk memuat lebih dari satu kategori dan 10.597 struk memuat lebih dari satu promo.
4. Member unik tidak aditif lintas periode/channel; gunakan `metrics.v_members_period` dengan satu `period_type`.
5. `NULL` pada target/achievement berarti **tidak ada target** (seluruh 2024), bukan nol.
6. Net Sales **tidak** dikurangi retur. Retur dilaporkan terpisah sebagai Return Rate.

## Daftar KPI
E
duckdb -readonly "$DB" -noheader -list -separator '' -c "
SELECT '### ' || kpi_id || '. ' || kpi_name || chr(10) || chr(10)
  || '- **Definisi bisnis:** ' || business_definition || chr(10)
  || '- **Rumus SQL:** \`' || sql_formula || '\`' || chr(10)
  || '- **Grain:** ' || grain || chr(10)
  || '- **View sumber:** \`' || source_view || '\`' || chr(10)
  || '- **Aturan inklusi/eksklusi:** ' || inclusion_exclusion || chr(10)
  || '- **Pemilik metrik:** ' || owner || chr(10)
  || '- **Target / ambang:** ' || target_threshold || chr(10)
FROM metrics.kpi_dictionary ORDER BY kpi_id"
cat <<'E'

## Ambang status (satu sumber untuk warna di semua kartu)

`basis = ASUMSI` berarti usulan analis yang perlu disetujui pemilik metrik; angka target Net Sales dan Target GM berasal dari FP&A.

E
q "SELECT kpi, status, min_value AS batas_bawah, color_hex AS warna, meaning AS arti, basis FROM metrics.ref_status_threshold ORDER BY kpi, sort_order"
cat <<'E'

## Katalog view (schema `metrics`)

| View | Grain | Dipakai untuk |
| --- | --- | --- |
| `v_sales_monthly` | bulan x channel x region (as-of) x toko x kategori x B2B | Net Sales, Gross/Contribution Margin, tren, kontribusi channel |
| `v_txn_monthly` | bulan x channel x region x toko x member x B2B | Jumlah Transaksi, AOV |
| `v_target_achievement` | bulan x channel x region (Store) atau nasional (online) | Achievement vs Target, status warna |
| `v_store_target_alloc` | bulan x toko | Achievement per toko dengan target ALOKASI (asumsi, lihat KPI 2) |
| `v_margin_vs_target` | bulan x channel | GM% dan CM% terhadap target dan status |
| `v_return_rate_monthly` | bulan x channel x region x kategori | Return Rate (Rp dan unit) |
| `v_return_reason_monthly` | bulan x channel x region x kategori x alasan | Distribusi alasan retur |
| `v_cancellation_void_monthly` | bulan x channel x region | Cancellation Rate (online), Void Rate (POS) |
| `v_members_period` | tipe periode x periode x channel (+ Semua channel) | Active Members, Repeat Rate |
| `v_promo_performance` | satu kode promo | Promo Lift, dampak margin, pemakaian anggaran |
| `v_data_freshness` | satu baris | Indikator kesegaran data dan status sinkronisasi POS |
| `v_pos_sync_status` | toko | Status sinkronisasi terakhir per toko |
| `v_data_completeness` | bulan x toko | Penanda data tidak lengkap / toko tutup |

## Catatan metode: target toko (alokasi)

FP&A hanya menetapkan target Store **per region**. Target toko di `v_store_target_alloc` adalah alokasi (asumsi, bukan target resmi):
`target region bulan itu x pangsa toko`. Pangsa = penjualan toko (tanpa B2B) pada bulan yang sama tahun lalu dibagi total penjualan seluruh
toko anggota region pada akhir bulan target (SCD2, sehingga perpindahan BGR-01 pada Juli 2025 diperlakukan benar). Region tanpa penjualan tahun
lalu (DPS-01 yang buka 15 Jan 2025) dibagi rata. Jumlah target toko selalu sama dengan target region (diuji, T44).

## Catatan metode: Promo Lift

Baseline = hari yang sama pada +/-1 sampai 4 minggu dari jendela promo (kelipatan 7 hari menjaga komposisi hari kerja; dua sisi meredam tren
musiman satu arah), tanpa hari yang tercakup promo lain yang scope-nya beririsan. Pembanding YoY = +/-364 hari (tersedia untuk 20 promo).
Lift dihitung pada Net Sales (sudah dikurangi diskon) dan unit. `incremental_gross_margin_idr` sudah memperhitungkan biaya diskon.
**Keterbatasan:** baseline tidak mengendalikan faktor musiman yang tidak terlihat dari tanggal (mis. gajian); sebaiknya promo dibandingkan
dengan promo sejenis (stabilitas lintas tahun) daripada dengan jenis promo lain.
E
} > reports/A7_kamus_metrik.md

# ------------------------------------------------------------------ number registry
{
cat <<E
# Number Registry

Dihasilkan otomatis oleh \`scripts/export_reports.sh\` dari \`kirana.duckdb\`. Setiap angka di insight brief dan laporan harus berasal dari sini
(atau dari kartu Metabase yang membaca view yang sama). Periode: FY2024 = Jan–Des 2024, FY2025 = Jan–Des 2025, H1 2026 = Jan–Jun 2026.
Rupiah, tanpa pajak. Rasio dihitung ulang dari pembilang/penyebut. Data sampai: $(duckdb -readonly "$DB" -noheader -list -c "SELECT strftime(data_through_date, '%d %b %Y') FROM metrics.v_data_freshness").

## 1. Net Sales per channel dan periode
*View: \`metrics.v_sales_monthly\`. Filter: periode. Termasuk B2B bulk.*

E
q "WITH x AS (SELECT $P AS periode, channel_name AS channel, sum(net_sales_idr) AS net_sales_idr FROM metrics.v_sales_monthly GROUP BY ALL)
   SELECT periode, channel, net_sales_idr, round(100.0 * net_sales_idr / sum(net_sales_idr) OVER (PARTITION BY periode), 1) AS kontribusi_pct
   FROM x ORDER BY 1, 2"
cat <<'E'

## 2. Achievement vs Target per channel
*View: `metrics.v_target_achievement`. Filter: periode FY2025 dan H1 2026 (2024 tidak punya target).*

E
q "SELECT $P AS periode, channel_name AS channel, sum(net_sales_idr) AS net_sales_idr, sum(target_net_sales_idr) AS target_idr,
          round(100.0 * sum(net_sales_idr) / sum(target_net_sales_idr), 1) AS achievement_pct,
          CASE WHEN 100.0 * sum(net_sales_idr) / sum(target_net_sales_idr) >= 100 THEN 'Hijau' WHEN 100.0 * sum(net_sales_idr) / sum(target_net_sales_idr) >= 90 THEN 'Kuning' ELSE 'Merah' END AS status
   FROM metrics.v_target_achievement WHERE target_net_sales_idr IS NOT NULL GROUP BY ALL ORDER BY 1, 2"
cat <<'E'

## 3. Achievement Store per region
*View: `metrics.v_target_achievement` (channel Store, region as-of tanggal transaksi).*

E
q "SELECT $P AS periode, region, sum(net_sales_idr) AS net_sales_idr, sum(target_net_sales_idr) AS target_idr,
          round(100.0 * sum(net_sales_idr) / sum(target_net_sales_idr), 1) AS achievement_pct,
          CASE WHEN 100.0 * sum(net_sales_idr) / sum(target_net_sales_idr) >= 100 THEN 'Hijau' WHEN 100.0 * sum(net_sales_idr) / sum(target_net_sales_idr) >= 90 THEN 'Kuning' ELSE 'Merah' END AS status
   FROM metrics.v_target_achievement WHERE channel_name = 'Store' AND target_net_sales_idr IS NOT NULL GROUP BY ALL ORDER BY 1, 2"
cat <<'E'

## 4. Achievement per toko (target ALOKASI, asumsi)
*View: `metrics.v_store_target_alloc`. Hanya toko dengan achievement terendah per periode; daftar lengkap di view.*

E
q "SELECT periode, store_code AS toko, region, net_sales_idr, store_target_idr, achievement_pct FROM (
     SELECT CASE WHEN month_start < DATE '2026-01-01' THEN 'FY2025' ELSE 'H1 2026' END AS periode, store_code, any_value(region) AS region,
            sum(net_sales_idr) AS net_sales_idr, sum(store_target_idr)::BIGINT AS store_target_idr,
            round(100.0 * sum(net_sales_idr) / sum(store_target_idr), 1) AS achievement_pct,
            row_number() OVER (PARTITION BY CASE WHEN month_start < DATE '2026-01-01' THEN 'FY2025' ELSE 'H1 2026' END ORDER BY sum(net_sales_idr) / sum(store_target_idr)) AS rk
     FROM metrics.v_store_target_alloc GROUP BY CASE WHEN month_start < DATE '2026-01-01' THEN 'FY2025' ELSE 'H1 2026' END, store_code) WHERE rk <= 5 ORDER BY periode, rk"
cat <<'E'

## 5. Gross Margin % dan Contribution Margin % per channel
*View: `metrics.v_margin_vs_target`. GM target dari FP&A; CM target = Target GM - tarif channel (ASUMSI).*

E
q "SELECT $P AS periode, channel_name AS channel,
          round(100.0 * sum(gross_margin_idr) / sum(net_sales_idr), 2) AS gm_pct, round(avg(target_gm_pct), 1) AS target_gm_pct,
          round(100.0 * sum(contribution_margin_idr) / sum(net_sales_idr), 2) AS cm_pct
   FROM metrics.v_margin_vs_target GROUP BY ALL ORDER BY 1, 2"
cat <<'E'

## 6. Gross Margin % total per periode (efek SCD HPP)
*View: `metrics.v_sales_monthly`. Pembanding dengan HPP terkini ada di `sql/analysis/scd_impact.sql`.*

E
q "SELECT $P AS periode, sum(net_sales_idr) AS net_sales_idr, round(100.0 * sum(gross_margin_idr) / sum(net_sales_idr), 2) AS gm_pct,
          round(100.0 * sum(contribution_margin_idr) / sum(net_sales_idr), 2) AS cm_pct
   FROM metrics.v_sales_monthly GROUP BY 1 ORDER BY 1"
cat <<'E'

## 7. Jumlah Transaksi dan AOV per channel
*View: `metrics.v_txn_monthly`. AOV = SUM(net_sales_idr) / SUM(transactions).*

E
q "SELECT $P AS periode, channel_name AS channel, sum(transactions) AS transaksi, round(sum(net_sales_idr)::DOUBLE / sum(transactions))::BIGINT AS aov_idr
   FROM metrics.v_txn_monthly GROUP BY ALL ORDER BY 1, 2"
cat <<'E'

## 8. Return Rate per channel
*View: `metrics.v_return_rate_monthly`. Rate Rp = SUM(refund_idr) / SUM(net_sales_idr); retur menurut tanggal retur.*

E
q "SELECT $P AS periode, channel_name AS channel, sum(refund_idr) AS refund_idr, round(100.0 * sum(refund_idr) / sum(net_sales_idr), 2) AS return_rate_pct,
          round(100.0 * sum(return_qty) / sum(qty_sold), 2) AS return_rate_unit_pct
   FROM metrics.v_return_rate_monthly GROUP BY ALL ORDER BY 1, 2"
cat <<'E'

## 9. Alasan retur (seluruh periode)
*View: `metrics.v_return_reason_monthly`.*

E
q "SELECT return_reason AS alasan, sum(returns) AS retur, sum(refund_idr) AS refund_idr, round(100.0 * sum(refund_idr) / sum(sum(refund_idr)) OVER (), 1) AS pangsa_refund_pct
   FROM metrics.v_return_reason_monthly GROUP BY 1 ORDER BY 3 DESC"
cat <<'E'

## 10. Active Members dan Repeat Rate
*View: `metrics.v_members_period` (period_type Tahun untuk FY2024 dan FY2025, Semester untuk H1 2025 dan H1 2026). Struk B2B dikecualikan. Bandingkan hanya periode sama panjang: H1 2026 dengan H1 2025, bukan dengan FY.*

E
q "SELECT CASE WHEN period_type = 'Tahun' THEN 'FY' || period_label ELSE 'H1 ' || year(period_start)::VARCHAR END AS periode, channel_name AS channel, active_members, repeat_members, repeat_rate_pct
   FROM metrics.v_members_period WHERE (period_type = 'Tahun' AND period_start < DATE '2026-01-01') OR (period_type = 'Semester' AND period_start IN (DATE '2025-01-01', DATE '2026-01-01')) ORDER BY 1, 2"
cat <<'E'

## 11. Cancellation Rate (online) dan Void Rate (POS)
*View: `metrics.v_cancellation_void_monthly`.*

E
q "SELECT $P AS periode,
          round(100.0 * sum(cancelled_net_sales_idr) / (sum(valid_net_sales_idr) FILTER (WHERE channel_name <> 'Store') + sum(cancelled_net_sales_idr)), 2) AS cancellation_rate_online_pct,
          round(100.0 * sum(voided_net_sales_idr) / (sum(valid_net_sales_idr) FILTER (WHERE channel_name = 'Store') + sum(voided_net_sales_idr)), 2) AS void_rate_pos_pct
   FROM metrics.v_cancellation_void_monthly GROUP BY 1 ORDER BY 1"
cat <<'E'

## 12. Promo: Lift dan dampak margin per jenis
*View: `metrics.v_promo_performance`. Lift jenis = rata-rata lift per kode (informasi); nilai Rupiah dijumlahkan. Baseline simetris +/-1 sampai 4 minggu.*

E
q "SELECT promo_type AS jenis, count(*) AS kode, round(avg(lift_net_pct), 1) AS lift_net_rata2_pct, round(min(lift_net_pct), 1) AS lift_min_pct, round(max(lift_net_pct), 1) AS lift_maks_pct,
          round(avg(lift_qty_pct), 1) AS lift_unit_rata2_pct, round(avg(gm_change_pt), 2) AS perubahan_gm_rata2_pt,
          sum(incremental_net_sales_idr) AS incremental_net_sales_idr, sum(incremental_gross_margin_idr) AS incremental_gross_margin_idr,
          sum(discount_idr) AS diskon_idr, sum(budget_idr) AS anggaran_idr, round(100.0 * sum(discount_idr) / sum(budget_idr), 1) AS pemakaian_anggaran_pct
   FROM metrics.v_promo_performance GROUP BY 1 ORDER BY 1"
echo
echo "## 13. Kesegaran data"
echo "*View: \`metrics.v_data_freshness\`.*"
echo
q "SELECT data_from_date, data_through_date, sync_success_pct, failed_store_days, closed_store_days, freshness_label FROM metrics.v_data_freshness"
} > reports/number_registry.md
echo "OK: reports/A7_kamus_metrik.md dan reports/number_registry.md dibuat dari $DB"
