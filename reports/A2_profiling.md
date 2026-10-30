# A2. Data Profiling

Profiling dilakukan langsung dari `raw_data/` dengan DuckDB, tanpa mengubah file. Semua angka dapat
diulang dengan:

```bash
duckdb -markdown < sql/profiling/01_file_inventory.sql   # inventaris, keunikan kunci, null per kolom
duckdb -markdown < sql/profiling/02_issue_impact.sql     # dampak per isu, 53 pengecekan, kontrol sync log
duckdb -markdown < sql/profiling/03_distributions.sql    # sebaran nilai dan statistik yang dikutip di bawah
```

Kode `DQ-xx` merujuk ke Data Quality Issue Log ([A3](A3_issue_log.md)).

## 1. Inventaris file

| File | Sumber | Baris | Kolom kunci | Kunci unik | Periode | Catatan |
| --- | --- | ---: | --- | ---: | --- | --- |
| `sales_pos_transactions.csv` | POS toko | 264.420 | `trx_id`+`line_no` | 262.823 | 2024-01-01 s.d. 2026-06-30 | 1.597 kunci ganda (DQ-04, DQ-05) |
| `sales_online_orders.csv` | Platform e-commerce | 209.626 | `order_no`+`line_no` | 209.394 | 2024-01-01 s.d. 2026-06-30 | 232 kunci ganda (DQ-10) |
| `products.csv` | Master produk | 606 | `sku` | 600 | launch 2021-07-17 s.d. 2025-11-24 | 6 SKU ganda (DQ-13) |
| `product_cost_history.csv` | Finance | 850 | `sku`+`valid_from` | 850 | 2023-01-01 s.d. 9999-12-31 | 600 SKU; bersih |
| `stores.csv` | Master toko | 18 | `store_code` | 18 | buka 2019-03-01 s.d. 2025-01-15 | Semua `Active` |
| `store_region_history.csv` | Store Operations | 2 | `store_code`+`valid_from` | 2 | 2021-08-01 s.d. 2025-07-01 | Hanya BGR-01 (DQ-15) |
| `store_events.csv` | Store Operations | 1 | `store_code`+`start_date` | 1 | 2025-08-04 s.d. 2025-09-21 | Renovasi SBY-01 |
| `customers.csv` | CRM | 42.320 | `customer_id` | 42.320 | join 2023-06-16 s.d. 2026-06-18 | Berisi PII |
| `returns.csv` | Customer Service | 18.090 | `return_id` | 18.090 | 2024-01-03 s.d. 2026-06-30 | Refund total Rp 3.702.006.200 |
| `promotions.csv` | Marketing | 73 | `promo_code` | 73 | 2024-01-05 s.d. 2026-06-28 | Diskon 10 s.d. 45% |
| `channel_fee_rates.csv` | Finance | 5 | `channel`+`valid_from` | 5 | 2024-01-01 s.d. 2099-12-31 | Marketplace 9,0% -> 11,5% mulai 2025-04-01 |
| `pos_sync_log.csv` | IT | 16.036 | `store_code`+`business_date` | 16.036 | 2024-01-01 s.d. 2026-06-30 | 15.980 SUCCESS, 49 STORE_CLOSED, 7 FAILED |
| `sales_targets_2025_2026.xlsx` | FP&A | 9 + 9 + 4 baris | `channel`+`region` | 9 / 9 / 4 | FY2025, H1 2026 | 3 sheet; header di baris 3 (DQ-16) |

Cakupan sync log: 16.036 toko-hari, sama dengan 18 toko x 912 hari dikurangi 380 hari DPS-01 sebelum
dibuka (2025-01-15).

## 2. Kolom dengan nilai kosong

| File | Kolom | Kosong | % | Penjelasan |
| --- | --- | ---: | ---: | --- |
| `sales_pos_transactions.csv` | `promo_code` | 238.872 | 90,34 | Wajar: tanpa promo |
| `sales_pos_transactions.csv` | `member_id` | 118.995 | 45,00 | Wajar: bukan member |
| `sales_online_orders.csv` | `voucher_code` | 180.705 | 86,20 | Wajar: tanpa voucher |
| `sales_online_orders.csv` | `ship_province` | 2.109 | 1,01 | **Masalah data** (DQ-12) |
| `returns.csv` | `store_code` | 12.289 | 67,93 | Wajar: seluruhnya retur online |
| `pos_sync_log.csv` | `synced_at` | 56 | 0,35 | Wajar: 49 STORE_CLOSED + 7 FAILED |

Kolom lain pada file di atas, serta `products`, `stores`, dan `customers`, tidak memiliki nilai kosong.

## 3. Profiling per sumber

### 3.1 POS (`sales_pos_transactions.csv`)

| Aspek | Hasil |
| --- | --- |
| Format tanggal | 100% `YYYY-MM-DD HH:MM:SS`, semua dalam periode |
| Harga dan diskon | `unit_price` > 0 pada semua baris; diskon tidak pernah melebihi nilai kotor |
| `qty` | 262.320 baris 1–3 unit, 2.086 baris negatif (void kasir), 14 baris 152–446 unit (B2B bulk, DQ-07) |
| `store_code` | 38 kode untuk 18 toko: 3.236 baris huruf kecil (DQ-01); `TRN-99` 324 baris tidak ada di master (DQ-02) |
| `sku` | 2.650 baris berspasi/huruf kecil (DQ-03); setelah normalisasi 600 SKU, semuanya ada di `products` |
| Member | 145.425 baris (55,0%) berisi `member_id`; semuanya ada di `customers` |
| Duplikat kunci | 1.597 grup: 1.577 salinan persis (DQ-04) dan 20 tabrakan nomor struk (DQ-05) |
| Void | 2.068 baris void (setelah dedup), 2.067 terpasang ke baris asli (DQ-06) |
| Promo | Semua `promo_code` ada di `promotions`, kecuali `B2B-CORP` (14 baris, DQ-07) |
| Transaksi distinct | 144.089 `trx_id` (sebelum pembersihan) |
| Metode bayar | QRIS 79.404; Debit 79.151; Cash 52.970; Credit Card 52.895 |

### 3.2 Online (`sales_online_orders.csv`)

| Aspek | Hasil |
| --- | --- |
| Format tanggal | 100% `DD/MM/YYYY HH:MM`, semua dalam periode; awalan `order_no` (24/25/26) sesuai tahun order |
| `item_price` | 173.447 baris angka polos; 36.179 baris berformat `Rp100.900` (DQ-09). Setelah parse, tidak ada harga gagal atau ≤ 0 |
| `sales_channel` | 12 label untuk 3 channel (DQ-08); semuanya terpetakan, tidak ada order yang terpecah ke dua channel |
| `qty` | 157.039 baris 1 unit, 52.587 baris 2 unit; tidak ada ≤ 0 |
| Status | 196.881 COMPLETED, 12.745 CANCELLED (6,08% baris) (DQ-11) |
| Voucher | Semua kode ada di `promotions`; voucher tidak pernah melebihi nilai kotor; kode dan nilai selalu berpasangan |
| Customer | Semua `customer_id` ada di `customers` dan berformat `Mxxxxxx`; tidak ada order tanpa customer |
| `ship_province` | 13 provinsi + 2.109 kosong (DQ-12). Sulawesi Selatan dan Kalimantan Timur berada di luar enam region -> `Lainnya` |
| Duplikat kunci | 232 grup, semuanya salinan persis (DQ-10), tidak ada konflik nilai/status |
| Order distinct | 140.573 `order_no` (sebelum pembersihan) |
| Metode bayar | E-Wallet 73.445; Virtual Account 63.194; COD 26.972; Credit Card 25.138; Paylater 20.877 |

Harga transaksi POS dan online berada pada 94,8%–100% dari `current_list_price` (rata-rata 98,8% POS,
99,0% online). Itu menunjukkan harga jual berubah dari waktu ke waktu, bukan galat; analisis memakai
harga transaksi, bukan harga master.

### 3.3 Master produk, HPP, toko

| Aspek | Hasil |
| --- | --- |
| `products` | 606 baris, 600 SKU: 6 SKU ganda dengan varian nama `(old)` (DQ-13). Kategori punya 9 SKU berlabel `Home Décor` dan 5 SKU `kitchen & dining` (DQ-14). Harga dan HPP > 0, HPP selalu di bawah harga |
| `product_cost_history` | 850 baris untuk 600 SKU. Tanpa overlap, tanpa celah, `valid_from` ≤ `valid_to`, HPP aktif sama dengan `products.current_unit_cost`. 350 SKU satu periode; 250 SKU dua periode, semuanya naik (rata-rata +7,4%): 60 SKU berubah 2025-07-01 (rata-rata +18%) dan 190 SKU berubah 2026-01-01 (rata-rata +4%) |
| Penjualan sebelum `launch_date` | 126 baris, Rp 27,8 juta, seluruhnya baris asli yang kemudian di-void (DQ-17, sudah tercakup DQ-06b). Penjualan valid sebelum launch: 0 |
| `stores` | 18 toko, 6 region, tipe Flagship/Regular/Express; tidak ada penjualan sebelum `open_date` |
| `store_region_history` | Hanya BGR-01: Jawa Barat s.d. 2025-06-30, Jabodetabek mulai 2025-07-01 (DQ-15). Toko lain tidak punya riwayat |
| `channel_fee_rates` | Store 0,7%; Website dan Mobile App 2,2%; Marketplace 9,0% s.d. 2025-03-31 lalu 11,5% |

### 3.4 Customers (hanya agregat; tanpa nilai PII)

| Aspek | Hasil |
| --- | --- |
| Kunci | 42.320 `customer_id` unik, tidak ada kolom kosong |
| Tier | Silver 29.741; Gold 10.026; Platinum 2.553 |
| `join_channel` | Store 17.834; Marketplace 10.439; Mobile App 7.409; Website 6.638 |
| `birth_date` | 418 bernilai sentinel 1900-01-01 (DQ-18); selain itu rentang sampai 2006 |
| Email ganda | 491 grup berisi 982 member (DQ-19). Nomor telepon: 320 baris memakai nomor yang sudah muncul sebelumnya |
| Tanpa transaksi | 2.753 member tidak pernah bertransaksi (DQ-20) |
| Konsistensi waktu | Tidak ada transaksi POS sebelum `join_date` |

### 3.5 Retur (`returns.csv`)

| Aspek | Hasil |
| --- | --- |
| Volume | 18.090 retur, refund Rp 3.702.006.200; tanggal dalam periode; qty dan refund > 0 |
| Per channel | Marketplace 6.659; Store 5.801; Mobile App 3.987; Website 1.643 |
| Alasan | 8 label; "Barang cacat" (2.938) dan "Barang cacat / tidak berfungsi" (602) berhimpit (DQ-22) |
| Integritas | 1 retur yatim (DQ-21). Selain itu, untuk retur POS dan online: `sku` cocok dengan baris asal, total qty retur per item tidak melebihi qty terjual, channel dan toko retur sama dengan transaksi asal, tidak ada retur atas order CANCELLED, tidak ada retur sebelum transaksi |
| Refund | Sama dengan qty retur x nilai bersih per unit (setelah diskon/voucher), selisih paling besar Rp 100 karena pembulatan. Itu sebabnya refund 55%–100% dari harga sebelum diskon; bukan retur parsial |

### 3.6 Promo

73 promo dari 2024-01-05 sampai 2026-06-28: Mega Sale (8 kode), Ramadan Sale (3), Clearance Awal Tahun (3),
Harbolnas Website (2), serta Member Day dan App Payday Voucher bulanan. Cakupan channel: Store 33,
Mobile App 27, Marketplace 8, ALL 3, Website 2. Sebanyak 30 promo khusus member. Semua pemakaian berada
dalam masa berlaku, sesuai `channel_scope`, dan member-only tidak dipakai non-member. Pemakaian di luar
`category_scope` sebanyak 972 baris (696 POS, 276 online) sebelum label kategori dinormalisasi dan 0 sesudahnya
(DQ-14).

### 3.7 Sync log

| Status | Toko-hari | Toko | Temuan |
| --- | ---: | ---: | --- |
| SUCCESS | 15.980 | 18 | 54 hari `rows_uploaded` = 0 dan memang tidak ada baris POS pada hari itu (13 toko); dianggap hari tanpa transaksi, bukan data hilang |
| STORE_CLOSED | 49 | 1 | Semuanya SBY-01, 2025-08-04 s.d. 2025-09-21, sama dengan renovasi di `store_events` (DQ-24) |
| FAILED | 7 | 1 | Semuanya BDG-02, 2025-11-03 s.d. 2025-11-09; tidak ada baris POS pada hari tersebut (DQ-23) |

Tidak ada penjualan POS pada hari FAILED/STORE_CLOSED, dan semua hari penjualan tercatat di sync log.

### 3.8 Target (`sales_targets_2025_2026.xlsx`)

| Sheet | Isi | Total |
| --- | --- | ---: |
| Target Net Sales 2025 | Header baris 3; 9 baris (Marketplace, Mobile App, Website nasional + 6 region Store) x 12 bulan | Rp 44.181.000.000 |
| Target Net Sales H1 2026 | Header baris 3; 9 baris x 6 bulan | Rp 23.820.000.000 |
| Target GM | Store 46%; Website 45%; Mobile App 43%; Marketplace 42% (2025 dan H1 2026 sama) | |

Semua sel angka terisi. Label region target tidak sesuai nama resmi: `Bali Nusra`, `JABODETABEK`, `Jabar`,
`Jateng-DIY`, `Jatim`, `Sumatra` (DQ-16). `range` harus diberikan eksplisit saat `read_xlsx`; tanpa itu
DuckDB hanya menangkap baris judul.

## 4. Pengecekan yang lolos (53 pengecekan, 0 pelanggaran)

Hasil lengkap ada di keluaran `02_issue_impact.sql` bagian B.

| Kelompok | Pengecekan yang lolos |
| --- | --- |
| POS | Tanggal dalam periode; harga > 0; diskon ≤ nilai kotor; `member_id` ada di customers; SKU ada di products setelah normalisasi; prefix `trx_id` = `store_code`; promo ada di `promotions` (selain B2B-CORP); tidak ada penjualan sebelum `open_date`; tidak ada penjualan pada hari FAILED/STORE_CLOSED; semua hari penjualan ada di sync log |
| Online | Tanggal dalam periode; harga ter-parse dan > 0; qty > 0; label channel terpetakan semua; satu channel per order; `customer_id` dan SKU ada di master; voucher ≤ nilai kotor dan ada di `promotions`; kode dan nilai voucher berpasangan; tidak ada duplikat yang konflik |
| HPP | Tidak ada overlap, celah, SKU tanpa riwayat, HPP aktif berbeda dari master, atau HPP ≥ harga |
| Promo | Tanggal mulai ≤ selesai; budget > 0; pemakaian dalam masa berlaku, sesuai `channel_scope` dan `member_only`; sesuai `category_scope` setelah kategori dinormalisasi; kode terpakai selalu bernilai diskon > 0 (selain B2B-CORP) |
| Retur | `return_id` unik; qty dan refund > 0; `store_code` ada di master; SKU, channel, dan toko cocok dengan transaksi asal (POS dan online); qty retur kumulatif per item ≤ qty terjual; refund = qty retur x nilai bersih per unit; tidak ada retur atas order CANCELLED; tidak ada retur sebelum transaksi |
| Integritas teknis | Semua nilai numerik dan tanggal berhasil di-cast; `trx_id`, `order_no`, dan `original_trx_id` tidak memuat huruf kecil atau spasi; tidak ada penjualan valid sebelum `launch_date` |
| Sync log | `store_code` ada di master; tidak ada FAILED yang tetap punya penjualan |
| Customers | `customer_id` unik; tidak ada transaksi sebelum `join_date` |

## 5. Kontrol independen: `rows_uploaded` sync log vs baris POS bersih

Sync log memberi total kontrol yang tidak berasal dari file transaksi. Setelah (1) normalisasi kode toko
dan SKU, (2) dedup salinan persis, (3) membuang void beserta baris asal yang di-void (dipasangkan 1:1), dan
(4) membuang `TRN-99`:

| Ukuran | Nilai |
| --- | ---: |
| Jumlah `rows_uploaded` (status SUCCESS) | 258.375 |
| Baris POS bersih | 258.389 |
| dari itu, baris B2B (`B2B-CORP`) | 14 |
| **Baris POS bersih tanpa B2B** | **258.375** |
| Toko-hari yang cocok persis (dengan B2B ikut dihitung) | 15.967 dari 15.980 |

Setelah B2B dikeluarkan, jumlahnya sama persis dengan sync log. Ini mendukung tiga keputusan sekaligus:
dedup persis aman, void dan baris aslinya memang tidak terkirim, dan transaksi B2B berada di luar sinkronisasi
POS (13 toko-hari yang berbeda adalah hari terjadinya transaksi B2B). Pengecekan yang sama dijadikan uji
kualitas data di Task 2.

## 6. Ringkasan nilai sebelum pembersihan

| Sumber | Nilai bersih baris (qty x harga − diskon/voucher) |
| --- | ---: |
| POS, semua 264.420 baris (termasuk void, duplikat) | Rp 62.685.251.700 |
| Online, semua 209.626 baris (termasuk CANCELLED, duplikat) | Rp 47.493.993.000 |

Angka ini bukan Net Sales; hanya titik awal rekonsiliasi (Task 2). Net Sales didefinisikan di Task 3.
