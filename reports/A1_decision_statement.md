# A1. Decision Statement

## Pernyataan keputusan

> **Pada awal Juli 2026, Direktur Komersial KIRANA Home & Living memutuskan, untuk periode H2 2026:**
> **(1)** bagaimana anggaran promo direalokasikan antar-channel (Store, Website, Mobile App, Marketplace),
> antar-kategori produk, dan antar-mekanisme promo; dan
> **(2)** toko atau region mana yang masuk program perbaikan kinerja.
> Keputusan memakai data 1 Januari 2024 – 30 Juni 2026 dari satu sumber angka yang disepakati
> Commercial dan Finance.

| Unsur | Isi |
| --- | --- |
| **Keputusan 1** | Realokasi anggaran promo (channel, kategori, mekanisme: Ramadan, Clearance, Member Day, App Payday, Mega Sale, Harbolnas) |
| **Keputusan 2** | Pemilihan toko/region untuk program perbaikan kinerja H2 2026 |
| **Pengambil keputusan** | Direktur Komersial |
| **Waktu keputusan** | Awal Juli 2026 (rapat keputusan H2 2026); batas data 30 Juni 2026 |
| **Peran analis** | BI Analyst / Analytics Engineer, tim Data & Analytics |

## Pemangku kepentingan

| Pemangku kepentingan | Kepentingan terhadap keputusan | Yang dibutuhkan dari BI |
| --- | --- | --- |
| Direktur Komersial (utama) | Memutuskan keputusan 1 dan 2 | Satu angka yang dapat dipercaya, rekomendasi dengan dampak dan risiko |
| Head of Store Operations | Keputusan 2 (toko/region), kejadian operasional toko | Pembeda masalah bisnis (renovasi, tren) dan masalah data (sync gagal) |
| Head of E-Commerce | Keputusan 1 untuk Website, Mobile App, Marketplace | Efektivitas promo online, dampak komisi Marketplace, retur online |
| Finance Controller | Validasi angka sales, margin, HPP, biaya channel | Definisi metrik tertulis, rekonsiliasi dari raw ke angka laporan |

## Ukuran keputusan (draf, dikunci pada Task 3 dan 5)

- **Keputusan 1:** promo lift terhadap baseline, dampak ke gross margin dan contribution margin (setelah biaya channel), serta pemakaian anggaran terhadap `budget_idr` per promo.
- **Keputusan 2:** pencapaian terhadap target (region), tren dan kontribusi toko, dengan kriteria tegas yang memisahkan toko bermasalah karena bisnis dari toko yang datanya tidak lengkap.

## Pemetaan pertanyaan bisnis ke keputusan

| # | Pertanyaan bisnis | Keputusan | KPI utama | Tab dashboard |
| --- | --- | --- | --- | --- |
| 1 | Pencapaian net sales FY2025 dan H1 2026 terhadap target per channel, region, toko | 2 (dan 1) | Net Sales, Achievement vs Target % | 1 Executive Overview; 2 Channel, Region & Store |
| 2 | Tren, musiman, dan pergeseran kontribusi antar-channel | 1 | Net Sales, kontribusi channel % | 1 Executive Overview; 2 Channel, Region & Store |
| 3 | Kategori, channel, promo yang menekan gross margin dan contribution margin | 1 | Gross Margin %, Contribution Margin % | 3 Margin & Promotion |
| 4 | Efektivitas promo (Ramadan, Clearance, Member Day, App Payday, Mega Sale, Harbolnas) | 1 | Promo Lift, dampak margin promo | 3 Margin & Promotion |
| 5 | Toko berkinerja rendah dan penyebabnya (bisnis atau data) | 2 | Achievement %, tren toko, flag data tidak lengkap | 2 Channel, Region & Store |
| 6 | Tingkat dan alasan retur per kategori dan channel | 1 dan 2 | Return Rate, distribusi alasan | 4 Returns & Customers |
| 7 | Aktivitas dan repeat purchase member per channel | 1 | Active Members, Repeat Rate | 4 Returns & Customers |

## Asumsi dan batas ruang lingkup

- Target tersedia hanya untuk FY2025 dan H1 2026 (tidak ada target 2024). Target Store ditetapkan per region, target online per channel nasional; tidak ada target per toko.
- Nilai dalam Rupiah, tidak termasuk pajak.
- Biaya di luar `channel_fee_rates.csv` (biaya operasional toko, biaya marketing di luar `promotions.budget_idr`) tidak tersedia, sehingga contribution margin hanya dikurangi biaya channel.
- Seluruh angka berasal dari model di `kirana.duckdb`; tidak ada data eksternal.
