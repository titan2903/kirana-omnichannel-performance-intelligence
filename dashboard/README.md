# Dashboard Metabase KIRANA

Dashboard dibangun **dari kode**: tiap kartu adalah satu file SQL di `questions/`, tata letak dan filter ada di `layout.json`, dan
`provision.py` membuat semuanya lewat API Metabase. Semua kartu hanya membaca schema `metrics` (semantic layer); tidak ada rumus KPI
di Metabase dan tidak ada kolom PII.

| Berkas | Isi |
| --- | --- |
| `questions/*.sql` | 39 kartu. Header `-- ...` memuat nama, tab, posisi, bentuk, filter, dan pengaturan visual; sisanya SQL asli kartu |
| `layout.json` | Dua dashboard (utama 5 tab, Detail Toko), parameter filter, teks, dan kartu bersama |
| `provision.py` | Membuat kartu dan dashboard; `--verify` menguji semua kartu dan tiap filter |
| `export.py` | PNG per tab, tangkapan layar filter dan drill-through, dan satu PDF |
| `wireframe/` | Wireframe beranotasi (`wireframe.drawio`, PNG, `wireframe.md`) dihasilkan dari sumber yang sama |
| `export/` | Hasil ekspor (di-ignore git, dibuat ulang oleh `export.py`; lihat catatan di bawah) |

## Struktur dashboard

**KIRANA Omnichannel Performance Intelligence** (filter: Periode, Channel, Region, Kategori)

1. **Executive Overview**: Net Sales, Achievement (gauge dengan segmen Hijau/Kuning/Merah), GM, CM, Transaksi, AOV; tabel pencapaian dan margin per channel; tren vs target.
2. **Channel, Region & Store**: tabel achievement per region (klik region mengisi filter Region), tabel kinerja 18 toko (klik toko membuka Detail Toko), kontribusi channel.
3. **Margin & Promosi**: margin per kategori, jembatan Net Sales ke CM, CM dan rasio diskon bulanan, efektivitas promo per jenis dan per kode.
4. **Retur & Customer**: Return Rate, Cancellation dan Void Rate, retur per channel/kategori/alasan, Active Members, Repeat Rate.
5. **Storyline**: kerangka; diisi pada Task 5.

**KIRANA Detail Toko** (filter: Periode, Toko): ringkasan, tren vs target alokasi, kategori, kelengkapan data.

Fitur wajib: filter dashboard; click behavior (crossfilter region, link toko -> Detail Toko); warna status konsisten (palet status skill
`dataviz`: `#0ca30c` / `#fab219` / `#d03b3b`, selalu disertai teks Hijau/Kuning/Merah) dari satu tabel `metrics.ref_status_threshold`;
indikator kesegaran data dan status sinkronisasi POS di bagian atas tiap tab; penanda data tidak lengkap (sync gagal) dan toko tutup (renovasi).
Warna channel tetap di semua grafik (Store biru, Marketplace oranye, Mobile App aqua, Website kuning).

**Filter yang tidak berlaku sengaja ditandai di catatan tiap tab:** Kategori tidak berlaku pada Achievement/Transaksi (target tidak per
kategori; satu struk memuat banyak kategori); kartu promo hanya menerima Periode; kartu member tidak menerima Region/Kategori.

## Menjalankan

Prasyarat: `kirana.duckdb` sudah dibangun (`bash scripts/build.sh`), Metabase berjalan (`docker compose up -d`) dengan koneksi DuckDB
read-only, dan akun admin Metabase. **Kredensial hanya lewat variabel lingkungan; jangan simpan di repo.**

```bash
export METABASE_URL=http://localhost:3000 METABASE_USER=<email-admin> METABASE_PASSWORD=<password>
python3 dashboard/provision.py --verify          # membuat dashboard, lalu menguji semua kartu dan filter

pip install playwright pillow requests           # Chrome sistem dipakai; tidak ada unduhan browser
python3 dashboard/export.py                      # PNG + dashboard/export/Dashboard_KIRANA.pdf
```

`provision.py` mengosongkan koleksi *KIRANA BI* lalu membuat ulang (idempoten); edit manual di koleksi itu akan tertimpa. Nama koneksi
dapat dipilih dengan `METABASE_DB_NAME`. Skrip tidak pernah mengaktifkan public sharing atau embedding.
Setelah rebuild database: `docker compose stop metabase`, `bash scripts/build.sh`, `docker compose start metabase`, lalu jalankan ulang `provision.py`.

## Verifikasi yang sudah dijalankan

- `--verify`: 0 galat; matriks baris tiap kartu tanpa filter dan dengan tiap filter (selisih = filter bekerja).
- Nilai headline (Net Sales, Achievement, GM, CM, Transaksi, AOV, Return Rate, Cancellation Rate) di bawah beberapa kombinasi filter sama
  persis dengan query langsung ke DuckDB dan dengan `reports/number_registry.md`.
- Pengujian dilakukan pada Metabase v0.63.17 (image `metabase-duckdb:0.63.17-duckdb1.5.6.0`).

## Catatan ekspor

Berkas di `export/` dihasilkan dari instance Metabase sementara yang membaca `kirana.duckdb` yang sama (dashboard identik). Jalankan
`export.py` pada Metabase Anda sendiri sebelum pengumpulan, lalu ganti nama PDF menjadi `UAS_BI_<NIM>_<NamaLengkap>_Dashboard.pdf`.
Halaman Storyline masih kerangka sampai Task 5 selesai; ekspor ulang sesudahnya.

## Asumsi dan keterbatasan

- Ambang status (>=100% Hijau, 90 s.d. <100% Kuning, <90% Merah) adalah asumsi analis; target toko adalah alokasi (bukan target resmi FP&A).
- PDF dihasilkan dari tangkapan layar Chrome headless (bukan fitur *Export as PDF* Metabase) agar dapat memuat keadaan filter dan hasil klik.
- Perubahan nama kartu/kolom di `questions/*.sql` memerlukan `provision.py` dijalankan ulang.
