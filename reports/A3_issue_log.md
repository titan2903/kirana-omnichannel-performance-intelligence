# A3. Data Quality Issue Log

Seluruh angka dihasilkan oleh `sql/profiling/02_issue_impact.sql` (dapat diulang dari `raw_data/`).
Kode `DQ-xx` dipakai sebagai komentar di `sql/02_staging.sql`.

**Cara membaca**

- **Rp terdampak** = nilai bersih baris terdampak (qty x harga − diskon/voucher, tanpa pajak, belum dikurangi retur). Untuk retur = `refund_amount`. Untuk void = nilai absolut.
- Satu baris dapat terkena lebih dari satu isu (mis. kode toko huruf kecil dan SKU berspasi), jadi **Rp antar-isu tidak boleh dijumlahkan**.
- Urutan perlakuan di pipeline: normalisasi format -> dedup -> pasangan void -> pengecualian. Hitungan duplikat, void, dan B2B dilakukan setelah normalisasi.
- Isu master dan region (DQ-13, 14, 15, 17) dihitung pada **penjualan valid**: POS setelah dedup, tanpa void dan baris asalnya, tanpa `TRN-99`; online hanya `COMPLETED`. Basis ini sama dengan rekonsiliasi di Task 2.
- **Jenis:** *Data* = galat sistem sumber; *Bisnis* = kejadian nyata; *Observasi* = tidak dikoreksi.
- Kolom **Uji** menunjuk pengujian kualitas data yang dibuat di Task 2 (B = BLOCKING, W = WARNING).

## 1. POS

| ID | Isu | File / kolom | Baris | Rp terdampak | Jenis | Keputusan | Alasan | Uji |
| --- | --- | --- | ---: | ---: | --- | --- | --- | --- |
| DQ-01 | Kode toko huruf kecil (`jkt-01`) | `sales_pos_transactions` / `store_code` | 3.236 | 753.013.400 | Data | **Koreksi:** `upper(trim())` | Tanpa koreksi, baris terpecah ke "toko" yang tidak ada di master sehingga hilang dari agregat toko, region, dan target | B: domain `store_code` |
| DQ-02 | Kode `TRN-99` tidak ada di `stores.csv`, sync log, maupun target | idem | 324 | 77.478.700 | Data | **Quarantine** (`stg.pos_line`, `disposition = REJECT_STORE_NOT_IN_MASTER`); tidak masuk fakta. 320 baris unik (324 dengan salinan duplikat); termasuk satu void tanpa pasangan (DQ-06c) | Tidak punya region, target, dan catatan sync; 0,12% nilai POS. Dugaan toko pelatihan/uji (**asumsi, perlu konfirmasi Store Operations**) | B: FK `store` yatim = 0 di fakta |
| DQ-03 | SKU berspasi / huruf kecil | idem / `sku` | 2.650 | 637.316.400 | Data | **Koreksi:** `upper(trim())` | Tanpa koreksi, join ke `products` dan `product_cost_history` gagal sehingga HPP/margin kosong. Setelah koreksi, 100% SKU cocok. Ikut membuat 58 duplikat tampak "konflik" padahal identik | B: FK `sku` yatim = 0 |
| DQ-04 | Duplikat persis `(trx_id, line_no)` setelah normalisasi | idem | 1.577 (ekstra) | 384.198.300 | Data | **Hapus** salinan ekstra, pertahankan satu | Salinan identik di semua kolom; menggandakan penjualan. Terbukti benar oleh kontrol sync log (A2 §5) | B: grain unik |
| DQ-05 | Tabrakan nomor struk: `(trx_id, line_no)` sama, item, kasir, dan pembayaran berbeda | idem | 20 grup | 8.474.000 (absolut) | Data | **Pertahankan** kedua baris, ditandai `key_collision`; grain memakai produk, bukan hanya `(trx_id, line_no)` | Item berbeda, bukan salinan; membuangnya menghilangkan penjualan. **Hasil implementasi:** seluruh 20 grup terdiri dari item dan void-nya, sehingga keduanya dikeluarkan lewat DQ-06 dan **tidak ada tabrakan tersisa di `fact_sales`** (T23 = 0) | W: T23 tabrakan kunci |
| DQ-06a | Void kasir (`qty < 0`) | idem / `qty` | 2.068 | 409.124.200 (absolut) | Bisnis | **Keluarkan** dari Net Sales dan hitungan transaksi; disimpan di `dw.fact_sales_excluded` (`VOID`) | Void membatalkan penjualan | B: rekonsiliasi |
| DQ-06b | Baris asli yang dibatalkan void (dipasangkan 1:1 per `trx_id`, `sku`, `qty`) | idem | 2.067 | 408.697.800 | Bisnis | **Keluarkan** bersama void-nya | Sync log hanya menghitung baris tanpa keduanya (A2 §5); jika hanya void dikeluarkan, penjualan tetap terhitung. 126 dari baris asli ini terjadi sebelum `launch_date` produk (DQ-17) | B: rekonsiliasi |
| DQ-06c | Void tanpa baris asli | idem | 1 | 403.900 | Data | **Quarantine** (`REJECT_VOID_WITHOUT_ORIGINAL`) | Tidak ada penjualan yang dapat dikoreksi. **Hasil implementasi:** satu-satunya void tanpa pasangan (trx `TRN-99-0124-0058041`) berada di toko `TRN-99`, sehingga sudah dikarantina lewat DQ-02; di toko master semua void berpasangan (T24 = 0) | W: T24 void tanpa pasangan |
| DQ-07 | Pembelian B2B bulk (`trx_id` memuat `B2B`, `line_no` 50, qty 152–446, `promo_code = B2B-CORP` yang tidak ada di `promotions`) | idem | 14 | 499.918.500 | Bisnis | **Pertahankan**, tandai `is_b2b_bulk`; `B2B-CORP` masuk `dim_promo` sebagai promo korporat tanpa diskon | Penjualan nyata (0,80% nilai POS) tetapi di luar sinkronisasi POS (A2 §5) dan tidak mewakili kinerja toko normal: terkonsentrasi di JKT-01, SBY-01, BDG-01. Tampilkan dengan dan tanpa B2B pada kinerja toko (Task 5) | W: promo di luar master |

## 2. Online

| ID | Isu | File / kolom | Baris | Rp terdampak | Jenis | Keputusan | Alasan | Uji |
| --- | --- | --- | ---: | ---: | --- | --- | --- | --- |
| DQ-08 | 12 label `sales_channel` (`MP`, `APP`, `WEB`, `Web Store`, `mobile_app`, ...) untuk 3 channel | `sales_online_orders` / `sales_channel` | 31.483 | 7.109.459.900 | Data | **Koreksi:** tabel pemetaan eksplisit ke Website / Mobile App / Marketplace | Tanpa pemetaan, agregat per channel terpecah dan tidak cocok dengan target per channel. Semua label terpetakan, tidak ada order terbelah dua channel | B: domain channel |
| DQ-09 | `item_price` berformat teks `Rp100.900` | idem / `item_price` | 36.179 | 8.050.182.800 | Data | **Koreksi:** hanya dua pola dikenali, angka polos dan `Rp` + ribuan bertitik (`Rp100.900`); pola lain tidak ditebak -> NULL -> quarantine (hasil: 0 baris) | Nilai teks tidak bisa dijumlah; mengabaikan baris ini menghilangkan 17% baris | B: harga numerik > 0 |
| DQ-10 | Duplikat persis `(order_no, line_no)` | idem | 232 (ekstra) | 48.915.600 | Data | **Hapus** salinan ekstra | Identik di semua kolom, tidak ada duplikat yang konflik | B: grain unik |
| DQ-11 | Order `CANCELLED` | idem / `order_status` | 12.733 | 2.882.492.400 | Bisnis | **Keluarkan** dari Net Sales; disimpan di `dw.fact_sales_excluded` (`exclude_reason = CANCELLED`) untuk cancellation rate | Tidak ada penjualan; berguna sebagai ukuran operasional | – |
| DQ-12 | `ship_province` kosong | idem / `ship_province` | 1.984 | 453.083.700 | Data | **Koreksi:** provinsi disimpulkan dari `ship_city` bila kota itu hanya berpasangan dengan satu provinsi di seluruh file; ditandai `province_source = INFERRED_FROM_CITY`. Bila tak terselesaikan -> `Lainnya` | Kota selalu terisi dan setiap kota hanya punya satu provinsi di 207 ribu baris lain, jadi penyimpulan deterministik. **Hasil:** seluruh 1.984 baris terselesaikan, tidak ada yang jatuh ke `Lainnya` karena ini | W: T25 provinsi tak terselesaikan |

Catatan pemetaan region online (bukan galat): Sulawesi Selatan (8.045 baris) dan Kalimantan Timur (2.587
baris) berada di luar enam region resmi sehingga masuk `Lainnya`, sesuai panduan paket data.

## 3. Master data, region, dan target

| ID | Isu | File / kolom | Baris | Rp terdampak | Jenis | Keputusan | Alasan | Uji |
| --- | --- | --- | ---: | ---: | --- | --- | --- | --- |
| DQ-13 | 6 SKU ganda di master (varian nama `(old)`) | `products` / `sku` | 6 SKU (3.699 baris penjualan valid) | 983.406.300 | Data | **Hapus** baris `(old)`, pertahankan satu per SKU | Atribut harga, HPP, dan kategori sama; join naif menggandakan penjualan SKU tersebut | B: `dim_product` unik |
| DQ-14 | Label kategori tidak baku: `Home Décor` (9), `kitchen & dining` (5) | `products` / `category` | 14 SKU (12.198 baris penjualan valid) | 2.314.085.900 | Data | **Koreksi:** ke `Home Decor` dan `Kitchen & Dining` | Memecah kategori pada agregat dan membuat 972 pemakaian promo tampak di luar `category_scope` | B: domain kategori |
| DQ-15 | Riwayat region hanya untuk BGR-01 (pindah Jawa Barat -> Jabodetabek 1 Jul 2025); 17 toko tanpa riwayat | `store_region_history` | 2 baris; 7.705 baris penjualan valid BGR-01 sebelum 2025-07-01 | 1.818.909.900 | Data / Bisnis | **SCD2 `dim_store`** dengan `COALESCE(riwayat, stores.region)`; di fakta tersimpan `region_target_basis` (peta awal tahun, dasar achievement), `region_asof`, dan `region_current`. **Direvisi di Task 5:** achievement memakai `region_target_basis`, bukan region saat transaksi | Target FY2025 tidak disesuaikan saat BGR-01 pindah (target Jawa Barat 341 -> 347 juta pada Jun -> Jul 2025, baru turun Jan 2026). Region saat transaksi menciptakan lonjakan palsu (Jawa Barat 98,1% -> 73,4%, Jabodetabek 94,9% -> 109,7%) dan menyembunyikan bahwa Jawa Barat FY2025 sebenarnya 100,8%. Inner join menjatuhkan 17 toko | B: T14 satu region per toko per tanggal; T53 region dasar target |
| DQ-16 | Target Excel: header baris 3, bulan melebar, label region tidak baku (`Jabar`, `Jatim`, `Sumatra`, `Jateng-DIY`, `Bali Nusra`, `JABODETABEK`) | `sales_targets_2025_2026.xlsx` | 12 baris region (2 sheet) | 40.413.000.000 (total target Store) | Data | **Unpivot** ke `fact_target(bulan, channel, region)` dan petakan label ke nama resmi | Join target ke aktual gagal tanpa pemetaan; achievement Store menjadi kosong | B: setiap (bulan, scope) punya target (2025–H1 2026) |
| DQ-17 | Baris penjualan sebelum `launch_date` produk | `products` / `launch_date` | 126 | 27.821.400 | Observasi | **Tidak ada tindakan tambahan**: seluruhnya sudah dikeluarkan lewat DQ-06b | Ke-126 baris adalah baris asli yang kemudian di-void kasir, jadi penjualan valid sebelum launch = 0. Void pada produk yang belum rilis konsisten dengan koreksi kasir | B: penjualan valid pra-launch = 0 |

## 4. Customers dan retur

| ID | Isu | File / kolom | Baris | Rp terdampak | Jenis | Keputusan | Alasan | Uji |
| --- | --- | --- | ---: | ---: | --- | --- | --- | --- |
| DQ-18 | `birth_date` sentinel `1900-01-01` | `customers` / `birth_date` (PII) | 418 member | – | Data | `birth_date` **tidak dibawa** ke model; turunan `age_band` = `Tidak diketahui` untuk sentinel | Kolom PII; sentinel merusak perhitungan usia | B: tidak ada PII di `dw` |
| DQ-19 | Email ganda antar member | `customers` / `email` (PII) | 491 grup = 982 member | 1.233.559.600 (net sales member tersebut) | Data | **Pertahankan** `customer_id` terpisah, tidak digabung | Tidak ada bukti bahwa dua ID adalah satu orang (email dapat dipakai bersama). Risiko: Repeat Rate bisa terhitung rendah. Dicatat sebagai keterbatasan di memo evaluasi | W |
| DQ-20 | Member tanpa transaksi | `customers` | 2.753 | – | Observasi | **Pertahankan** di `dim_customer`; Active Members dihitung dari transaksi | Wajar: member terdaftar belum bertransaksi | – |
| DQ-21 | Retur yatim: `original_trx_id` tidak ditemukan di POS maupun online | `returns` / `original_trx_id` | 1 | 178.900 | Data | **Quarantine**; tidak masuk `fact_returns` | Tidak bisa dikaitkan ke kategori, produk, atau transaksi asal | W: retur yatim |
| DQ-22 | Alasan retur ganda arti: "Barang cacat" (2.938) dan "Barang cacat / tidak berfungsi" (602) | `returns` / `return_reason` | 602 | 334.698.500 | Data | **Koreksi:** gabung ke "Barang cacat" | Dua label untuk alasan yang sama memecah distribusi alasan retur. **Asumsi**, dapat dikonfirmasi ke Customer Service | – |

## 5. Sinkronisasi POS

| ID | Isu | File / kolom | Toko-hari | Rp terdampak | Jenis | Keputusan | Alasan | Uji |
| --- | --- | --- | ---: | ---: | --- | --- | --- | --- |
| DQ-23 | Sync FAILED: BDG-02, 3–9 Nov 2025; tidak ada baris POS pada hari tersebut | `pos_sync_log` / `sync_status` | 7 | ≈ 20.789.288 (**estimasi**) | **Data** | **Tandai**, tidak diimputasi: `v_data_completeness` menandai toko-hari ini, dan dashboard menampilkan penanda data tidak lengkap | Penjualan hilang, bukan nol. Estimasi = 7 hari x rata-rata harian BDG-02 empat minggu sebelum dan sesudah (penjualan valid, tanpa B2B, hari tanpa transaksi dihitung 0); hanya untuk anotasi, tidak masuk angka resmi | W: FAILED menutupi penjualan |
| DQ-24 | STORE_CLOSED: SBY-01, 4 Agu – 21 Sep 2025 | idem | 49 | ≈ 300.412.656 (**estimasi indikatif**) | **Bisnis** | **Pertahankan** tanpa koreksi; target tidak disesuaikan; achievement SBY-01 dan Jawa Timur pada Agu–Sep 2025 diberi anotasi | Renovasi total (`store_events`), tidak ada penjualan sah. Estimasi = 49 hari x rata-rata harian delapan minggu sebelum dan sesudah (penjualan valid, tanpa B2B; belum memperhitungkan musiman) | W |

## 6. Rekap

| Jenis | Isu |
| --- | --- |
| Masalah data (dikoreksi / dikarantina / ditandai) | DQ-01, 02, 03, 04, 05, 06c, 08, 09, 10, 12, 13, 14, 15, 16, 18, 19, 21, 22, 23 |
| Kejadian bisnis | DQ-06a, 06b (void), DQ-07 (B2B bulk), DQ-11 (order batal), DQ-24 (renovasi SBY-01) |
| Observasi tanpa koreksi | DQ-17, 20 |

Observasi lain yang bukan isu: harga transaksi 94,8%–100% dari harga master (harga berubah); retur parsial
(refund 70%–100% harga); 54 toko-hari SUCCESS tanpa baris POS; kenaikan HPP 250 SKU (ditangani lewat SCD,
bukan dikoreksi).

## 7. Keputusan yang menunggu konfirmasi

| Keputusan | Asumsi saat ini | Siapa yang dapat mengonfirmasi |
| --- | --- | --- |
| `TRN-99` = toko pelatihan/uji, dikeluarkan (DQ-02) | Dikeluarkan; 0,12% nilai POS | Head of Store Operations |
| Transaksi B2B dipertahankan di Net Sales (DQ-07) | Dipertahankan dan ditandai | Direktur Komersial / Finance Controller |
| "Barang cacat / tidak berfungsi" = "Barang cacat" (DQ-22) | Digabung | Customer Service |
| Member berbeda dengan email sama dianggap orang berbeda (DQ-19) | Tidak digabung | CRM |

Dampak perubahan asumsi ditunjukkan di laporan (Task 5) bila material.
