# C1. Memo Evaluasi Solusi BI

**Kepada:** Direktur Komersial KIRANA · **Dari:** BI Analyst · **Perihal:** Apakah solusi ini cukup untuk keputusan H2 2026, dan apa yang perlu dikembangkan.
Semua angka sama dengan Bagian B (insight brief) dan registri angka `reports/insights/insight_registry.md`.

## 1. Apakah dashboard menjawab dua keputusan?

**Ya untuk arah keputusan, belum untuk besaran pasti.** Dashboard menunjukkan tindakan mana yang menaikkan atau menurunkan margin dan toko mana yang layak diprioritaskan, tetapi dua besaran (respons penjualan terhadap diskon dan target resmi per toko) tidak dapat diukur dari data yang ada.

| Pertanyaan keputusan | Tab dan kartu yang menjawab | Status |
| --- | --- | --- |
| 1. Promo mana yang menambah margin dan mana yang hanya membeli revenue? | Tab 3: `promo_incremental_gm_bar`, `promo_detail`, `margin_bridge_channel`. Hasil: App Payday positif di 27 dari 27 kode, Mega Sale 0 dari 8, Clearance 0 dari 3 | Terjawab untuk arah; dampak Rp adalah replay H2 2025 |
| 1. Seberapa besar tekanan margin dan dari mana? | Tab 1 dan 3: margin kotor turun 3,1 pt (HPP per unit +5,9% vs harga neto +1,5%), contribution margin turun 4,2 pt | Terjawab |
| 1. Apakah anggaran menjadi batasan? | Tab 3, `promo_per_jenis` (kolom Pemakaian anggaran): diskon yang diberikan hanya 9,2% dari anggaran (Rp 1,94 miliar dari Rp 21,14 miliar) | Terjawab: mekanisme, bukan anggaran, yang menentukan |
| 2. Channel dan region mana di bawah target? | Tab 1 dan 2: `achievement_per_channel`, `ach_store_per_region` | Terjawab |
| 2. Toko mana masuk program perbaikan, dan mana yang hanya bermasalah di data? | Tab 2: `store_ranking` (dengan kolom kelengkapan data), drill-down region → toko → Detail Toko | Terjawab dengan asumsi alokasi target |
| 2. Mengapa MDN-01 turun? | Insight brief (insight 5; angka per kota dari `facts.sql`, belum ada kartu per kota): bukan kanibalisasi online (Medan online +45,2%, setara kota lain) | **Belum terjawab**: penyebab (trafik, harga kompetitor, jam buka) tidak ada di data |

## 2. Keterbatasan dan asumsi

1. **Tidak ada target per toko.** Target toko adalah *alokasi* target region menurut pangsa penjualan tahun lalu. Ambang status (Hijau ≥100%, Kuning 90 s.d. <100%, Merah <90%) adalah usulan analis. Keduanya diberi label asumsi di dashboard. Pangsa memakai bulan yang sama tahun lalu, sehingga target alokasi Agu–Sep 2026 di Jawa Timur akan terdistorsi oleh penutupan SBY-01 (Agu–Sep 2025); H1 2026 tidak terpengaruh.
2. **Target tidak mengikuti perpindahan region.** Target FY2025 tidak disesuaikan saat BGR-01 pindah ke Jabodetabek (1 Jul 2025). Achievement memakai region awal tahun (`region_target_basis`). Pada versi awal saya memakai region saat transaksi dan Jawa Barat tampak anjlok dari 98,1% ke 73,4%; itu artefak ukur dan sudah dikoreksi, dijaga uji T53, dan dijelaskan di A4 bagian 5.
3. **Definisi.** Net Sales = gross − diskon, tanpa pajak dan sebelum retur. Retur dilaporkan terpisah (Return Rate = refund / Net Sales). Pembelian B2B bulk (14 baris, Rp 500 juta) dipertahankan dan ditandai.
4. **Baseline promo.** Promo Lift memakai jendela ±1 sampai 4 minggu tanpa hari yang tercakup promo lain. Pengaruh musim yang tidak tampak dari tanggal belum dikendalikan; Ramadan dan Clearance diuji konsisten antar tahun.
5. **Void, cancelled, TRN-99.** Void kasir dan pasangannya, serta order CANCELLED, dikeluarkan dari Net Sales tetapi dilaporkan (cancellation dan void rate). `TRN-99` (324 baris mentah atau 320 setelah duplikat dihapus; Rp 76,4 juta, 0,12% nilai POS, sesuai rekonsiliasi A5) dikarantina karena tidak ada di master toko, sync log, maupun target.
6. **Hari sync FAILED.** BDG-02 gagal 7 hari (3–9 Nov 2025) dan tidak diimputasi; estimasi hilang Rp 20,8 juta hanya indikatif. Penutupan SBY-01 (49 hari) adalah kejadian bisnis, bukan masalah data.
7. **Biaya di luar data.** Anggaran promo hanya `budget_idr`; biaya iklan dan biaya operasional toko tidak ada, sehingga contribution margin hanya dikurangi biaya channel dan bukan laba toko.
8. **Teknis.** Driver DuckDB dibuka read-only dan DuckDB hanya punya satu penulis; Metabase harus dihentikan saat rebuild. Pembatasan akses per region memakai view `acc_<region>` dan izin koleksi Metabase (`dashboard/access.py`), bukan row-level security Metabase (fitur berbayar).

## 3. Yang perlu dikembangkan

| Pengembangan | Alasan | Manfaat |
| --- | --- | --- |
| Refresh terjadwal otomatis (lihat C2) | Rebuild kini manual (`scripts/build.sh`) | Dashboard tidak basi; jam sync POS 01:00–01:49 sudah diketahui |
| Target resmi per toko dari FP&A | Menghilangkan asumsi alokasi | Status toko menjadi keputusan, bukan perkiraan |
| Biaya operasional toko dan biaya marketing di luar diskon | Contribution margin belum mencakup biaya ini | Profitabilitas toko dan ROI promo yang sebenarnya |
| Uji terkontrol (toko atau kota kontrol, holdout) pada promo | Lift saat ini bersifat observasional | Dampak dan elastisitas yang dapat dipertanggungjawabkan |
| Alat lineage (mis. dbt docs) | Lineage kini manual (C2) | Perubahan model terlacak otomatis |

## 4. Apakah machine learning diperlukan?

**Tidak untuk dua keputusan ini.** Alasannya:

- **Perbedaan hasilnya besar dan jelas dari analisis deskriptif.** Promo dengan margin negatif (Mega Sale 0 dari 8 kode positif) dan promo positif (App Payday 27 dari 27) dapat dipisahkan tanpa model. Hal yang sama berlaku untuk MDN-01 (79,3% dan 83,5%) terhadap toko lain.
- **Keputusannya sekali (H2 2026) dengan data 30 bulan.** Forecast permintaan tidak mengubah pilihan promo atau toko.
- **Tidak ada eksperimen atau kontrol.** Model uplift atau elastisitas dari data observasional akan menebak sebab-akibat dan menyamarkan ketidakpastiannya; saya memilih menyatakannya sebagai asumsi.

ML menjadi layak bila: (a) promo dijalankan dengan kelompok kontrol sehingga uplift dapat dimodelkan, atau (b) keputusan stok dan penjadwalan tenaga kerja per toko berulang tiap minggu sehingga forecast permintaan per SKU dan toko menghemat biaya. Keduanya belum ada saat ini.

## 5. Penilaian akhir

Solusi cukup untuk memutuskan **arah** realokasi promo dan **daftar pantau** toko pada Juli 2026. Sebelum angka dampak dijadikan komitmen anggaran, minta tiga hal: konfirmasi Store Operations atas renovasi SBY-01 dan log sync BDG-02, target toko resmi dari FP&A, dan satu uji promo terkontrol.
