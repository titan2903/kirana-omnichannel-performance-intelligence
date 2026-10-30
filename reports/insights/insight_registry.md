# Insight Registry

Dihasilkan otomatis oleh `scripts/build_insights.py` dari `reports/insights/facts.sql` dan `kirana.duckdb`. Setiap angka yang dikutip di `B_insight_brief.md`, 
storyline dashboard, dan grafik ada di tabel ini beserta sumbernya. Nilai mentah dalam Rupiah penuh atau persen/poin.

| Kunci | Nilai | Sumber |
| --- | ---: | --- |
| `ach_ap_fy25` | 119.1242 | metrics.v_target_achievement |
| `ach_ap_h126` | 124.3362 | metrics.v_target_achievement |
| `ach_mp_fy25` | 109.0152 | metrics.v_target_achievement |
| `ach_mp_h126` | 127.4843 | metrics.v_target_achievement |
| `ach_reg_jb_fy25` | 100.7929 | metrics.v_target_achievement (Store, region dasar target) |
| `ach_reg_jb_h126` | 95.7988 | metrics.v_target_achievement (Store, region dasar target) |
| `ach_reg_sum_fy25` | 86.7422 | metrics.v_target_achievement (Store, region dasar target) |
| `ach_reg_sum_h126` | 88.9713 | metrics.v_target_achievement (Store, region dasar target) |
| `ach_st_fy25` | 95.6163 | metrics.v_target_achievement |
| `ach_st_h126` | 95.5997 | metrics.v_target_achievement |
| `ach_total_fy25` | 99.4935 | metrics.v_target_achievement |
| `ach_total_h126` | 105.8374 | metrics.v_target_achievement |
| `ach_wb_fy25` | 75.953 | metrics.v_target_achievement |
| `ach_wb_h126` | 87.4585 | metrics.v_target_achievement |
| `app_cm_per_disc_h225` | 0.9088 | CM tambahan per Rp diskon App Payday H2 2025 |
| `b2b_rows` | 14 | dw.fact_sales (is_b2b_bulk) |
| `b2b_rp` | 499918500 | dw.fact_sales (is_b2b_bulk) |
| `bdg02_est_lost_rp` | 20789288 | ESTIMASI: 7 hari x rata-rata harian 4 minggu sebelum+sesudah |
| `bdg02_failed_days` | 7 | dw.fact_pos_sync (FAILED) |
| `bdg02_net_nov25` | 69192400 | metrics.v_sales_monthly |
| `bgr01_h225_rp` | 673004400 | metrics.v_sales_monthly (BGR-01 Jul-Des 2025) |
| `cm_drop_pt` | 4.1808 | selisih cm_fy24 - cm_h126 |
| `cm_effect_margin_pt` | -3.291 | dekomposisi CM%: efek margin dalam channel |
| `cm_effect_mix_pt` | -0.8898 | dekomposisi CM% FY2024 -> H1 2026: efek bauran channel |
| `cm_fy24` | 43.6613 | metrics.v_sales_monthly |
| `cm_gap_st_mp` | 13.0043 | CM% Store - CM% Marketplace, H1 2026 (pt = sen per Rupiah) |
| `cm_h126` | 39.4805 | metrics.v_sales_monthly |
| `cmch_ap_fy24` | 42.3735 | metrics.v_sales_monthly |
| `cmch_ap_h126` | 38.2818 | metrics.v_sales_monthly |
| `cmch_mp_fy24` | 34.8773 | metrics.v_sales_monthly |
| `cmch_mp_h126` | 30.585 | metrics.v_sales_monthly |
| `cmch_st_fy24` | 46.2204 | metrics.v_sales_monthly |
| `cmch_st_h126` | 43.5892 | metrics.v_sales_monthly |
| `cmch_wb_fy24` | 44.3412 | metrics.v_sales_monthly |
| `cmch_wb_h126` | 41.6918 | metrics.v_sales_monthly |
| `data_through_ord` | 20260630 | metrics.v_data_freshness |
| `disc_fy24` | 1.6266 | metrics.v_sales_monthly |
| `disc_h126` | 2.0528 | metrics.v_sales_monthly |
| `disc_rise_pt` | 0.4263 | selisih disc_h126 - disc_fy24 |
| `fashion_excess_refund_year_rp` | 388497546.8858 | net Fashion online x (RR online - RR Store) / 2,5 tahun |
| `fashion_refund_rp` | 1499408400 | metrics.v_return_rate_monthly |
| `fashion_refund_share_pct` | 40.5045 | metrics.v_return_rate_monthly |
| `fee_fy24` | 2.4462 | metrics.v_sales_monthly |
| `fee_h126` | 3.5662 | metrics.v_sales_monthly |
| `fee_rise_pt` | 1.12 | selisih fee_h126 - fee_fy24 |
| `fr_berubah` | 14.2348 | metrics.v_return_reason_monthly (Fashion) |
| `fr_cacat` | 9.9456 | metrics.v_return_reason_monthly (Fashion) |
| `fr_ukuran` | 57.0411 | metrics.v_return_reason_monthly (Fashion) |
| `fr_warna` | 18.7785 | metrics.v_return_reason_monthly (Fashion) |
| `gap_ap_fy25` | 1059860400 | metrics.v_target_achievement |
| `gap_ap_h126` | 920395100 | metrics.v_target_achievement |
| `gap_mp_fy25` | 768547000 | metrics.v_target_achievement |
| `gap_mp_h126` | 1264550500 | metrics.v_target_achievement |
| `gap_st_fy25` | -1156900600 | metrics.v_target_achievement |
| `gap_st_h126` | -617005100 | metrics.v_target_achievement |
| `gap_total_fy25` | -223762700 | metrics.v_target_achievement |
| `gap_total_h126` | 1390478100 | metrics.v_target_achievement |
| `gap_wb_fy25` | -895269500 | metrics.v_target_achievement |
| `gap_wb_h126` | -177462400 | metrics.v_target_achievement |
| `gm_cf_fy24` | 46.1075 | dw.fact_sales x dw.dim_product_cost (HPP 2024) |
| `gm_cf_fy25` | 45.7166 | dw.fact_sales x dw.dim_product_cost (HPP 2024) |
| `gm_cf_h126` | 46.3173 | dw.fact_sales x dw.dim_product_cost (HPP 2024) |
| `gm_drop_pt` | 3.0608 | selisih gm_fy24 - gm_h126 |
| `gm_fy24` | 46.1075 | metrics.v_sales_monthly |
| `gm_fy25` | 44.3231 | metrics.v_sales_monthly |
| `gm_h126` | 43.0467 | metrics.v_sales_monthly |
| `gm_hppterkini_fy24` | 43.0339 | stg.product (HPP terkini; bukan dipakai) |
| `harga_perlu_naik_pct` | 5.6795 | kenaikan harga neto agar GM H1 2026 = GM FY2024 (volume tetap) |
| `hpp_effect_pt` | -3.2707 | gm_h126 - gm_cf_h126 |
| `hpp_idx_fy25` | 102.3828 | dw.fact_sales: HPP per unit, SKU sama, FY2024 = 100 |
| `hpp_idx_h126` | 105.8673 | dw.fact_sales: HPP per unit, SKU sama, FY2024 = 100 |
| `hpp_naik_jan26_pct` | 3.9951 | rata-rata kenaikan HPP SKU yang berubah 2026-01-01 |
| `hpp_naik_jul25_pct` | 17.9997 | rata-rata kenaikan HPP SKU yang berubah 2025-07-01 |
| `mega_depth_breakeven_cm_pct` | 26.0537 | d* = 1 - (1 - GM baseline) / (1 - 11,5%) |
| `mega_discount_pct` | 45 | dw.dim_promo |
| `mp_fee_extra_h126_rp` | 146638762.5 | Net Sales Marketplace H1 2026 x 2,5% |
| `mp_fee_extra_total_rp` | 330147422.5 | Net Sales Marketplace sejak 2025-04-01 x (11,5% - 9,0%) |
| `online_yoy_all` | 42.9696 | stg.online_line, seluruh kota |
| `online_yoy_medan` | 45.2375 | stg.online_line (ship_city), H1 2026 vs H1 2025 |
| `online_yoy_palembang` | 45.6082 | stg.online_line (ship_city), H1 2026 vs H1 2025 |
| `p_budget_total` | 21140000000 | metrics.v_promo_performance |
| `p_cm_ap` | 300411163 | metrics.v_promo_performance |
| `p_cm_mega` | -144587796 | metrics.v_promo_performance |
| `p_disc_ap` | 307011000 | metrics.v_promo_performance |
| `p_disc_mbr` | 152345000 | metrics.v_promo_performance |
| `p_disc_total` | 1942242500 | metrics.v_promo_performance |
| `p_gm_ap` | 325748866 | metrics.v_promo_performance |
| `p_gm_clr` | -166112193 | metrics.v_promo_performance |
| `p_gm_clr_year` | -55370731 | p_gm_clr / jumlah kode (satu per tahun) |
| `p_gm_hbn` | 918125 | metrics.v_promo_performance |
| `p_gm_mbr` | -13650510 | metrics.v_promo_performance |
| `p_gm_mega` | -101117490 | metrics.v_promo_performance |
| `p_gm_rmd` | 225282835 | metrics.v_promo_performance |
| `p_gmpct_base_mega` | 38.4937 | metrics.v_promo_performance |
| `p_gmpct_promo_mega` | -12.0437 | metrics.v_promo_performance |
| `p_h225_cm_mega` | -99526864 | metrics.v_promo_performance (promo mulai Jul-Des 2025) |
| `p_h225_disc_mega` | 240196100 | metrics.v_promo_performance (promo mulai Jul-Des 2025) |
| `p_h225_net_mega` | 237350988 | metrics.v_promo_performance (promo mulai Jul-Des 2025) |
| `p_lift_clr` | -32.2333 | metrics.v_promo_performance |
| `p_lift_mega` | 457.7625 | metrics.v_promo_performance |
| `p_n_ap` | 27 | metrics.v_promo_performance |
| `p_n_mbr` | 30 | metrics.v_promo_performance |
| `p_neg_ap` | 0 | metrics.v_promo_performance |
| `p_neg_clr` | 3 | metrics.v_promo_performance |
| `p_neg_hbn` | 0 | metrics.v_promo_performance |
| `p_neg_mbr` | 20 | metrics.v_promo_performance |
| `p_neg_mega` | 8 | metrics.v_promo_performance |
| `p_neg_rmd` | 0 | metrics.v_promo_performance |
| `p_pos_ap` | 27 | metrics.v_promo_performance |
| `p_pos_clr` | 0 | metrics.v_promo_performance |
| `p_pos_hbn` | 2 | metrics.v_promo_performance |
| `p_pos_mbr` | 10 | metrics.v_promo_performance |
| `p_pos_mega` | 0 | metrics.v_promo_performance |
| `p_pos_rmd` | 3 | metrics.v_promo_performance |
| `p_util_total_pct` | 9.1875 | metrics.v_promo_performance |
| `price_idx_fy25` | 99.9558 | dw.fact_sales: harga neto per unit, SKU x channel sama, FY2024 = 100 |
| `price_idx_h126` | 101.4664 | dw.fact_sales: harga neto per unit, SKU x channel sama, FY2024 = 100 |
| `promo_n_app` | 27 | dw.dim_promo (channel_scope = Mobile App) |
| `promo_n_website` | 2 | dw.dim_promo (channel_scope = Website) |
| `reg_jb_h125_asof` | 98.0958 | dw.fact_sales.region_asof vs dw.fact_target |
| `reg_jb_h125_basis` | 98.0958 | dw.fact_sales.region_target_basis vs dw.fact_target |
| `reg_jb_h225_asof` | 73.363 | dw.fact_sales.region_asof vs dw.fact_target |
| `reg_jb_h225_basis` | 103.4347 | dw.fact_sales.region_target_basis vs dw.fact_target |
| `reg_jkt_h125_asof` | 94.8959 | dw.fact_sales.region_asof vs dw.fact_target |
| `reg_jkt_h125_basis` | 94.8959 | dw.fact_sales.region_target_basis vs dw.fact_target |
| `reg_jkt_h225_asof` | 109.7119 | dw.fact_sales.region_asof vs dw.fact_target |
| `reg_jkt_h225_basis` | 96.2841 | dw.fact_sales.region_target_basis vs dw.fact_target |
| `rp_gap_gm_h126` | 771652536.9711 | gm_drop_pt x net_h126 |
| `rp_per_1pct_harga` | 252104781 | 1% x net_h126 (sebelum efek volume) |
| `rr_ap_total_pct` | 5.1107 | metrics.v_return_rate_monthly |
| `rr_fashion_online_pct` | 15.0538 | metrics.v_return_rate_monthly (Fashion, online) |
| `rr_fashion_store_pct` | 2.7735 | metrics.v_return_rate_monthly (Fashion, Store) |
| `rr_mp_total_pct` | 6.3885 | metrics.v_return_rate_monthly |
| `rr_other_online_pct` | 3.5771 | metrics.v_return_rate_monthly (non-Fashion, online) |
| `rr_other_store_pct` | 1.7445 | metrics.v_return_rate_monthly (non-Fashion, Store) |
| `rr_st_total_pct` | 1.9287 | metrics.v_return_rate_monthly |
| `s_bdg01_ach_fy25` | 102.5311 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_bdg01_ach_h126` | 97.0663 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_bdg02_ach_fy25` | 101.2008 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_bdg02_ach_h126` | 93.7343 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_bgr01_ach_fy25` | 97.8059 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_bgr01_ach_h126` | 93.3219 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_bks01_ach_fy25` | 97.9814 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_bks01_ach_h126` | 93.9284 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_dpk01_ach_fy25` | 90.2254 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_dpk01_ach_h126` | 103.2464 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_dps01_ach_fy25` | 90.7592 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_dps01_ach_h126` | 96.5512 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_jkt01_ach_fy25` | 96.2251 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_jkt01_ach_h126` | 101.2796 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_jkt02_ach_fy25` | 98.3825 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_jkt02_ach_h126` | 91.8452 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_jkt03_ach_fy25` | 90.1768 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_jkt03_ach_h126` | 92.0083 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_mdn01_ach_fy25` | 79.2975 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_mdn01_ach_h126` | 83.5388 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_mdn01_gap_fy25` | -301377381.75 | metrics.v_store_performance_monthly |
| `s_mdn01_gap_h126` | -107387318.62 | metrics.v_store_performance_monthly |
| `s_mdn01_half_net_rp` | 53693659.31 | 50% dari gap H1 2026 MDN-01 |
| `s_mdn01_yoy` | -6.317 | metrics.v_sales_monthly: H1 2026 vs H1 2025, tanpa B2B |
| `s_mlg01_ach_fy25` | 96.7 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_mlg01_ach_h126` | 87.9227 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_mlg01_yoy` | -1.5643 | metrics.v_sales_monthly: H1 2026 vs H1 2025, tanpa B2B |
| `s_plm01_ach_fy25` | 96.5479 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_plm01_ach_h126` | 95.0331 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_plm01_yoy` | 5.6987 | metrics.v_sales_monthly: H1 2026 vs H1 2025, tanpa B2B |
| `s_prog4_cm_full_rp` | 138432326.4404 | gap 4 toko x CM Store H1 2026 (batas atas) |
| `s_prog4_cm_half_rp` | 69216163.2202 | skenario 50% gap tertutup |
| `s_prog4_gap_h126` | -317583753.52 | MDN-01 + SBY-02 + MLG-01 + SOL-01, H1 2026 |
| `s_sby01_ach_fy25` | 89.0034 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_sby01_ach_h126` | 111.3141 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_sby01_ach_h126_xb2b` | 104.652 | metrics.v_store_performance_monthly: tanpa B2B |
| `s_sby02_ach_fy25` | 95.3737 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_sby02_ach_h126` | 87.8322 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_sby02_yoy` | -1.1093 | metrics.v_sales_monthly: H1 2026 vs H1 2025, tanpa B2B |
| `s_smg01_ach_fy25` | 101.058 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_smg01_ach_h126` | 94.0693 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_sol01_ach_fy25` | 106.2257 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_sol01_ach_h126` | 89.8967 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_sol01_yoy` | -0.7201 | metrics.v_sales_monthly: H1 2026 vs H1 2025, tanpa B2B |
| `s_tgr01_ach_fy25` | 98.4512 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_tgr01_ach_h126` | 102.0049 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_ygy01_ach_fy25` | 98.4349 | metrics.v_store_performance_monthly (target ALOKASI) |
| `s_ygy01_ach_h126` | 90.9456 | metrics.v_store_performance_monthly (target ALOKASI) |
| `sby01_closed_days` | 49 | dw.fact_pos_sync (STORE_CLOSED) |
| `sby01_est_lost_rp` | 300412656 | ESTIMASI: 49 hari x rata-rata harian 8 minggu sebelum+sesudah |
| `sby01_net_aug25` | 15796300 | metrics.v_sales_monthly |
| `sby01_net_jul25` | 203256000 | metrics.v_sales_monthly |
| `sby01_net_oct25` | 239553900 | metrics.v_sales_monthly |
| `sby01_net_sep25` | 64748400 | metrics.v_sales_monthly |
| `scn_promo_pt_cm` | 0.6113 | skenario tinggi / net_h126 (proksi Net Sales semester) |
| `scn_promo_total_high_rp` | 154102158.367 | hentikan Mega Sale + realokasi ke App Payday |
| `scn_promo_total_low_rp` | 99526864 | hentikan Mega Sale: hindari CM negatif H2 2025 |
| `scn_realokasi_gain_rp` | 54575294.367 | dialihkan x 50% imbal hasil historis App Payday (konservatif) |
| `scn_realokasi_rp` | 120098050 | 50% diskon Mega Sale H2 2025 dialihkan ke App Payday |
| `share_ap_fy24` | 10.498 | metrics.v_sales_monthly |
| `share_ap_h126` | 18.6525 | metrics.v_sales_monthly |
| `share_mp_fy24` | 17.4506 | metrics.v_sales_monthly |
| `share_mp_h126` | 23.2663 | metrics.v_sales_monthly |
| `share_st_fy24` | 62.6951 | metrics.v_sales_monthly |
| `share_st_h126` | 53.1723 | metrics.v_sales_monthly |
| `share_wb_fy24` | 9.3564 | metrics.v_sales_monthly |
| `share_wb_h126` | 4.9088 | metrics.v_sales_monthly |
| `sku_hpp_jan26` | 190 | dw.dim_product_cost (berlaku 2026-01-01) |
| `sku_hpp_jul25` | 60 | dw.dim_product_cost (berlaku 2025-07-01) |
| `tgt_jb_202506` | 341000000 | metrics.v_target_achievement |
| `tgt_jb_202507` | 347000000 | metrics.v_target_achievement |
| `tgt_jb_202601` | 277000000 | metrics.v_target_achievement |
| `total_refund_rp` | 3701827300 | metrics.v_return_rate_monthly |
| `trn99_rows` | 324 | stg.pos_line (REJECT_STORE_NOT_IN_MASTER) |
| `web_mig_app` | 2538 | pindah ke Mobile App (tanpa Website) |
| `web_mig_inactive` | 2002 | tidak aktif sama sekali H1 2026 |
| `web_mig_other` | 2309 | pindah ke Marketplace/Store saja |
| `web_mig_still` | 1119 | masih berbelanja di Website H1 2026 |
| `web_mig_still_pct` | 14.0437 | web_mig_still / web_mig_total |
| `web_mig_total` | 7968 | dw.fact_sales: member aktif Website FY2024 |
| `yoy_ap` | 66.8244 | metrics.v_sales_monthly: H1 2026 vs H1 2025 |
| `yoy_mp` | 46.7499 | metrics.v_sales_monthly: H1 2026 vs H1 2025 |
| `yoy_st` | 9.1525 | metrics.v_sales_monthly: H1 2026 vs H1 2025 |
| `yoy_wb` | -14.155 | metrics.v_sales_monthly: H1 2026 vs H1 2025 |
