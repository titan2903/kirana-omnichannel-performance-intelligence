# Pernyataan Penggunaan AI

**Alat:** Claude Code (Anthropic), asisten AI berbasis terminal yang berjalan di mesin lokal dan memiliki akses ke folder proyek.

**Pembagian peran**

| Peran | Dikerjakan oleh mahasiswa | Dikerjakan dengan bantuan AI |
| --- | --- | --- |
| Arah dan urutan kerja | Menetapkan urutan Task 1–6, meminta peninjauan ulang setelah tiap task sebelum lanjut, dan menentukan kapan sebuah task dianggap selesai | Menyusun daftar langkah per task dari panduan UAS dan paket data |
| Infrastruktur | Menyiapkan Docker dan Metabase, membuat akun admin, menghubungkan `kirana.duckdb` sebagai koneksi read-only, menjalankan provisioning dan pemasangan hak akses di instance sendiri | Menulis `compose.yaml` dan skrip pembuat dashboard serta hak akses (`dashboard/provision.py`, `dashboard/access.py`, `dashboard/export.py`) |
| Data, model, dan metrik | Meninjau hasil profiling, uji kualitas, dan rekonsiliasi; meminta pemeriksaan ulang Task 1 dan Task 2 sebelum melanjutkan | Menulis dan men-debug SQL DuckDB (profiling, staging, star schema, uji kualitas, rekonsiliasi, view metrik) |
| Insight dan laporan | Menentukan bentuk akhir laporan (LaTeX, satu berkas), struktur folder repo, tautan berkas ke GitHub, dan penamaan berkas pengumpulan | Menyusun kueri fakta (`reports/insights/facts.sql`), skrip pembuat brief, serta draf teks brief, memo evaluasi, dan lampiran tata kelola |
| Publikasi | Mengelola repositori Git (commit dan push ke GitHub) dan mengumpulkan berkas | Menyiapkan skrip paket pengumpulan |

**Contoh tinjauan dan keputusan mahasiswa atas keluaran AI**

- Meminta peninjauan ulang menyeluruh setelah Task 1, Task 2, dan di akhir pekerjaan sebelum melanjutkan, lalu menilai temuannya.
- Mempertanyakan keluaran yang janggal, misalnya mengapa berkas laporan di `dist/` berbeda dari hasil kompilasi LaTeX, dan meminta tanda penulisan (`->`) yang belum rapi diperbaiki.
- Menolak struktur yang diusulkan AI dan menetapkan sendiri: nama folder `laporan_akhir/` (bukan `latex/`), laporan sebagai satu berkas LaTeX, dan penamaan berkas sesuai panduan.
- Menentukan agar setiap penyebutan berkas di laporan dapat diklik menuju repositori GitHub.
- Menjalankan sendiri langkah yang menyentuh sistem miliknya (pemasangan hak akses Metabase, penghapusan skrip lama, commit dan push).

**Cara keluaran AI diperiksa**

- **Angka tidak diketik manual.** Setiap angka di brief dan storyline dihitung oleh `reports/insights/facts.sql` dari `kirana.duckdb` dan tercatat di `reports/insights/insight_registry.md`; kunci angka yang tidak ada membuat build gagal. Angka kamus dan pencapaian tercatat di Lampiran Number Registry.
- **Pemeriksaan otomatis.** 43 uji kualitas data (29 BLOCKING, semuanya lolos), rekonsiliasi dengan selisih 0, 35 cacat yang sengaja disuntik (semuanya terdeteksi), dan uji idempotensi (dua build menghasilkan 62 objek identik).
- **Angka dashboard dicocokkan.** Angka utama brief dicocokkan langsung dengan kartu Metabase pada filter periode yang sama.
- **Kesalahan AI yang ditemukan dan dikoreksi secara terbuka.** Keputusan awal memakai region saat transaksi untuk achievement membuat Jawa Barat tampak anjlok dari 98,1% ke 73,4%. Ini artefak ukur karena target FY2025 tidak disesuaikan saat BGR-01 pindah region. Koreksi (`region_target_basis`), uji T53, dan dampaknya dijelaskan di Bagian A4 dan A3 (DQ-15).
- **Data pribadi.** Kolom PII `customers.csv` tidak dibawa ke model, dashboard, laporan, atau SQL (uji T12 memeriksanya); pemeriksaan akhir tidak menemukan nama, telepon, atau email member di berkas keluaran.

**Tanggung jawab.** Mahasiswa bertanggung jawab atas seluruh isi laporan, termasuk bagian yang drafnya disusun dengan bantuan AI. Rekomendasi (Bagian B dan C) bersandar pada asumsi yang dicantumkan secara eksplisit; dampak Rupiah adalah estimasi indikatif dari replay data historis.
