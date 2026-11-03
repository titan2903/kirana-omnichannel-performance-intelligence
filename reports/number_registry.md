# Number Registry

Dihasilkan otomatis oleh `scripts/export_reports.sh` dari `kirana.duckdb`. Setiap angka di insight brief dan laporan harus berasal dari sini
(atau dari kartu Metabase yang membaca view yang sama). Periode: FY2024 = Jan–Des 2024, FY2025 = Jan–Des 2025, H1 2026 = Jan–Jun 2026.
Rupiah, tanpa pajak. Rasio dihitung ulang dari pembilang/penyebut. Data sampai: 30 Jun 2026.

## 1. Net Sales per channel dan periode
*View: `metrics.v_sales_monthly`. Filter: periode. Termasuk B2B bulk.*

| periode |   channel   | net_sales_idr | kontribusi_pct |
|---------|-------------|--------------:|---------------:|
| FY2024  | Marketplace | 6564843100    | 17.5           |
| FY2024  | Mobile App  | 3949287900    | 10.5           |
| FY2024  | Store       | 23585615400   | 62.7           |
| FY2024  | Website     | 3519832900    | 9.4            |
| FY2025  | Marketplace | 9293547000    | 21.1           |
| FY2025  | Mobile App  | 6601860400    | 15.0           |
| FY2025  | Store       | 25234099400   | 57.4           |
| FY2025  | Website     | 2827730500    | 6.4            |
| H1 2026 | Marketplace | 5865550500    | 23.3           |
| H1 2026 | Mobile App  | 4702395100    | 18.7           |
| H1 2026 | Store       | 13404994900   | 53.2           |
| H1 2026 | Website     | 1237537600    | 4.9            |

## 2. Achievement vs Target per channel
*View: `metrics.v_target_achievement`. Filter: periode FY2025 dan H1 2026 (2024 tidak punya target).*

| periode |   channel   | net_sales_idr | target_idr  | achievement_pct | status |
|---------|-------------|--------------:|------------:|----------------:|--------|
| FY2025  | Marketplace | 9293547000    | 8525000000  | 109.0           | Hijau  |
| FY2025  | Mobile App  | 6601860400    | 5542000000  | 119.1           | Hijau  |
| FY2025  | Store       | 25234099400   | 26391000000 | 95.6            | Kuning |
| FY2025  | Website     | 2827730500    | 3723000000  | 76.0            | Merah  |
| H1 2026 | Marketplace | 5865550500    | 4601000000  | 127.5           | Hijau  |
| H1 2026 | Mobile App  | 4702395100    | 3782000000  | 124.3           | Hijau  |
| H1 2026 | Store       | 13404994900   | 14022000000 | 95.6            | Kuning |
| H1 2026 | Website     | 1237537600    | 1415000000  | 87.5            | Merah  |

## 3. Achievement Store per region
*View: `metrics.v_target_achievement` (channel Store, region dasar target `region_target_basis` = region awal tahun).*

| periode |        region        | net_sales_idr | target_idr | achievement_pct | status |
|---------|----------------------|--------------:|-----------:|----------------:|--------|
| FY2025  | Bali & Nusa Tenggara | 1124506000    | 1239000000 | 90.8            | Kuning |
| FY2025  | Jabodetabek          | 9494637900    | 9932000000 | 95.6            | Kuning |
| FY2025  | Jateng & DIY         | 3545477900    | 3500000000 | 101.3           | Hijau  |
| FY2025  | Jawa Barat           | 4465127100    | 4430000000 | 100.8           | Hijau  |
| FY2025  | Jawa Timur           | 4382882600    | 4729000000 | 92.7            | Kuning |
| FY2025  | Sumatera             | 2221467900    | 2561000000 | 86.7            | Merah  |
| H1 2026 | Bali & Nusa Tenggara | 755030500     | 782000000  | 96.6            | Kuning |
| H1 2026 | Jabodetabek          | 5679016700    | 5872000000 | 96.7            | Kuning |
| H1 2026 | Jateng & DIY         | 1777878900    | 1935000000 | 91.9            | Kuning |
| H1 2026 | Jawa Barat           | 1653486600    | 1726000000 | 95.8            | Kuning |
| H1 2026 | Jawa Timur           | 2439007800    | 2470000000 | 98.7            | Kuning |
| H1 2026 | Sumatera             | 1100574400    | 1237000000 | 89.0            | Merah  |

## 4. Achievement per toko (target ALOKASI, asumsi)
*View: `metrics.v_store_target_alloc`. Hanya toko dengan achievement terendah per periode; daftar lengkap di view.*

| periode |  toko  |        region        | net_sales_idr | store_target_idr | achievement_pct |
|---------|--------|----------------------|--------------:|-----------------:|----------------:|
| FY2025  | MDN-01 | Sumatera             | 1154377400    | 1455754782       | 79.3            |
| FY2025  | SBY-01 | Jawa Timur           | 1995235000    | 2241752328       | 89.0            |
| FY2025  | JKT-03 | Jabodetabek          | 1506758500    | 1670893994       | 90.2            |
| FY2025  | DPK-01 | Jabodetabek          | 911142500     | 1009850993       | 90.2            |
| FY2025  | DPS-01 | Bali & Nusa Tenggara | 1124506000    | 1239000000       | 90.8            |
| H1 2026 | MDN-01 | Sumatera             | 544980300     | 652367619        | 83.5            |
| H1 2026 | SBY-02 | Jawa Timur           | 629045100     | 716189392        | 87.8            |
| H1 2026 | MLG-01 | Jawa Timur           | 534782500     | 608241365        | 87.9            |
| H1 2026 | SOL-01 | Jateng & DIY         | 441268900     | 490862178        | 89.9            |
| H1 2026 | YGY-01 | Jateng & DIY         | 637043000     | 700466062        | 90.9            |

## 5. Gross Margin % dan Contribution Margin % per channel
*View: `metrics.v_margin_vs_target`. GM target dari FP&A; CM target = Target GM - tarif channel (ASUMSI).*

| periode |   channel   | gm_pct | target_gm_pct | cm_pct |
|---------|-------------|-------:|---------------|-------:|
| FY2024  | Marketplace | 43.88  | NULL          | 34.88  |
| FY2024  | Mobile App  | 44.57  | NULL          | 42.37  |
| FY2024  | Store       | 46.92  | NULL          | 46.22  |
| FY2024  | Website     | 46.54  | NULL          | 44.34  |
| FY2025  | Marketplace | 41.84  | 42.0          | 30.87  |
| FY2025  | Mobile App  | 42.07  | 43.0          | 39.87  |
| FY2025  | Store       | 45.7   | 46.0          | 45.0   |
| FY2025  | Website     | 45.46  | 45.0          | 43.26  |
| H1 2026 | Marketplace | 42.08  | 42.0          | 30.58  |
| H1 2026 | Mobile App  | 40.48  | 43.0          | 38.28  |
| H1 2026 | Store       | 44.29  | 46.0          | 43.59  |
| H1 2026 | Website     | 43.89  | 45.0          | 41.69  |

## 6. Gross Margin % total per periode (efek SCD HPP)
*View: `metrics.v_sales_monthly`. Pembanding dengan HPP terkini ada di `sql/analysis/scd_impact.sql`.*

| periode | net_sales_idr | gm_pct | cm_pct |
|---------|--------------:|-------:|-------:|
| FY2024  | 37619579300   | 46.11  | 43.66  |
| FY2025  | 43957237300   | 44.32  | 41.13  |
| H1 2026 | 25210478100   | 43.05  | 39.48  |

## 7. Jumlah Transaksi dan AOV per channel
*View: `metrics.v_txn_monthly`. AOV = SUM(net_sales_idr) / SUM(transactions).*

| periode |   channel   | transaksi | aov_idr |
|---------|-------------|----------:|--------:|
| FY2024  | Marketplace | 19984     | 328505  |
| FY2024  | Mobile App  | 11679     | 338153  |
| FY2024  | Store       | 54720     | 431024  |
| FY2024  | Website     | 10254     | 343264  |
| FY2025  | Marketplace | 28133     | 330343  |
| FY2025  | Mobile App  | 19418     | 339987  |
| FY2025  | Store       | 58480     | 431500  |
| FY2025  | Website     | 8336      | 339219  |
| H1 2026 | Marketplace | 17116     | 342694  |
| H1 2026 | Mobile App  | 13649     | 344523  |
| H1 2026 | Store       | 30569     | 438516  |
| H1 2026 | Website     | 3468      | 356845  |

## 8. Return Rate per channel
*View: `metrics.v_return_rate_monthly`. Rate Rp = SUM(refund_idr) / SUM(net_sales_idr); retur menurut tanggal retur.*

| periode |   channel   | refund_idr | return_rate_pct | return_rate_unit_pct |
|---------|-------------|-----------:|----------------:|---------------------:|
| FY2024  | Marketplace | 408768500  | 6.23            | 5.92                 |
| FY2024  | Mobile App  | 195843600  | 4.96            | 5.31                 |
| FY2024  | Store       | 426032200  | 1.81            | 1.77                 |
| FY2024  | Website     | 144355200  | 4.1             | 4.42                 |
| FY2025  | Marketplace | 605383700  | 6.51            | 6.24                 |
| FY2025  | Mobile App  | 342923100  | 5.19            | 5.44                 |
| FY2025  | Store       | 508220200  | 2.01            | 1.98                 |
| FY2025  | Website     | 129191600  | 4.57            | 4.67                 |
| H1 2026 | Marketplace | 373681500  | 6.37            | 6.29                 |
| H1 2026 | Mobile App  | 240793100  | 5.12            | 5.39                 |
| H1 2026 | Store       | 265847200  | 1.98            | 2.04                 |
| H1 2026 | Website     | 60787400   | 4.91            | 4.62                 |

## 9. Alasan retur (seluruh periode)
*View: `metrics.v_return_reason_monthly`.*

|         alasan          | retur | refund_idr | pangsa_refund_pct |
|-------------------------|------:|-----------:|------------------:|
| Barang cacat            | 3539  | 855415400  | 23.1              |
| Ukuran tidak sesuai     | 4806  | 855279500  | 23.1              |
| Berubah pikiran         | 3001  | 571854800  | 15.4              |
| Rusak saat pengiriman   | 2434  | 563880600  | 15.2              |
| Tidak sesuai deskripsi  | 1925  | 424429300  | 11.5              |
| Warna berbeda dari foto | 1545  | 281566600  | 7.6               |
| Salah kirim             | 839   | 149401100  | 4.0               |

## 10. Active Members dan Repeat Rate
*View: `metrics.v_members_period` (period_type Tahun untuk FY2024 dan FY2025, Semester untuk H1 2025 dan H1 2026). Struk B2B dikecualikan. Bandingkan hanya periode sama panjang: H1 2026 dengan H1 2025, bukan dengan FY.*

| periode |    channel    | active_members | repeat_members | repeat_rate_pct |
|---------|---------------|---------------:|---------------:|----------------:|
| FY2024  | Marketplace   | 13049          | 4184           | 32.06           |
| FY2024  | Mobile App    | 8820           | 2003           | 22.71           |
| FY2024  | Semua channel | 30450          | 18505          | 60.77           |
| FY2024  | Store         | 19474          | 7511           | 38.57           |
| FY2024  | Website       | 7968           | 1627           | 20.42           |
| FY2025  | Marketplace   | 16307          | 6257           | 38.37           |
| FY2025  | Mobile App    | 12781          | 3973           | 31.09           |
| FY2025  | Semua channel | 32707          | 21631          | 66.14           |
| FY2025  | Store         | 20713          | 8213           | 39.65           |
| FY2025  | Website       | 6756           | 1194           | 17.67           |
| H1 2025 | Marketplace   | 9011           | 2066           | 22.93           |
| H1 2025 | Mobile App    | 6767           | 1275           | 18.84           |
| H1 2025 | Semua channel | 23255          | 10068          | 43.29           |
| H1 2025 | Store         | 12707          | 2741           | 21.57           |
| H1 2025 | Website       | 3829           | 408            | 10.66           |
| H1 2026 | Marketplace   | 11637          | 3381           | 29.05           |
| H1 2026 | Mobile App    | 9993           | 2456           | 24.58           |
| H1 2026 | Semua channel | 25618          | 12837          | 50.11           |
| H1 2026 | Store         | 13122          | 3144           | 23.96           |
| H1 2026 | Website       | 3140           | 286            | 9.11            |

## 11. Cancellation Rate (online) dan Void Rate (POS)
*View: `metrics.v_cancellation_void_monthly`.*

| periode | cancellation_rate_online_pct | void_rate_pos_pct |
|---------|-----------------------------:|------------------:|
| FY2024  | 5.95                         | 0.63              |
| FY2025  | 6.16                         | 0.67              |
| H1 2026 | 6.09                         | 0.66              |

## 12. Promo: Lift dan dampak margin per jenis
*View: `metrics.v_promo_performance`. Lift dan perubahan GM per jenis = rasio gabungan (jumlah pembilang / jumlah penyebut), sama dengan kartu Metabase dan brief; min/maks = rentang lift per kode; nilai Rupiah dijumlahkan. Baseline simetris +/-1 sampai 4 minggu.*

|   jenis    | kode | lift_net_pct | lift_min_pct | lift_maks_pct | lift_unit_pct | perubahan_gm_pt | incremental_net_sales_idr | incremental_gross_margin_idr | diskon_idr | anggaran_idr | pemakaian_anggaran_pct |
|------------|-----:|-------------:|-------------:|--------------:|--------------:|----------------:|--------------------------:|-----------------------------:|-----------:|-------------:|-----------------------:|
| App Payday | 27   | 66.4         | 19.2         | 153.7         | 84.0          | -6.14           | 1151713694                | 325748866                    | 307011000  | 3240000000   | 9.5                    |
| Clearance  | 3    | -33.1        | -40.3        | -19.4         | -2.8          | -19.3           | -177099692                | -166112193                   | 153764800  | 1200000000   | 12.8                   |
| Harbolnas  | 2    | 67.8         | 51.8         | 79.8          | 122.6         | -15.11          | 11998050                  | 918125                       | 9898500    | 500000000    | 2.0                    |
| Mega Sale  | 8    | 449.6        | 372.0        | 561.3         | 872.0         | -50.64          | 417072602                 | -101117490                   | 417236500  | 7200000000   | 5.8                    |
| Member Day | 30   | 12.1         | -12.6        | 138.0         | 22.6          | -5.98           | 155762693                 | -13650510                    | 152345000  | 4500000000   | 3.4                    |
| Ramadan    | 3    | 31.5         | 29.9         | 34.4          | 55.8          | -8.28           | 1223347756                | 225282835                    | 901986700  | 4500000000   | 20.0                   |

## 13. Kesegaran data
*View: `metrics.v_data_freshness`.*

| data_from_date | data_through_date | sync_success_pct | failed_store_days | closed_store_days |                                      freshness_label                                      |
|----------------|-------------------|-----------------:|------------------:|------------------:|-------------------------------------------------------------------------------------------|
| 2024-01-01     | 2026-06-30        | 99.65            | 7                 | 49                | Data sampai 30 Jun 2026; sync POS berhasil 99.65% (7 toko-hari gagal, 49 toko-hari tutup) |
