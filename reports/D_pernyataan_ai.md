# Pernyataan Penggunaan AI

**Alat:** Claude Code (Anthropic), asisten AI berbasis terminal yang berjalan di mesin lokal dan memiliki akses ke folder proyek.

**Untuk apa AI dipakai**

| Bagian | Peran AI |
| --- | --- |
| Persiapan | Membaca panduan UAS dan paket data, lalu membantu menyusun aturan kerja dan daftar langkah per task |
| Task 1 sampai 3 | Membantu menulis dan men-debug SQL DuckDB (profiling, staging, star schema, uji kualitas, rekonsiliasi, view metrik) |
| Task 4 | Membantu menulis skrip pembuat dashboard Metabase (`dashboard/provision.py`, `export.py`) dan wireframe |
| Task 5 dan 6 | Membantu menyusun kueri fakta (`facts.sql`), template dan skrip pembuat brief, serta draf teks brief, memo evaluasi, lampiran tata kelola, dan skrip hak akses Metabase (`dashboard/access.py`) |
| Peninjauan | Meninjau pekerjaan sebelumnya dan menjalankan pemeriksaan (idempotensi, uji mutasi, pindai PII) |

**Cara keluaran AI dikendalikan**

- **Angka tidak diketik manual.** Setiap angka di brief dan storyline dihitung oleh `reports/insights/facts.sql` dari `kirana.duckdb` dan tercatat di `reports/insights/insight_registry.md`; kunci angka yang tidak ada membuat build gagal. Angka kamus dan pencapaian tercatat di Lampiran Number Registry.
- **Pemeriksaan otomatis.** 43 uji kualitas data (29 BLOCKING, semuanya lolos), rekonsiliasi dengan selisih 0, 35 cacat yang sengaja disuntik (semuanya terdeteksi), dan uji idempotensi (dua build menghasilkan 62 objek identik).
- **Kesalahan AI yang ditemukan dan dikoreksi secara terbuka.** Keputusan awal memakai region saat transaksi untuk achievement membuat Jawa Barat tampak anjlok dari 98,1% ke 73,4%. Ini artefak ukur karena target FY2025 tidak disesuaikan saat BGR-01 pindah region. Koreksi (`region_target_basis`), uji T53, dan dampaknya dijelaskan di Bagian A4 dan A3 (DQ-15).
- **Data pribadi.** Kolom PII `customers.csv` tidak dibawa ke model, dashboard, laporan, atau SQL (uji T12 memeriksanya); pemeriksaan akhir tidak menemukan nama, telepon, atau email member di berkas keluaran. Pekerjaan AI atas data pribadi dibatasi pada agregat dan kolom non-PII.
- **Batas.** Penilaian dan rekomendasi akhir (Bagian B dan C) bersandar pada asumsi yang dicantumkan secara eksplisit di brief dan memo; dampak Rupiah adalah estimasi indikatif dari replay data historis.
