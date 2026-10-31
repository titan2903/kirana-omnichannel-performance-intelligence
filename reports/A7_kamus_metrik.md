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
### 1. Net Sales

- **Definisi bisnis:** Nilai penjualan bersih: harga x qty dikurangi diskon POS atau voucher online, tanpa pajak, sebelum dikurangi retur.
- **Rumus SQL:** `SUM(net_sales_idr)`
- **Grain:** bulan x channel x region (dasar target, region_target_basis) x toko x kategori x flag B2B
- **View sumber:** `metrics.v_sales_monthly`
- **Aturan inklusi/eksklusi:** Termasuk: POS valid dan order online COMPLETED, B2B bulk (dapat dikeluarkan lewat is_b2b_bulk). Dikecualikan: void dan baris asli yang di-void, order CANCELLED, duplikat, toko di luar master (TRN-99). Retur dan biaya channel TIDAK dikurangkan.
- **Pemilik metrik:** Finance Controller
- **Target / ambang:** Target bulanan FP&A per channel/region (FY2025 Rp 44,181 miliar; H1 2026 Rp 23,820 miliar, semua channel). Tidak ada target 2024.

### 2. Achievement vs Target %

- **Definisi bisnis:** Net Sales aktual dibagi target Net Sales pada grain target (Store per region, online per channel nasional).
- **Rumus SQL:** `100 * SUM(net_sales_idr) / NULLIF(SUM(target_net_sales_idr), 0)`
- **Grain:** bulan x channel x region (Store) atau nasional (online)
- **View sumber:** `metrics.v_target_achievement`
- **Aturan inklusi/eksklusi:** Aktual dikelompokkan menurut peta region AWAL TAHUN (dasar penetapan target; BGR-01 di Jawa Barat sepanjang 2025, di Jabodetabek mulai 2026), bukan region saat transaksi: target FY2025 tidak disesuaikan saat BGR-01 pindah (Jul 2025), sehingga region saat transaksi menciptakan lonjakan palsu. B2B bulk termasuk (net_sales_ex_b2b_idr tersedia). Kategori tidak berlaku karena target tidak per kategori. NULL = tidak ada target. Per toko: v_store_target_alloc dengan target ALOKASI (asumsi).
- **Pemilik metrik:** Direktur Komersial
- **Target / ambang:** Hijau >= 100%; Kuning 90 sampai <100%; Merah < 90% (ASUMSI analis, ref_status_threshold).

### 3. Gross Margin %

- **Definisi bisnis:** (Net Sales - COGS) / Net Sales. COGS = qty x HPP yang berlaku pada tanggal transaksi.
- **Rumus SQL:** `100 * SUM(gross_margin_idr) / NULLIF(SUM(net_sales_idr), 0)`
- **Grain:** bulan x channel x region x toko x kategori
- **View sumber:** `metrics.v_sales_monthly`
- **Aturan inklusi/eksklusi:** Basis baris sama dengan Net Sales: tanpa void dan baris asli yang di-void, tanpa order CANCELLED, tanpa TRN-99; retur tidak dikurangkan. HPP as-of dari product_cost_history (bukan HPP terkini). Margin dihitung setelah diskon/voucher dan sebelum biaya channel.
- **Pemilik metrik:** Finance Controller
- **Target / ambang:** Target GM FP&A per channel: Store 46%, Website 45%, Mobile App 43%, Marketplace 42%. Hijau: selisih >= 0 pt; Kuning: sampai -2 pt; Merah: lebih dari 2 pt di bawah target (ASUMSI).

### 4. Contribution Margin %

- **Definisi bisnis:** (Gross Margin - biaya channel) / Net Sales. Biaya channel = Net Sales x tarif channel yang berlaku pada tanggal transaksi.
- **Rumus SQL:** `100 * SUM(contribution_margin_idr) / NULLIF(SUM(net_sales_idr), 0)`
- **Grain:** bulan x channel x region x toko x kategori
- **View sumber:** `metrics.v_sales_monthly / metrics.v_margin_vs_target`
- **Aturan inklusi/eksklusi:** Basis baris sama dengan Net Sales: tanpa void dan baris asli yang di-void, tanpa order CANCELLED, tanpa TRN-99; retur tidak dikurangkan. Tarif: Store 0,7%; Website dan Mobile App 2,2%; Marketplace 9,0% sampai 31 Mar 2025 lalu 11,5%. Biaya operasional toko dan biaya marketing di luar promo tidak tersedia di data.
- **Pemilik metrik:** Finance Controller
- **Target / ambang:** Target turunan = Target GM - tarif channel berlaku (ASUMSI; FP&A tidak menetapkan target CM). Status memakai ambang selisih yang sama dengan Gross Margin.

### 5. Return Rate

- **Definisi bisnis:** Nilai refund retur dibagi Net Sales (Rp), dan qty retur dibagi qty terjual (unit).
- **Rumus SQL:** `100 * SUM(refund_idr) / NULLIF(SUM(net_sales_idr), 0); 100 * SUM(return_qty) / NULLIF(SUM(qty_sold), 0)`
- **Grain:** bulan x channel x region x kategori
- **View sumber:** `metrics.v_return_rate_monthly`
- **Aturan inklusi/eksklusi:** Retur dikelompokkan menurut tanggal retur; penjualan menurut tanggal jual. Atribut retur mengikuti penjualan asal. Retur yatim dikarantina. Alasan retur: v_return_reason_monthly.
- **Pemilik metrik:** Head of Store Operations (Store); Head of E-Commerce (online)
- **Target / ambang:** Tidak ada target resmi. Pembanding: tahun lalu dan rata-rata channel; pemilik menetapkan ambang.

### 6. Average Order Value (AOV)

- **Definisi bisnis:** Net Sales per struk/order.
- **Rumus SQL:** `SUM(net_sales_idr) / NULLIF(SUM(transactions), 0)`
- **Grain:** bulan x channel x region x toko x member x B2B
- **View sumber:** `metrics.v_txn_monthly`
- **Aturan inklusi/eksklusi:** Struk = (sumber, trx_id/order_no) distinct. Struk void dan order CANCELLED tidak dihitung; retur tidak dikurangkan. Hanya pada view tanpa kategori/promo karena 39% struk memuat lebih dari satu kategori.
- **Pemilik metrik:** Direktur Komersial
- **Target / ambang:** Tidak ada target resmi. Pembanding: bulan yang sama tahun lalu.

### 7. Jumlah Transaksi

- **Definisi bisnis:** Banyaknya struk POS atau order online valid.
- **Rumus SQL:** `SUM(transactions)`
- **Grain:** bulan x channel x region x toko x member x B2B
- **View sumber:** `metrics.v_txn_monthly`
- **Aturan inklusi/eksklusi:** Tidak termasuk void dan order CANCELLED. Aditif lintas channel, toko, region, dan bulan (satu struk hanya punya satu nilai tiap atribut itu). TIDAK aditif lintas kategori atau promo.
- **Pemilik metrik:** Direktur Komersial
- **Target / ambang:** Tidak ada target resmi. Pembanding: tahun lalu.

### 8. Active Members

- **Definisi bisnis:** Member (customer_key > 0) yang memiliki minimal satu struk pada periode.
- **Rumus SQL:** `active_members (pilih satu period_type, filter period_start dan channel_name)`
- **Grain:** tipe periode (Bulan, Kuartal, Semester, Tahun) x periode x channel (+ Semua channel)
- **View sumber:** `metrics.v_members_period`
- **Aturan inklusi/eksklusi:** Struk B2B bulk dikecualikan. Member unik tidak aditif lintas periode atau channel, maka dihitung per tipe periode. Dua customer_id dengan email sama dihitung sebagai dua member (DQ-19).
- **Pemilik metrik:** Head of E-Commerce (online); Head of Store Operations (Store)
- **Target / ambang:** Tidak ada target resmi. Pembanding: periode yang sama tahun lalu.

### 9. Repeat Rate

- **Definisi bisnis:** Persentase Active Members yang bertransaksi minimal dua kali (dua struk berbeda) pada periode yang sama.
- **Rumus SQL:** `100 * repeat_members / NULLIF(active_members, 0)`
- **Grain:** tipe periode x periode x channel (+ Semua channel)
- **View sumber:** `metrics.v_members_period`
- **Aturan inklusi/eksklusi:** Dihitung dalam periode dan channel yang dipilih; repeat di channel A dan satu kali di channel B tidak dihitung repeat pada channel masing-masing, tetapi dihitung repeat pada Semua channel. Nilai bergantung pada panjang periode: bandingkan hanya periode sama panjang (H1 2026 dengan H1 2025, bukan dengan FY2025).
- **Pemilik metrik:** Head of E-Commerce (online); Head of Store Operations (Store)
- **Target / ambang:** Tidak ada target resmi. Pembanding: periode yang sama tahun lalu.

### 10. Promo Lift dan Dampak Margin

- **Definisi bisnis:** Kenaikan Net Sales (dan unit) pada jendela promo terhadap baseline, beserta perubahan margin dan margin tambahan dalam Rupiah.
- **Rumus SQL:** `lift_net_pct = 100 * (net_sales_idr / baseline_net_sales_idr - 1); incremental_gross_margin_idr = gross_margin_idr - baseline_gross_margin_idr`
- **Grain:** satu kode promo (73)
- **View sumber:** `metrics.v_promo_performance`
- **Aturan inklusi/eksklusi:** Scope = channel, kategori, dan (bila member-only) penjualan member; B2B bulk dikecualikan. Baseline = hari yang sama pada +/-1 sampai 4 minggu, tanpa hari yang tercakup promo beririsan; pembanding YoY +/-364 hari. Net Sales sudah dikurangi diskon. Tidak mengendalikan musiman.
- **Pemilik metrik:** Direktur Komersial (Marketing)
- **Target / ambang:** Tidak ada target resmi. Kriteria usulan: promo menguntungkan bila incremental_gross_margin_idr > 0; baseline_quality harus BAIK.

### 11. Cancellation Rate dan Void Rate

- **Definisi bisnis:** Cancellation Rate: Rp order CANCELLED dibagi (COMPLETED + CANCELLED) pada online. Void Rate: Rp baris asli yang di-void dibagi (valid + di-void) pada POS.
- **Rumus SQL:** `100 * SUM(cancelled_net_sales_idr) / NULLIF(SUM(valid_net_sales_idr) + SUM(cancelled_net_sales_idr), 0)`
- **Grain:** bulan x channel x region
- **View sumber:** `metrics.v_cancellation_void_monthly`
- **Aturan inklusi/eksklusi:** Baris void bernilai negatif tidak dihitung agar tidak mengurangi dua kali. Hanya channel yang relevan: pembatalan untuk online, void untuk Store.
- **Pemilik metrik:** Head of E-Commerce (pembatalan); Head of Store Operations (void)
- **Target / ambang:** Tidak ada target resmi. Pembanding: tahun lalu.

### 12. Promo Budget Utilization

- **Definisi bisnis:** Diskon yang benar-benar diberikan lewat kode promo dibagi anggaran promo (budget_idr).
- **Rumus SQL:** `100 * SUM(discount_idr) / NULLIF(SUM(budget_idr), 0)`
- **Grain:** satu kode promo
- **View sumber:** `metrics.v_promo_performance`
- **Aturan inklusi/eksklusi:** Diskon = jumlah discount pada baris yang memakai kode promo (POS promo_code, online voucher). Anggaran dari promotions.csv; biaya non-diskon (iklan, dll.) tidak tersedia.
- **Pemilik metrik:** Finance Controller; Direktur Komersial (Marketing)
- **Target / ambang:** Batas atas 100% dari anggaran promo.


## Ambang status (satu sumber untuk warna di semua kartu)

`basis = ASUMSI` berarti usulan analis yang perlu disetujui pemilik metrik; angka target Net Sales dan Target GM berasal dari FP&A.

|       kpi       | status | batas_bawah |  warna  |                     arti                     | basis  |
|-----------------|--------|------------:|---------|----------------------------------------------|--------|
| ACHIEVEMENT_PCT | Hijau  | 100.0       | #0ca30c | Net Sales >= target                          | ASUMSI |
| ACHIEVEMENT_PCT | Kuning | 90.0        | #fab219 | 90% sampai <100% dari target                 | ASUMSI |
| ACHIEVEMENT_PCT | Merah  | NULL        | #d03b3b | <90% dari target                             | ASUMSI |
| MARGIN_GAP_PT   | Hijau  | 0.0         | #0ca30c | Margin >= target                             | ASUMSI |
| MARGIN_GAP_PT   | Kuning | -2.0        | #fab219 | Di bawah target hingga 2 poin persentase     | ASUMSI |
| MARGIN_GAP_PT   | Merah  | NULL        | #d03b3b | Lebih dari 2 poin persentase di bawah target | ASUMSI |

## Katalog view (schema `metrics`)

| View | Grain | Dipakai untuk |
| --- | --- | --- |
| `v_sales_monthly` | bulan x channel x region (dasar target) x toko x kategori x B2B | Net Sales, Gross/Contribution Margin, tren, kontribusi channel |
| `v_txn_monthly` | bulan x channel x region x toko x member x B2B | Jumlah Transaksi, AOV |
| `v_target_achievement` | bulan x channel x region (Store) atau nasional (online) | Achievement vs Target, status warna |
| `v_store_target_alloc` | bulan x toko | Achievement per toko dengan target ALOKASI (asumsi, lihat KPI 2) |
| `v_store_performance_monthly` | bulan x toko | Achievement toko + status kelengkapan data (satu filter periode untuk keduanya) |
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
toko anggota region menurut peta awal tahun target (`region_target_basis`; BGR-01 di Jawa Barat sepanjang 2025, Jabodetabek mulai 2026). Region tanpa penjualan tahun
lalu (DPS-01 yang buka 15 Jan 2025) dibagi rata. Jumlah target toko selalu sama dengan target region (diuji, T44).

## Catatan metode: Promo Lift

Baseline = hari yang sama pada +/-1 sampai 4 minggu dari jendela promo (kelipatan 7 hari menjaga komposisi hari kerja; dua sisi meredam tren
musiman satu arah), tanpa hari yang tercakup promo lain yang scope-nya beririsan. Pembanding YoY = +/-364 hari (tersedia untuk 20 promo).
Lift dihitung pada Net Sales (sudah dikurangi diskon) dan unit. `incremental_gross_margin_idr` sudah memperhitungkan biaya diskon.
**Keterbatasan:** baseline tidak mengendalikan faktor musiman yang tidak terlihat dari tanggal (mis. gajian); sebaiknya promo dibandingkan
dengan promo sejenis (stabilitas lintas tahun) daripada dengan jenis promo lain.
