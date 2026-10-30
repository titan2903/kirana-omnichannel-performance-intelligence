# A5. Uji Kualitas Data dan Rekonsiliasi

Dihasilkan oleh `sql/04_reconciliation.sql` dan `sql/06_tests.sql`; tabel hasil ada di `kirana.duckdb`
(`dq.reconciliation`, `dq.net_sales_bridge`, `dq.test_results`, `dq.test_results_demo`).

```bash
bash scripts/build.sh                                          # bangun ke file sementara; kirana.duckdb diganti HANYA bila semua uji BLOCKING lolos
bash scripts/mutation_test.sh                                  # 35 cacat disuntik ke salinan (data, staging, dan semantic layer); semua harus terdeteksi
duckdb -readonly kirana.duckdb -markdown -c "SELECT * FROM dq.test_results ORDER BY test_id"
bash .claude/skills/kirana-pipeline/scripts/idempotency_check.sh   # IDEMPOTENT: 62 objek identik di dua run
```

## 1. Hasil uji produksi

**43 uji: 29 BLOCKING (semua lolos), 14 WARNING (11 lolos, 3 temuan yang sudah diketahui).**

*BLOCKING = bila diabaikan, angka akan salah, sehingga build berhenti. WARNING = angka tetap valid, tetapi ada kondisi sumber yang harus dicatat; baris ditandai atau dikarantina, bukan dibuang.*

| ID | Uji | Severity | Gagal | Status | Alasan |
| --- | --- | --- | ---: | --- | --- |
| T01 | Grain `fact_sales` unik (source, txn_id, line_no, produk) | BLOCKING | 0 | PASS | Duplikat menggandakan revenue |
| T02 | Tidak ada FK yatim (tanggal, produk, toko, channel, pelanggan, promo) | BLOCKING | 0 | PASS | Baris yatim hilang dari agregat |
| T03 | Channel, toko, region hanya bernilai resmi | BLOCKING | 0 | PASS | Memecah agregat (DQ-01, 08) |
| T04 | Tiap baris punya tepat satu HPP as-of dan sama dengan nilai di fakta | BLOCKING | 0 | PASS | COGS dan GM salah (SCD HPP) |
| T05 | Tiap baris punya tarif biaya channel as-of | BLOCKING | 0 | PASS | Contribution margin menyimpang |
| T10 | Rekonsiliasi raw -> fakta: selisih baris dan Rp = 0 | BLOCKING | 0 | PASS | Data hilang tanpa jejak |
| T11 | Jembatan Net Sales menutup | BLOCKING | 0 | PASS | Net Sales harus dapat ditelusuri |
| T12 | Tidak ada kolom PII langsung di stg/dw/dq/metrics/acc_* | BLOCKING | 0 | PASS | PII tidak boleh ke dashboard |
| T13 | Kontrol sync log: `SUM(rows_uploaded)` = baris POS valid tanpa B2B | BLOCKING | 0 | PASS | Kontrol independen dari IT: membuktikan dedup dan void benar |
| T14 | `dim_store` SCD2: satu region per toko per tanggal, tanpa tumpang tindih | BLOCKING | 0 | PASS | Region salah memindahkan penjualan antar target (DQ-15) |
| T15 | Kunci alami dimensi unik | BLOCKING | 0 | PASS | Kunci ganda menggandakan fakta (DQ-13) |
| T16 | `fact_target` lengkap, unik, total sama dengan Excel | BLOCKING | 0 | PASS | Achievement kosong (DQ-16) |
| T17 | Retur terhubung ke penjualan asal dan konsisten | BLOCKING | 0 | PASS | Retur tanpa asal tak bisa dikelompokkan |
| T18 | Tidak ada baris ditolak karena format/label tak dikenal | BLOCKING | 0 | PASS | Label baru harus ditangani eksplisit |
| T19 | `return_id` unik di `fact_returns` | BLOCKING | 0 | PASS | Retur ganda menggandakan refund; rekonsiliasi tidak mendeteksinya karena raw dan fakta sama-sama memuat duplikat |
| T20 | Net sales ≥ 0 dan diskon ≤ gross | WARNING | 0 | PASS | Anomali nilai |
| T21 | Retur yatim | WARNING | **1** | FAIL (diketahui) | DQ-21: dikarantina, tidak masuk `fact_returns` |
| T22 | Hari sync POS FAILED | WARNING | **7** | FAIL (diketahui) | DQ-23: BDG-02, 3–9 Nov 2025; tidak diimputasi, ditandai data tidak lengkap |
| T23 | Tabrakan nomor struk di `fact_sales` | WARNING | 0 | PASS | DQ-05: 20 grup, semuanya pasangan void sehingga tidak ada di fakta |
| T24 | Void tanpa baris asli di toko master | WARNING | 0 | PASS | DQ-06c: satu-satunya kasus ada di `TRN-99` |
| T25 | Provinsi online tak terselesaikan | WARNING | 0 | PASS | DQ-12: seluruhnya terselesaikan dari kota |
| T26 | Promo dipakai di luar masa berlaku, channel, member-only, atau kategori | WARNING | 0 | PASS | Menyesatkan analisis promo |
| T27 | Penjualan valid sebelum `launch_date` | WARNING | 0 | PASS | DQ-17 |
| T28 | Target lengkap 18 bulan x 9 baris | WARNING | 0 | PASS | Achievement NULL |
| T29 | Transaksi B2B bulk di fakta | WARNING | **14** | FAIL (diketahui) | DQ-07: dipertahankan, ditandai `is_b2b_bulk` |
| T30 | Retur atas penjualan yang sudah dikeluarkan (void/batal) | WARNING | 0 | PASS | Dikarantina bila terjadi; tidak boleh mengurangi Net Sales |
| T31 | Refund = qty retur x nilai bersih per unit (toleransi Rp 100) | WARNING | 0 | PASS | Refund menyimpang membuat Return Rate (Rp) bias |
| T32 | `promo_type` dikenali | WARNING | 0 | PASS | Jenis promo baru jatuh ke `Lainnya` dan harus diperiksa |
| T40 | Kamus metrik memuat ≥ 8 KPI dan semua view yang dirujuk ada | BLOCKING | 0 | PASS | KPI tanpa view membuat angka dashboard tak dapat ditelusuri |
| T41 | `v_sales_monthly` = `fact_sales` (Net Sales, gross margin, COGS, qty, diskon, fee) | BLOCKING | 0 | PASS | Baris hilang/ganda saat agregasi ke grain view |
| T42 | `v_txn_monthly` = `fact_sales` (struk distinct, Net Sales) | BLOCKING | 0 | PASS | `transactions` hanya aditif bila satu struk jatuh di satu baris grain |
| T43 | `v_target_achievement`: aktual dan target menutup ke fakta | BLOCKING | 0 | PASS | Join target gagal membuat Achievement kosong/ganda |
| T44 | `v_store_target_alloc`: pangsa = 1 dan target toko = target region | BLOCKING | 0 | PASS | Achievement toko harus konsisten dengan region |
| T45 | `v_return_rate_monthly` dan `v_return_reason_monthly` = `fact_returns` | BLOCKING | 0 | PASS | Retur hilang membuat Return Rate terlalu rendah |
| T46 | Active Members tahunan = member unik langsung dari fakta | BLOCKING | 0 | PASS | Member unik tidak boleh dijumlahkan antar bulan |
| T47 | `v_margin_vs_target` = fakta; target GM dan tarif ada untuk 2025-01..2026-06 | BLOCKING | 0 | PASS | Status margin yang salah menyesatkan keputusan promo |
| T48 | `v_cancellation_void_monthly` = fakta (valid, batal, void) | BLOCKING | 0 | PASS | Rate harus berasal dari baris yang sama dengan rekonsiliasi |
| T49 | `v_promo_performance`: 73 promo dan total diskon = fakta | BLOCKING | 0 | PASS | Analisis efektivitas promo harus dapat dipercaya |
| T50 | Baseline Promo Lift memadai (tak ada TIDAK_CUKUP) | WARNING | 0 | PASS | Promo tanpa baseline tidak punya lift |
| T51 | `v_data_completeness` konsisten dengan sync log | BLOCKING | 0 | PASS | Penanda data tidak lengkap harus sama dengan sumber |
| T53 | `region_target_basis` = region toko pada awal tahun transaksi (dihitung ulang dari `dim_store`) | BLOCKING | 0 | PASS | Target FY2025 tidak disesuaikan saat BGR-01 pindah; region saat transaksi membuat achievement Jawa Barat dan Jabodetabek salah |
| T52 | `v_store_performance_monthly`: satu baris per bulan x toko; Net Sales dan target = `v_store_target_alloc` | BLOCKING | 0 | PASS | Join kelengkapan yang menggandakan baris merusak achievement toko di dashboard |
| T54 | Schema `acc_<region>`: tiap view hanya memuat regionnya; gabungan semua region (+ Lainnya untuk online) = view induk | BLOCKING | 0 | PASS | Pembatasan akses per region yang bocor atau menghilangkan baris (Task 6) |

Uji T13 menangkap bug nyata saat pengembangan: `is_b2b_bulk` bernilai NULL (bukan `false`) untuk baris tanpa promo,
sehingga 232 ribu baris POS tidak terhitung. Bug diperbaiki di staging dan uji kini lolos.

## 2. Uji yang sengaja gagal

Salinan `fact_sales` disuntik tiga cacat (1 baris duplikat persis, 1 baris dengan `product_key` 999999, 1 baris dengan
`net_sales` −5.000). Macro uji yang sama dijalankan pada salinan itu; model produksi tidak berubah dan tetap PASS.

| ID | Uji | Gagal | Status | Cacat yang disuntik |
| --- | --- | ---: | --- | --- |
| T01 | Grain unik | 1 | **FAIL** | 1 baris duplikat persis |
| T02 | FK yatim | 1 | **FAIL** | `product_key` 999999 |
| T03 | Domain channel/toko/region | 0 | PASS | – |
| T04 | HPP as-of | 1 | **FAIL** | akibat samping: tidak ada HPP untuk produk 999999 |
| T05 | Tarif biaya channel | 0 | PASS | – |
| T20 | Net sales ≥ 0 | 1 | **FAIL** | `net_sales` −5.000 |

Hasil disimpan di `dq.test_results_demo`. Ini membuktikan uji benar-benar mendeteksi cacat, bukan sekadar selalu lolos.

## 2b. Uji punya gigi: mutation test

`scripts/mutation_test.sh` menyuntik **satu cacat per percobaan** ke salinan `kirana.duckdb`, menjalankan ulang rekonsiliasi dan uji,
lalu memastikan uji yang tepat gagal. Hasil: **35 dari 35 cacat terdeteksi** (sekitar 1 menit; 20 cacat data/staging dan 15 cacat semantic layer, region, dan akses). Ini menutup celah bahwa hanya
T01–T05 yang pernah terbukti bisa gagal.

| Cacat yang disuntik | Uji yang gagal |
| --- | --- |
| Hapus 1 baris `fact_sales` | T10, T11, T13 |
| Baris sumber ditolak diam-diam (disposition diubah) | T10, T11, T18 |
| Hapus 1 baris target | T10, T16, T28 |
| Channel target NULL | T16 |
| `dim_store` tumpang tindih | T14 |
| Retur tanpa tanggal jual | T17 |
| Kolom PII `email` masuk `dim_customer` | T12 |
| Flag B2B salah pada 1 baris | T13 |
| HPP ganda untuk 1 produk | T04 |
| FK toko yatim | T02 |
| Region POS tidak resmi | T03 |
| Tarif channel hilang | T05 |
| Promo dipakai di luar `channel_scope` | T26 |
| SKU ganda di `dim_product` | T10, T15 |
| `launch_date` setelah tanggal jual | T27 |
| Retur duplikat di `fact_returns` | T10, T19 |
| Retur atas penjualan yang dikeluarkan | T10, T30 |
| Refund menyimpang dari nilai bersih | T10, T31 |
| Jenis promo tak dikenal | T32 |
| Net sales negatif di fakta | T10, T11, T20 |
| View penjualan kehilangan satu kategori | T41, T47, T48 |
| View transaksi kehilangan baris B2B | T42 |
| View achievement kehilangan satu channel | T43 |
| Alokasi target toko membengkak 10% | T44 |
| View alasan retur kehilangan satu alasan | T45 |
| Active Members tahunan salah hitung | T46 |
| Tarif channel kosong di view margin | T47 |
| Pembatalan terhitung dua kali | T48 |
| View promo kehilangan satu promo | T49 |
| Baseline promo tidak memadai | T50 |
| Penanda data tidak lengkap hilang | T51 |
| Kamus merujuk view yang tidak ada | T40 |
| Join kelengkapan menggandakan baris toko | T52 |
| Region dasar target salah pada 1 baris POS | T53 |
| View region memuat baris region lain | T54 |

## 3. Rekonsiliasi raw -> tabel bersih (baris)

Rumus: `raw = salinan duplikat + ditolak + dikeluarkan + fakta`. Sisi mentah dihitung langsung dari file, bukan dari staging.

| Sumber | Baris raw | Salinan duplikat | Ditolak | Dikeluarkan | Fakta | Selisih |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| POS | 264.420 | 1.577 | 320 | 4.134 | 258.389 | **0** |
| Online | 209.626 | 232 | 0 | 12.733 | 196.661 | **0** |
| Retur | 18.090 | 0 | 1 | 0 | 18.089 | **0** |
| Target (sel bulan) | 162 | 0 | 0 | 0 | 162 | **0** |
| Sync log POS | 16.036 | 0 | 0 | 0 | 16.036 | **0** |
| Dim produk | 606 | 0 | 6 | 0 | 600 | **0** |
| Dim pelanggan | 42.320 | 0 | 0 | 0 | 42.320 | **0** |
| Dim toko | 18 | 0 | 0 | 0 | 18 | **0** |
| Dim promo | 73 | 0 | 0 | 0 | 73 | **0** |

Keterangan: POS ditolak = `TRN-99` (DQ-02); dikeluarkan = 2.067 void + 2.067 baris asli yang di-void. Online dikeluarkan = order `CANCELLED`.

## 4. Rekonsiliasi nilai (Rupiah)

Basis: nilai bersih baris = qty x harga − diskon/voucher; retur = `refund_amount`; target = nilai target.

| Sumber | Raw | Salinan duplikat | Ditolak | Dikeluarkan | Fakta | Selisih |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| POS | 62.685.251.700 | 384.198.300 | 76.366.200 | −22.500 | 62.224.709.700 | **0** |
| Online | 47.493.993.000 | 48.915.600 | 0 | 2.882.492.400 | 44.562.585.000 | **0** |
| Retur | 3.702.006.200 | 0 | 178.900 | 0 | 3.701.827.300 | **0** |
| Target | 68.001.000.000 | 0 | 0 | 0 | 68.001.000.000 | **0** |

## 5. Jembatan ke Net Sales (POS + online)

| Langkah | Rupiah |
| --- | ---: |
| Nilai bersih mentah POS + online | 110.179.244.700 |
| dikurangi salinan duplikat persis (DQ-04, DQ-10) | −433.113.900 |
| dikurangi `TRN-99` (DQ-02) | −76.366.200 |
| dikurangi void dan baris asli yang di-void (DQ-06; hampir saling meniadakan) | +22.500 |
| dikurangi order online `CANCELLED` (DQ-11) | −2.882.492.400 |
| dikurangi penolakan lain | 0 |
| **= Net Sales hasil jembatan** | **106.787.294.700** |
| Net Sales di `dw.fact_sales` | 106.787.294.700 |
| Selisih | **0** |
| Rincian: gross sales (qty x harga) | 108.729.537.200 |
| Rincian: diskon POS + voucher online | −1.942.242.500 |

Net Sales per channel: Store Rp 62.224.709.700; Marketplace Rp 21.723.940.600; Mobile App Rp 15.253.543.400; Website Rp 7.585.101.000.

## 6. Kontrol independen dari sync log

`SUM(rows_uploaded)` (status SUCCESS) = **258.375** = jumlah baris POS valid di `fact_sales` tanpa 14 baris B2B. Uji T13
memastikan angka ini tetap sama pada setiap build. Transaksi B2B berada di luar sinkronisasi POS (A2 §5).

## 7. Idempotensi dan integritas sumber

- `idempotency_check.sh`: build dua kali ke database sementara, hash isi tiap tabel dan view dibandingkan -> **IDEMPOTENT: 62 objek identik**.
- `scripts/build.sh`: build ke `kirana.duckdb.building`, lalu menukar ke `kirana.duckdb` hanya bila gerbang BLOCKING lolos. Jalur gagal diuji: file yang ada tidak berubah (checksum sama) dan file sementara dihapus.
- 13 file `raw_data/` dibandingkan dengan ZIP asli (SHA-256): **13 identik, 0 berbeda**. Pipeline tidak pernah menulis ke `raw_data/`.
