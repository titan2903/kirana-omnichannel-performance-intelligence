# Insight Brief: Realokasi Promo dan Program Perbaikan Toko H2 2026

<p class="meta"><b>Untuk:</b> Direktur Komersial &nbsp;|&nbsp; <b>Data:</b> 1 Jan 2024 s.d. {{data_through_ord|tgl}} &nbsp;|&nbsp; <b>Disusun oleh:</b> BI Analyst, Data &amp; Analytics &nbsp;|&nbsp; Semua angka berasal dari <code>kirana.duckdb</code> (lihat <code>insights/insight_registry.md</code>), Rupiah tanpa pajak.</p>

## Ringkasan eksekutif

Penjualan sudah memenuhi target secara agregat (FY2025 **{{ach_total_fy25|pct1}}**, H1 2026 **{{ach_total_h126|pct1}}**), tetapi kualitasnya turun: **margin kotor turun {{gm_drop_pt|pt1}}** (dari {{gm_fy24|pct1}} ke {{gm_h126|pct1}}) dan **contribution margin turun {{cm_drop_pt|pt1}}** (dari {{cm_fy24|pct1}} ke {{cm_h126|pct1}}). Pertumbuhan datang dari channel online yang berbiaya lebih tinggi, sementara Store tertahan di {{ach_st_h126|pct1}} dari target. Dua keputusan H2 2026 bergantung pada tiga hal berikut.

1. **Penurunan margin adalah masalah harga dan HPP, bukan diskon.** HPP per unit naik {{hpp_idx_h126|idx}}% sedangkan harga neto hanya {{price_idx_h126|idx}}%. Setiap 1% kenaikan harga neto bernilai kira-kira **{{rp_per_1pct_harga|rpj}}** margin per semester sebelum efek volume.
2. **Promo harus direalokasi.** Mega Sale (diskon {{mega_discount_pct|int}}%) menjual di bawah HPP dan menghasilkan contribution margin **{{p_cm_mega|rpj}}**; Clearance konsisten negatif. App Payday positif di **{{p_pos_ap|int}} dari {{p_n_ap|int}}** kode. Estimasi dampak H2 2026: **{{scn_promo_total_low_rp|srpj}} sampai {{scn_promo_total_high_rp|srpj}}** contribution margin.
3. **Program perbaikan toko sebaiknya sempit.** Hanya **MDN-01 (Medan)** yang konsisten di bawah target tanpa penjelasan kejadian atau data; **SBY-02, MLG-01, SOL-01** memburuk di H1 2026. SBY-01, BDG-02, DPS-01 dan region Jawa Barat tampak buruk karena renovasi, sync yang gagal, toko baru, dan kesalahan pengukuran region, bukan karena kinerja.

<table class="reco"><thead><tr><th>Keputusan</th><th>Rekomendasi</th><th>Estimasi dampak (H2 2026)</th></tr></thead><tbody>
<tr><td><b>1. Realokasi anggaran promo</b></td><td>Hentikan Mega Sale {{mega_discount_pct|int}}% (atau batasi diskon maks. {{mega_depth_breakeven_cm_pct|int}}%); hentikan Clearance; ubah Member Day; alihkan diskon ke App Payday; teruskan kenaikan HPP ke harga.</td><td>{{scn_promo_total_low_rp|srpj}} s.d. {{scn_promo_total_high_rp|srpj}} CM dari promo; harga: {{rp_per_1pct_harga|rpj}} per 1% kenaikan harga neto</td></tr>
<tr><td><b>2. Program perbaikan toko/region</b></td><td>Program intensif MDN-01; pemantauan 90 hari SBY-02, MLG-01, SOL-01; tidak ada program untuk SBY-01, BDG-02, DPS-01, maupun region Jawa Barat.</td><td>Batas atas {{s_prog4_cm_full_rp|rpj}} CM per semester; skenario 50%: {{s_prog4_cm_half_rp|rpj}}</td></tr>
</tbody></table>

## 1. Margin kotor turun {{gm_drop_pt|pt1}} karena HPP per unit naik {{hpp_idx_h126|idx}}% sementara harga neto hanya naik {{price_idx_h126|idx}}%

Pada {{gm_h126|pct1}} margin kotor H1 2026 jauh di bawah FY2024 ({{gm_fy24|pct1}}). Bila HPP per SKU dibekukan di nilai akhir 2024, margin H1 2026 justru **{{gm_cf_h126|pct1}}**, sehingga efek HPP ({{hpp_effect_pt|pt1}}) menjelaskan seluruh penurunan. Diskon bukan penyebab utamanya: rasio diskon terhadap gross sales naik hanya {{disc_rise_pt|pt2}} (dari {{disc_fy24|pct2}} ke {{disc_h126|pct2}}) dan bauran kategori nyaris tidak bergeser. Kenaikan HPP terjadi dua kali: **{{sku_hpp_jul25|int}} SKU** pada 1 Jul 2025 (rata-rata +{{hpp_naik_jul25_pct|n1}}%) dan **{{sku_hpp_jan26|int}} SKU** pada 1 Jan 2026 (rata-rata +{{hpp_naik_jan26_pct|n1}}%).

<div class="figs"><img src="insights/img/c1_margin.png" alt="HPP dan harga neto per unit, margin aktual dan kontrafaktual"></div>

**Artinya:** memulihkan margin FY2024 membutuhkan kenaikan harga neto sekitar **{{harga_perlu_naik_pct|n1}}%** (volume tetap), setara **{{rp_gap_gm_h126|rpj}}** per semester. Tiap kenaikan 1% harga neto menambah sekitar {{rp_per_1pct_harga|rpj}} per semester sebelum efek volume. Elastisitas harga tidak dapat diukur dari data ini. <span class="note"><b>Catatan data:</b> temuan ini hanya terlihat karena HPP dihitung per tanggal transaksi (SCD). Bila HPP terkini dipakai untuk seluruh histori, margin FY2024 tampak {{gm_hppterkini_fy24|pct1}} dan penurunannya nyaris hilang.</span>

## 2. Contribution margin turun {{cm_drop_pt|pt1}}: {{cm_effect_margin_pt|abs|pt1}} dari margin dalam channel dan {{cm_effect_mix_pt|abs|pt1}} dari pergeseran ke Marketplace

Marketplace naik dari {{share_mp_fy24|pct1}} ke {{share_mp_h126|pct1}} dari Net Sales, tetapi contribution margin-nya hanya {{cmch_mp_h126|pct1}} dibanding Store {{cmch_st_h126|pct1}}, karena komisi naik dari 9,0% ke 11,5% sejak 1 Apr 2025. Kenaikan komisi itu saja sudah menambah biaya **{{mp_fee_extra_total_rp|rpj}}** hingga Juni 2026 ({{mp_fee_extra_h126_rp|rpj}} pada H1 2026). Rasio biaya channel terhadap Net Sales naik {{fee_rise_pt|pt1}} (dari {{fee_fy24|pct1}} ke {{fee_h126|pct1}}).

<div class="figs"><img src="insights/img/c2_cm.png" alt="Dekomposisi contribution margin dan bauran channel"></div>

**Artinya:** setiap Rupiah penjualan yang berpindah dari Store ke Marketplace mengurangi sekitar {{cmch_st_h126|n1}} - {{cmch_mp_h126|n1}} = **{{cm_gap_st_mp|n1}} sen** contribution margin. Pertumbuhan online tetap bernilai, tetapi tidak boleh dibeli dengan diskon yang menghapus margin (lihat insight 4).

## 3. Target agregat tercapai hanya karena online: Marketplace {{ach_mp_h126|pct1}} dan Mobile App {{ach_ap_h126|pct1}} menutup Store ({{ach_st_h126|pct1}}) dan Website ({{ach_wb_h126|pct1}})

Pada FY2025 Net Sales {{ach_total_fy25|pct1}} dari target (selisih {{gap_total_fy25|srpj}}); pada H1 2026 {{ach_total_h126|pct1}} ({{gap_total_h126|srpj}}). Store kekurangan {{gap_st_fy25|rpj_abs}} (FY2025) dan {{gap_st_h126|rpj_abs}} (H1 2026); Website kekurangan {{gap_wb_fy25|rpj_abs}} dan {{gap_wb_h126|rpj_abs}}. Sebaliknya Marketplace dan Mobile App melampaui target masing-masing {{gap_mp_h126|rpj}} dan {{gap_ap_h126|rpj}} pada H1 2026, tumbuh {{yoy_mp|pct1}} dan {{yoy_ap|pct1}} secara tahunan, sementara Store hanya {{yoy_st|pct1}} dan **Website turun {{yoy_wb|abs|pct1}}**. Kelebihan di atas 120% pada dua channel online menunjukkan target online kemungkinan terlalu rendah.

<div class="figs"><img src="insights/img/c3_target.png" alt="Selisih Net Sales terhadap target per channel"></div>

**Website bukan kehilangan pelanggan, melainkan pelanggan yang berpindah.** Dari {{web_mig_total|int}} member yang aktif di Website pada FY2024, hanya {{web_mig_still|int}} ({{web_mig_still_pct|pct0}}) yang masih berbelanja di sana pada H1 2026; **{{web_mig_app|int}}** pindah ke Mobile App, {{web_mig_other|int}} ke Marketplace/Store, dan hanya {{web_mig_inactive|int}} yang berhenti total. Website hanya memiliki **{{promo_n_website|int}}** promo sepanjang periode (Harbolnas 1 hari) dibanding {{promo_n_app|int}} promo Mobile App. Implikasinya: jangan menambah anggaran promo Website untuk mengejar target, tetapi tinjau ulang target Website.

## 4. Mega Sale dan Clearance menggerus margin, App Payday menambahnya di {{p_pos_ap|int}} dari {{p_n_ap|int}} kode

Baseline promo adalah hari yang sama pada 1 s.d. 4 minggu sebelum dan sesudah jendela promo, tanpa hari yang tercakup promo lain; Net Sales sudah netto diskon sehingga margin tambahan sudah memuat biaya diskon. Hasilnya konsisten antar tahun (Ramadan +34, +31, +30%; Clearance -19, -40, -37%).

<div class="figs"><img src="insights/img/c4_promo.png" alt="Margin kotor tambahan per jenis promo dan jumlah kode positif"></div>

- **Mega Sale** (Marketplace, diskon {{mega_discount_pct|int}}%): Net Sales melonjak {{p_lift_mega|n0}}% tetapi **margin kotor saat promo rata-rata {{p_gmpct_promo_mega|pct1}}** (baseline {{p_gmpct_base_mega|pct1}}). Margin tambahan {{p_gm_mega|rpj}} dan contribution margin {{p_cm_mega|rpj}} setelah komisi; makin buruk pada 2025 ({{p_h225_cm_mega|rpj}} hanya pada H2 2025) karena HPP dan komisi naik. Diskon di atas **{{mega_depth_breakeven_cm_pct|n0}}%** sudah merugikan contribution margin sebelum memperhitungkan lonjakan penjualan.
- **Clearance:** lift Net Sales {{p_lift_clr|n1}}% dan margin tambahan {{p_gm_clr|rpj}}, negatif pada ketiga tahun; hanya berjalan pada Januari sehingga relevan untuk perencanaan H1 2027.
- **Member Day:** hanya {{p_pos_mbr|int}} dari {{p_n_mbr|int}} kode positif; margin tambahan {{p_gm_mbr|rpj}} dengan diskon {{p_disc_mbr|rpj}}.
- **App Payday:** {{p_pos_ap|int}} dari {{p_n_ap|int}} kode positif, margin tambahan {{p_gm_ap|rpj}} dan CM {{p_cm_ap|rpj}} untuk diskon {{p_disc_ap|rpj}}: sekitar **{{app_cm_per_disc_h225|n2}}** Rupiah CM per Rupiah diskon pada H2 2025. Ramadan juga positif ({{p_gm_rmd|rpj}}).
- **Anggaran:** diskon yang benar-benar diberikan hanya **{{p_util_total_pct|pct1}}** dari anggaran promo ({{p_disc_total|rpm}} dari {{p_budget_total|rpm}}), sehingga anggaran bukan batasan yang mengikat; mekanisme promolah yang menentukan hasil.

**Artinya:** menghentikan Mega Sale menghindari {{scn_promo_total_low_rp|rpj}} CM per semester (replay H2 2025) dengan melepas {{p_h225_net_mega|rpj}} Net Sales tambahan yang bermargin nol atau negatif. Mengalihkan setengah diskonnya ({{scn_realokasi_rp|rpj}}) ke App Payday pada separuh imbal hasil historis menambah sekitar {{scn_realokasi_gain_rp|rpj}}; skenario tinggi **{{scn_promo_total_high_rp|rpj}}** (kira-kira {{scn_promo_pt_cm|pt2}} CM).

## 5. Hanya MDN-01 yang konsisten di bawah target tanpa penjelasan lain; tiga toko lain memburuk, sedangkan SBY-01, BDG-02, dan Jawa Barat bukan masalah kinerja

Target toko adalah **alokasi** target region menurut pangsa penjualan tahun lalu (asumsi, bukan target resmi). Kriteria program: achievement di bawah 90% pada H1 2026 **dan** penjualan tahunan tidak tumbuh, tanpa kejadian operasional atau data hilang.

<div class="figs"><img src="insights/img/c5_toko.png" alt="Achievement toko FY2025 dan H1 2026"></div>

- **MDN-01 (Medan):** {{s_mdn01_ach_fy25|pct1}} (FY2025) dan {{s_mdn01_ach_h126|pct1}} (H1 2026), kekurangan {{s_mdn01_gap_fy25|rpj_abs}} dan {{s_mdn01_gap_h126|rpj_abs}}, penjualan turun {{s_mdn01_yoy|abs|pct1}} secara tahunan. Penjualan online ke Medan justru tumbuh {{online_yoy_medan|pct1}}, setara kota lain ({{online_yoy_palembang|pct1}} di Palembang, tempat toko PLM-01 tetap tumbuh {{s_plm01_yoy|pct1}}), sehingga kanibalisasi online saja tidak menjelaskannya.
- **SBY-02, MLG-01, SOL-01:** {{s_sby02_ach_h126|pct1}}, {{s_mlg01_ach_h126|pct1}}, {{s_sol01_ach_h126|pct1}} pada H1 2026 (naik dari ≥95% pada FY2025) dengan penjualan tahunan {{s_sby02_yoy|pct1}}, {{s_mlg01_yoy|pct1}}, {{s_sol01_yoy|pct1}}: pantau 90 hari. Keempat toko bersama-sama berselisih {{s_prog4_gap_h126|rpj_abs}} dari target H1 2026.
- **Region:** Sumatera di bawah target di kedua periode ({{ach_reg_sum_fy25|pct1}} dan {{ach_reg_sum_h126|pct1}}), terutama karena MDN-01 (PLM-01 sehat). **Jawa Barat tidak bermasalah** ({{ach_reg_jb_fy25|pct1}} pada FY2025, {{ach_reg_jb_h126|pct1}} pada H1 2026); lihat tabel Anomali di halaman 5.

## 6. Fashion online mengembalikan {{rr_fashion_online_pct|pct1}} penjualannya (Store {{rr_fashion_store_pct|pct1}}), dan {{fr_ukuran|pct0}} refund Fashion karena ukuran

Fashion hanya sebagian kecil penjualan tetapi menyumbang **{{fashion_refund_share_pct|pct1}}** dari seluruh refund ({{fashion_refund_rp|rpj}} dari {{total_refund_rp|rpj}}). Kategori non-Fashion di online hanya {{rr_other_online_pct|pct1}}. Alasan "Ukuran tidak sesuai" hanya muncul pada Fashion. Return Rate Marketplace ({{rr_mp_total_pct|pct1}}) dan Mobile App ({{rr_ap_total_pct|pct1}}) jauh di atas Store ({{rr_st_total_pct|pct1}}) terutama karena Fashion.

<div class="figs"><img src="insights/img/c6_retur.png" alt="Return rate Fashion dan alasan retur"></div>

**Artinya:** bila Return Rate Fashion online turun ke level Store, refund sekitar **{{fashion_excess_refund_year_rp|rpj}} per tahun** dapat dihindari. Panduan ukuran dan foto yang akurat lebih murah daripada promo tambahan untuk Fashion online.

## Rekomendasi dan estimasi dampak

<table class="reco"><thead><tr><th>Tindakan</th><th>Estimasi dampak (dan asumsi)</th><th>Risiko</th><th>Data yang dapat mengubah rekomendasi</th></tr></thead><tbody>
<tr class="grp"><td colspan="4"><b>Keputusan 1: realokasi anggaran promo antar-channel, kategori, dan mekanisme</b></td></tr>
<tr><td><b>1a.</b> Hentikan Mega Sale {{mega_discount_pct|int}}% di Marketplace, atau batasi diskon maks. {{mega_depth_breakeven_cm_pct|int}}% dan uji.</td><td>{{scn_promo_total_low_rp|srpj}} CM per semester (replay H2 2025: CM {{p_h225_cm_mega|rpj}}, diskon {{p_h225_disc_mega|rpj}}). Melepas {{p_h225_net_mega|rpj}} Net Sales tambahan.</td><td>Pangsa Marketplace di hari besar turun; lift pada diskon lebih dangkal belum teramati (hanya satu kedalaman).</td><td>Elastisitas pada diskon {{mega_depth_breakeven_cm_pct|int}}-30%; margin barang yang dijual (apakah stok lambat); nilai akuisisi pelanggan dari Mega Sale.</td></tr>
<tr><td><b>1b.</b> Hentikan Clearance Januari; rancang ulang pelepasan stok.</td><td>Menghindari {{p_gm_clr|rpj}} margin kotor per 3 tahun (sekitar {{p_gm_clr_year|rpj}} per tahun). Berlaku untuk H1 2027.</td><td>Stok lambat menumpuk jika tidak ada jalur lain.</td><td>Umur dan nilai stok Home Decor; musiman Januari (baseline sudah simetris, tetapi tidak mengendalikan musiman).</td></tr>
<tr><td><b>1c.</b> Ubah Member Day: batasi pada tier tinggi atau jadikan kuartalan.</td><td>Netral terhadap margin ({{p_gm_mbr|srpj}} historis); menghemat sekitar separuh dari {{p_disc_mbr|rpj}} diskon.</td><td>Retensi member Store turun.</td><td>Repeat Rate per tier; data CRM yang memisahkan perilaku member tier (tidak tersedia).</td></tr>
<tr><td><b>1d.</b> Alihkan 50% diskon Mega Sale ke App Payday.</td><td>+{{scn_realokasi_gain_rp|rpj}} CM (imbal hasil 50% dari historis {{app_cm_per_disc_h225|n2}}). Gabungan dengan 1a: {{scn_promo_total_high_rp|srpj}} (kira-kira {{scn_promo_pt_cm|pt2}} CM).</td><td>Imbal hasil menurun pada skala lebih besar; kanibalisasi pasca-payday tidak terukur.</td><td>Hasil uji frekuensi App Payday; biaya marketing di luar diskon (tidak ada di data).</td></tr>
<tr><td><b>1e.</b> Teruskan sebagian kenaikan HPP ke harga neto (di luar dua keputusan, tetapi dampak terbesar).</td><td>Pulihkan margin FY2024 butuh +{{harga_perlu_naik_pct|n1}}% harga ({{rp_gap_gm_h126|rpj}} per semester, volume tetap); tiap 1% = {{rp_per_1pct_harga|rpj}}.</td><td>Volume turun; reaksi kompetitor.</td><td>Elastisitas harga per kategori; harga kompetitor.</td></tr>
<tr class="grp"><td colspan="4"><b>Keputusan 2: toko atau region yang masuk program perbaikan</b></td></tr>
<tr><td><b>2a.</b> Program intensif <b>MDN-01</b> (diagnosis 30 hari: trafik, ketersediaan, kompetitor lokal).</td><td>Gap H1 2026 {{s_mdn01_gap_h126|rpj_abs}}; menutup separuh menambah sekitar {{s_mdn01_half_net_rp|rpj}} Net Sales per semester.</td><td>Alokasi target toko adalah asumsi; penyebab bisnis belum terbukti dari data.</td><td>Data trafik pengunjung, harga kompetitor, jam operasional Medan.</td></tr>
<tr><td><b>2b.</b> Pemantauan 90 hari <b>SBY-02, MLG-01, SOL-01</b> (intervensi hanya bila tetap di bawah 90%).</td><td>Empat toko bersama menutup gap {{s_prog4_gap_h126|rpj_abs}} per semester: batas atas {{s_prog4_cm_full_rp|rpj}} CM, skenario 50%: {{s_prog4_cm_half_rp|rpj}}.</td><td>Penurunan ringan bisa musiman atau kanibalisasi online ({{online_yoy_all|pct0}} di seluruh kota).</td><td>Penjualan H2 2026; atribusi online per kota toko.</td></tr>
<tr><td><b>2c.</b> Tidak ada program untuk <b>SBY-01, BDG-02, DPS-01</b> dan region <b>Jawa Barat</b>.</td><td>Penjelasan di tabel Anomali (halaman 5); SBY-01 pulih ke {{s_sby01_ach_h126|pct1}} setelah renovasi.</td><td>Menyembunyikan masalah nyata bila asumsi anomali salah.</td><td>Konfirmasi Store Operations atas renovasi; log sync lengkap BDG-02.</td></tr>
</tbody></table>

## Anomali: kejadian bisnis atau masalah data

<table class="anom"><thead><tr><th>Anomali</th><th>Jenis</th><th>Bukti</th><th>Perlakuan</th></tr></thead><tbody>
<tr><td>SBY-01 tutup 4 Agu - 21 Sep 2025</td><td class="bis">Bisnis</td><td>{{sby01_closed_days|int}} hari STORE_CLOSED di sync log dan catatan renovasi; Net Sales Agu {{sby01_net_aug25|rpj}} dan Sep {{sby01_net_sep25|rpj}} vs Jul {{sby01_net_jul25|rpj}} dan Okt {{sby01_net_oct25|rpj}}. Estimasi tertahan {{sby01_est_lost_rp|rpj}}.</td><td>Achievement FY2025 {{s_sby01_ach_fy25|pct1}} dijelaskan penutupan; H1 2026 {{s_sby01_ach_h126|pct1}} ({{s_sby01_ach_h126_xb2b|pct1}} tanpa B2B). Bukan masalah kinerja.</td></tr>
<tr><td>BDG-02 sync POS gagal 3-9 Nov 2025</td><td class="dat">Data</td><td>{{bdg02_failed_days|int}} hari FAILED tanpa baris POS; Net Sales Nov {{bdg02_net_nov25|rpj}}. Estimasi hilang {{bdg02_est_lost_rp|rpj}}.</td><td>Ditandai tidak lengkap, tidak diimputasi. Dampak kecil terhadap achievement.</td></tr>
<tr><td>BGR-01 pindah Jawa Barat ke Jabodetabek 1 Jul 2025</td><td class="bis">Bisnis (+ artefak pengukuran)</td><td>Target FY2025 tidak disesuaikan: target Jawa Barat {{tgt_jb_202506|rpj}} (Jun) dan {{tgt_jb_202507|rpj}} (Jul), baru turun {{tgt_jb_202601|rpj}} pada Jan 2026. Dengan region saat transaksi, achievement Jawa Barat anjlok {{reg_jb_h125_asof|pct1}} ke {{reg_jb_h225_asof|pct1}} dan Jabodetabek naik {{reg_jkt_h125_asof|pct1}} ke {{reg_jkt_h225_asof|pct1}} pada titik yang sama.</td><td>Dikoreksi: achievement memakai peta region awal tahun target (Jawa Barat {{reg_jb_h125_basis|pct1}} lalu {{reg_jb_h225_basis|pct1}}; Jabodetabek {{reg_jkt_h125_basis|pct1}} lalu {{reg_jkt_h225_basis|pct1}}). Rp {{bgr01_h225_rp|rpj_plain}} penjualan BGR-01 pada H2 2025.</td></tr>
<tr><td>Komisi Marketplace 9,0% menjadi 11,5% sejak 1 Apr 2025</td><td class="bis">Bisnis</td><td>Tarif di <code>channel_fee_rates.csv</code>; biaya tambahan {{mp_fee_extra_total_rp|rpj}}.</td><td>Tarif dipakai per tanggal transaksi.</td></tr>
<tr><td>Kenaikan HPP 1 Jul 2025 dan 1 Jan 2026</td><td class="bis">Bisnis</td><td>{{sku_hpp_jul25|int}} dan {{sku_hpp_jan26|int}} SKU di <code>product_cost_history.csv</code>.</td><td>HPP as-of tanggal transaksi (SCD).</td></tr>
<tr><td>Pembelian B2B bulk (qty 152-446)</td><td class="bis">Bisnis</td><td>{{b2b_rows|int}} baris, {{b2b_rp|rpj}}, kode promo <code>B2B-CORP</code> tidak ada di master promo; di luar sync POS.</td><td>Dipertahankan dan ditandai; dapat dikeluarkan lewat filter.</td></tr>
<tr><td>Toko <code>TRN-99</code>, duplikat, void, label tidak baku</td><td class="dat">Data</td><td>{{trn99_rows|int}} baris TRN-99 tidak ada di master toko; duplikat dan void terverifikasi lewat kontrol sync log.</td><td>Dikarantina atau dikoreksi di staging; rekonsiliasi selisih 0.</td></tr>
</tbody></table>

## Asumsi dan keterbatasan

- **Target toko = alokasi** target region (pangsa penjualan tahun lalu); bukan target resmi. Ambang status (Hijau ≥100%, Kuning 90-<100%, Merah <90%) adalah asumsi analis.
- **Estimasi dampak** memakai replay H2 2025 dan imbal hasil historis; elastisitas harga dan lift pada diskon yang berbeda tidak teramati. Estimasi penjualan hilang (SBY-01, BDG-02) bersifat indikatif.
- **Promo Lift** tidak mengendalikan musiman yang tidak terlihat dari tanggal; sebaiknya promo dibandingkan dengan promo sejenis lintas tahun. Biaya marketing di luar diskon, biaya operasional toko, dan biaya logistik retur tidak tersedia, sehingga contribution margin hanya dikurangi biaya channel.
- **Machine learning tidak diperlukan** untuk dua keputusan ini: keduanya dapat diputuskan dari analisis deskriptif dan diagnostik di atas.
