-- Semua angka yang dikutip di insight brief dan storyline dashboard, dihitung langsung dari kirana.duckdb.
--   duckdb -readonly kirana.duckdb -json < reports/insights/facts.sql      (dibaca oleh scripts/build_insights.py)
-- Keluaran: baris (k, v, src). `src` = view/tabel sumber (masuk ke reports/insights/insight_registry.md).
-- Periode: fy24 = Jan-Des 2024, fy25 = Jan-Des 2025, h126 = Jan-Jun 2026, h225 = Jul-Des 2025. Rupiah penuh, tanpa pajak.
-- Kode channel: st Store, wb Website, mp Marketplace, ap Mobile App.

CREATE TEMP TABLE fs AS
SELECT f.*, CASE WHEN f.sale_date < DATE '2025-01-01' THEN 'fy24' WHEN f.sale_date < DATE '2026-01-01' THEN 'fy25' ELSE 'h126' END AS per,
       p.sku, p.category, CASE c.channel_name WHEN 'Store' THEN 'st' WHEN 'Website' THEN 'wb' WHEN 'Marketplace' THEN 'mp' ELSE 'ap' END AS ch
FROM dw.fact_sales f JOIN dw.dim_product p USING (product_key) JOIN dw.dim_channel c USING (channel_key);

CREATE TEMP TABLE m AS   -- metrics.v_sales_monthly diberi periode dan kode channel
SELECT CASE WHEN month_start < DATE '2025-01-01' THEN 'fy24' WHEN month_start < DATE '2026-01-01' THEN 'fy25' ELSE 'h126' END AS per,
       CASE channel_name WHEN 'Store' THEN 'st' WHEN 'Website' THEN 'wb' WHEN 'Marketplace' THEN 'mp' ELSE 'ap' END AS ch,
       month_start, store_code, is_b2b_bulk, net_sales_idr, gross_margin_idr, channel_fee_idr, contribution_margin_idr, discount_idr, gross_sales_idr
FROM metrics.v_sales_monthly;

CREATE TEMP TABLE facts (k VARCHAR, v DOUBLE, src VARCHAR);

-- ====================================================== I1 margin: HPP vs harga
INSERT INTO facts
SELECT k, v, 'metrics.v_sales_monthly' FROM (
  SELECT 'net_' || per AS k, sum(net_sales_idr)::DOUBLE AS v FROM m GROUP BY per
  UNION ALL SELECT 'gm_' || per, 100.0 * sum(gross_margin_idr) / sum(net_sales_idr) FROM m GROUP BY per
  UNION ALL SELECT 'cm_' || per, 100.0 * sum(contribution_margin_idr) / sum(net_sales_idr) FROM m GROUP BY per
  UNION ALL SELECT 'fee_' || per, 100.0 * sum(channel_fee_idr) / sum(net_sales_idr) FROM m GROUP BY per
  UNION ALL SELECT 'disc_' || per, 100.0 * sum(discount_idr) / sum(gross_sales_idr) FROM m GROUP BY per);

INSERT INTO facts SELECT 'gm_drop_pt', (SELECT v FROM facts WHERE k = 'gm_fy24') - (SELECT v FROM facts WHERE k = 'gm_h126'), 'selisih gm_fy24 - gm_h126';
INSERT INTO facts SELECT 'cm_drop_pt', (SELECT v FROM facts WHERE k = 'cm_fy24') - (SELECT v FROM facts WHERE k = 'cm_h126'), 'selisih cm_fy24 - cm_h126';
INSERT INTO facts SELECT 'disc_rise_pt', (SELECT v FROM facts WHERE k = 'disc_h126') - (SELECT v FROM facts WHERE k = 'disc_fy24'), 'selisih disc_h126 - disc_fy24';
INSERT INTO facts SELECT 'fee_rise_pt', (SELECT v FROM facts WHERE k = 'fee_h126') - (SELECT v FROM facts WHERE k = 'fee_fy24'), 'selisih fee_h126 - fee_fy24';

-- kontrafaktual: HPP per SKU dibekukan pada nilai 31 Des 2024
CREATE TEMP TABLE c24 AS SELECT product_key, unit_cost FROM dw.dim_product_cost WHERE DATE '2024-12-31' BETWEEN valid_from AND valid_to;
INSERT INTO facts SELECT 'gm_cf_' || per, 100.0 * (sum(f.net_sales) - sum(f.qty * c24.unit_cost)) / sum(f.net_sales), 'dw.fact_sales x dw.dim_product_cost (HPP 2024)'
FROM fs f JOIN c24 USING (product_key) GROUP BY per;
INSERT INTO facts SELECT 'hpp_effect_pt', (SELECT v FROM facts WHERE k = 'gm_h126') - (SELECT v FROM facts WHERE k = 'gm_cf_h126'), 'gm_h126 - gm_cf_h126';

CREATE TEMP TABLE np AS SELECT per, sku, ch, sum(net_sales)::DOUBLE / sum(qty) AS np, sum(qty) AS q FROM fs GROUP BY 1, 2, 3;
INSERT INTO facts SELECT 'price_idx_' || a.per, 100.0 * sum(a.q * a.np) / sum(a.q * b.np), 'dw.fact_sales: harga neto per unit, SKU x channel sama, FY2024 = 100'
FROM np a JOIN np b ON b.per = 'fy24' AND a.sku = b.sku AND a.ch = b.ch WHERE a.per <> 'fy24' GROUP BY a.per;
CREATE TEMP TABLE cp AS SELECT per, sku, sum(cogs)::DOUBLE / sum(qty) AS cp, sum(qty) AS q FROM fs GROUP BY 1, 2;
INSERT INTO facts SELECT 'hpp_idx_' || a.per, 100.0 * sum(a.q * a.cp) / sum(a.q * b.cp), 'dw.fact_sales: HPP per unit, SKU sama, FY2024 = 100'
FROM cp a JOIN cp b ON b.per = 'fy24' AND a.sku = b.sku WHERE a.per <> 'fy24' GROUP BY a.per;

INSERT INTO facts SELECT 'sku_hpp_naik', count(*), 'dw.dim_product_cost' FROM (SELECT sku FROM dw.dim_product_cost GROUP BY sku HAVING count(*) > 1);
INSERT INTO facts SELECT 'sku_hpp_jul25', count(*), 'dw.dim_product_cost (berlaku 2025-07-01)' FROM dw.dim_product_cost WHERE valid_from = DATE '2025-07-01';
INSERT INTO facts SELECT 'sku_hpp_jan26', count(*), 'dw.dim_product_cost (berlaku 2026-01-01)' FROM dw.dim_product_cost WHERE valid_from = DATE '2026-01-01';
INSERT INTO facts SELECT 'hpp_naik_jul25_pct', 100.0 * avg(c.unit_cost::DOUBLE / o.unit_cost - 1), 'rata-rata kenaikan HPP SKU yang berubah 2025-07-01'
FROM dw.dim_product_cost c JOIN dw.dim_product_cost o ON o.sku = c.sku AND o.valid_to = c.valid_from - 1 WHERE c.valid_from = DATE '2025-07-01';
INSERT INTO facts SELECT 'hpp_naik_jan26_pct', 100.0 * avg(c.unit_cost::DOUBLE / o.unit_cost - 1), 'rata-rata kenaikan HPP SKU yang berubah 2026-01-01'
FROM dw.dim_product_cost c JOIN dw.dim_product_cost o ON o.sku = c.sku AND o.valid_to = c.valid_from - 1 WHERE c.valid_from = DATE '2026-01-01';
-- GM bila HPP terkini dipakai untuk seluruh histori (efek SCD)
INSERT INTO facts SELECT 'gm_hppterkini_' || per, 100.0 * (sum(f.net_sales) - sum(f.qty * p.current_unit_cost)) / sum(f.net_sales), 'stg.product (HPP terkini; bukan dipakai)'
FROM fs f JOIN dw.dim_product dp USING (product_key) JOIN stg.product p ON p.sku = dp.sku GROUP BY per;

INSERT INTO facts SELECT 'rp_per_1pct_harga', (SELECT v FROM facts WHERE k = 'net_h126') * 0.01, '1% x net_h126 (sebelum efek volume)';
INSERT INTO facts SELECT 'rp_per_1pt_gm', (SELECT v FROM facts WHERE k = 'net_h126') * 0.01, '1 pt GM x net_h126';
INSERT INTO facts SELECT 'rp_gap_gm_h126', (SELECT v FROM facts WHERE k = 'gm_drop_pt') / 100.0 * (SELECT v FROM facts WHERE k = 'net_h126'), 'gm_drop_pt x net_h126';
INSERT INTO facts SELECT 'harga_perlu_naik_pct', 100.0 * ((1 - (SELECT v FROM facts WHERE k = 'gm_h126') / 100.0) / (1 - (SELECT v FROM facts WHERE k = 'gm_fy24') / 100.0) - 1),
       'kenaikan harga neto agar GM H1 2026 = GM FY2024 (volume tetap)';

-- ====================================================== I2 CM: bauran dan komisi
INSERT INTO facts SELECT 'share_' || ch || '_' || per, 100.0 * sum(net_sales_idr) / sum(sum(net_sales_idr)) OVER (PARTITION BY per), 'metrics.v_sales_monthly'
FROM m GROUP BY per, ch;
INSERT INTO facts SELECT 'cmch_' || ch || '_' || per, 100.0 * sum(contribution_margin_idr) / sum(net_sales_idr), 'metrics.v_sales_monthly' FROM m GROUP BY per, ch;
INSERT INTO facts SELECT 'gmch_' || ch || '_' || per, 100.0 * sum(gross_margin_idr) / sum(net_sales_idr), 'metrics.v_sales_monthly' FROM m GROUP BY per, ch;

CREATE TEMP TABLE w AS SELECT per, ch, sum(net_sales_idr)::DOUBLE AS net, sum(contribution_margin_idr)::DOUBLE AS cm FROM m GROUP BY per, ch;
INSERT INTO facts
WITH a AS (SELECT ch, net / sum(net) OVER () AS w0, cm / net AS c0 FROM w WHERE per = 'fy24'),
     b AS (SELECT ch, net / sum(net) OVER () AS w1, cm / net AS c1 FROM w WHERE per = 'h126')
SELECT 'cm_effect_mix_pt', 100 * sum((b.w1 - a.w0) * a.c0), 'dekomposisi CM% FY2024 -> H1 2026: efek bauran channel' FROM a JOIN b USING (ch)
UNION ALL SELECT 'cm_effect_margin_pt', 100 * sum(b.w1 * (b.c1 - a.c0)), 'dekomposisi CM%: efek margin dalam channel' FROM a JOIN b USING (ch);

INSERT INTO facts SELECT 'mp_fee_extra_total_rp', sum(net_sales_idr) * 0.025, 'Net Sales Marketplace sejak 2025-04-01 x (11,5% - 9,0%)'
FROM metrics.v_sales_monthly WHERE channel_name = 'Marketplace' AND month_start >= DATE '2025-04-01';
INSERT INTO facts SELECT 'mp_fee_extra_h126_rp', sum(net_sales_idr) * 0.025, 'Net Sales Marketplace H1 2026 x 2,5%'
FROM metrics.v_sales_monthly WHERE channel_name = 'Marketplace' AND month_start >= DATE '2026-01-01';

-- ====================================================== I3 achievement
CREATE TEMP TABLE a AS
SELECT CASE WHEN month_start < DATE '2026-01-01' THEN 'fy25' ELSE 'h126' END AS per,
       CASE channel_name WHEN 'Store' THEN 'st' WHEN 'Website' THEN 'wb' WHEN 'Marketplace' THEN 'mp' ELSE 'ap' END AS ch,
       region, net_sales_idr, target_net_sales_idr
FROM metrics.v_target_achievement WHERE target_net_sales_idr IS NOT NULL;
INSERT INTO facts SELECT 'ach_total_' || per, 100.0 * sum(net_sales_idr) / sum(target_net_sales_idr), 'metrics.v_target_achievement' FROM a GROUP BY per;
INSERT INTO facts SELECT 'gap_total_' || per, (sum(net_sales_idr) - sum(target_net_sales_idr))::DOUBLE, 'metrics.v_target_achievement' FROM a GROUP BY per;
INSERT INTO facts SELECT 'ach_' || ch || '_' || per, 100.0 * sum(net_sales_idr) / sum(target_net_sales_idr), 'metrics.v_target_achievement' FROM a GROUP BY per, ch;
INSERT INTO facts SELECT 'gap_' || ch || '_' || per, (sum(net_sales_idr) - sum(target_net_sales_idr))::DOUBLE, 'metrics.v_target_achievement' FROM a GROUP BY per, ch;
INSERT INTO facts SELECT 'ach_reg_' || CASE region WHEN 'Sumatera' THEN 'sum' WHEN 'Jawa Barat' THEN 'jb' WHEN 'Jabodetabek' THEN 'jkt' WHEN 'Jateng & DIY' THEN 'jtg' WHEN 'Jawa Timur' THEN 'jtm' ELSE 'bali' END || '_' || per,
       100.0 * sum(net_sales_idr) / sum(target_net_sales_idr), 'metrics.v_target_achievement (Store, region dasar target)'
FROM a WHERE ch = 'st' GROUP BY per, region;
INSERT INTO facts SELECT 'gap_reg_sum_' || per, (sum(net_sales_idr) - sum(target_net_sales_idr))::DOUBLE, 'metrics.v_target_achievement' FROM a WHERE ch = 'st' AND region = 'Sumatera' GROUP BY per;

INSERT INTO facts SELECT 'yoy_' || ch, 100.0 * (sum(net_sales_idr) FILTER (WHERE month_start >= DATE '2026-01-01') / sum(net_sales_idr) FILTER (WHERE month_start BETWEEN DATE '2025-01-01' AND DATE '2025-06-01') - 1),
       'metrics.v_sales_monthly: H1 2026 vs H1 2025' FROM m GROUP BY ch;
INSERT INTO facts SELECT 'netsemester_wb_' || k, v, 'metrics.v_sales_monthly' FROM (
  SELECT 'h124' AS k, sum(net_sales_idr)::DOUBLE AS v FROM m WHERE ch = 'wb' AND month_start < DATE '2024-07-01'
  UNION ALL SELECT 'h126', sum(net_sales_idr) FROM m WHERE ch = 'wb' AND month_start >= DATE '2026-01-01');

-- Website: ke mana member FY2024 pergi di H1 2026
CREATE TEMP TABLE mt AS
SELECT f.customer_key, c.channel_name, CASE WHEN f.sale_date < DATE '2025-01-01' THEN 'fy24' WHEN f.sale_date < DATE '2026-01-01' THEN 'fy25' ELSE 'h126' END AS per
FROM dw.fact_sales f JOIN dw.dim_channel c USING (channel_key) WHERE f.customer_key > 0 AND NOT f.is_b2b_bulk GROUP BY ALL;
CREATE TEMP TABLE w24 AS SELECT DISTINCT customer_key FROM mt WHERE per = 'fy24' AND channel_name = 'Website';
CREATE TEMP TABLE h26 AS SELECT customer_key, bool_or(channel_name = 'Website') AS web, bool_or(channel_name = 'Mobile App') AS app FROM mt WHERE per = 'h126' GROUP BY 1;
INSERT INTO facts
SELECT 'web_mig_total', count(*), 'dw.fact_sales: member aktif Website FY2024' FROM w24
UNION ALL SELECT 'web_mig_still', count(*) FILTER (WHERE h.web), 'masih berbelanja di Website H1 2026' FROM w24 LEFT JOIN h26 h USING (customer_key)
UNION ALL SELECT 'web_mig_app', count(*) FILTER (WHERE h.app AND NOT h.web), 'pindah ke Mobile App (tanpa Website)' FROM w24 LEFT JOIN h26 h USING (customer_key)
UNION ALL SELECT 'web_mig_other', count(*) FILTER (WHERE h.customer_key IS NOT NULL AND NOT h.web AND NOT h.app), 'pindah ke Marketplace/Store saja' FROM w24 LEFT JOIN h26 h USING (customer_key)
UNION ALL SELECT 'web_mig_inactive', count(*) FILTER (WHERE h.customer_key IS NULL), 'tidak aktif sama sekali H1 2026' FROM w24 LEFT JOIN h26 h USING (customer_key);
INSERT INTO facts SELECT 'web_active_' || period_label, active_members, 'metrics.v_members_period' FROM metrics.v_members_period WHERE period_type = 'Semester' AND channel_name = 'Website' AND period_label IN ('2024-H1', '2026-H1');
INSERT INTO facts SELECT 'web_repeat_' || period_label, repeat_rate_pct, 'metrics.v_members_period' FROM metrics.v_members_period WHERE period_type = 'Semester' AND channel_name = 'Website' AND period_label IN ('2024-H1', '2026-H1');
INSERT INTO facts SELECT 'promo_n_website', count(*), 'dw.dim_promo (channel_scope = Website)' FROM dw.dim_promo WHERE channel_scope = 'Website';
INSERT INTO facts SELECT 'promo_n_all', count(*), 'dw.dim_promo (channel_scope = ALL, Ramadan)' FROM dw.dim_promo WHERE channel_scope = 'ALL' AND promo_key > 0;
INSERT INTO facts SELECT 'promo_n_app', count(*), 'dw.dim_promo (channel_scope = Mobile App)' FROM dw.dim_promo WHERE channel_scope = 'Mobile App';

-- ====================================================== I4 promo
CREATE TEMP TABLE pp AS
SELECT *, CASE promo_type WHEN 'App Payday' THEN 'ap' WHEN 'Ramadan' THEN 'rmd' WHEN 'Harbolnas' THEN 'hbn' WHEN 'Member Day' THEN 'mbr' WHEN 'Mega Sale' THEN 'mega' ELSE 'clr' END AS t,
       CASE WHEN start_date >= DATE '2025-07-01' AND start_date < DATE '2026-01-01' THEN 'h225' END AS sem
FROM metrics.v_promo_performance;
INSERT INTO facts SELECT k || '_' || t, v, 'metrics.v_promo_performance' FROM (
  SELECT t, 'p_n' AS k, count(*)::DOUBLE AS v FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_gm', sum(incremental_gross_margin_idr)::DOUBLE FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_cm', sum(incremental_contribution_margin_idr)::DOUBLE FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_net', sum(incremental_net_sales_idr)::DOUBLE FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_disc', sum(discount_idr)::DOUBLE FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_budget', sum(budget_idr)::DOUBLE FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_lift', avg(lift_net_pct) FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_lift_unit', avg(lift_qty_pct) FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_gmpct_promo', avg(gm_pct_promo) FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_gmpct_base', avg(gm_pct_baseline) FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_pos', count(*) FILTER (WHERE incremental_gross_margin_idr > 0)::DOUBLE FROM pp GROUP BY t
  UNION ALL SELECT t, 'p_neg', count(*) FILTER (WHERE incremental_gross_margin_idr <= 0)::DOUBLE FROM pp GROUP BY t);
INSERT INTO facts SELECT 'p_h225_' || k || '_' || t, v, 'metrics.v_promo_performance (promo mulai Jul-Des 2025)' FROM (
  SELECT t, 'gm' AS k, sum(incremental_gross_margin_idr)::DOUBLE AS v FROM pp WHERE sem = 'h225' GROUP BY t
  UNION ALL SELECT t, 'cm', sum(incremental_contribution_margin_idr)::DOUBLE FROM pp WHERE sem = 'h225' GROUP BY t
  UNION ALL SELECT t, 'net', sum(incremental_net_sales_idr)::DOUBLE FROM pp WHERE sem = 'h225' GROUP BY t
  UNION ALL SELECT t, 'disc', sum(discount_idr)::DOUBLE FROM pp WHERE sem = 'h225' GROUP BY t
  UNION ALL SELECT t, 'n', count(*)::DOUBLE FROM pp WHERE sem = 'h225' GROUP BY t);
INSERT INTO facts SELECT 'p_budget_total', sum(budget_idr), 'metrics.v_promo_performance' FROM pp;
INSERT INTO facts SELECT 'p_disc_total', sum(discount_idr), 'metrics.v_promo_performance' FROM pp;
INSERT INTO facts SELECT 'p_util_total_pct', 100.0 * sum(discount_idr) / sum(budget_idr), 'metrics.v_promo_performance' FROM pp;
INSERT INTO facts SELECT 'mega_gmpct_promo_min', min(gm_pct_promo), 'metrics.v_promo_performance (Mega Sale)' FROM pp WHERE t = 'mega';
INSERT INTO facts SELECT 'mega_discount_pct', max(discount_pct), 'dw.dim_promo' FROM pp WHERE t = 'mega';
INSERT INTO facts SELECT 'mega_gmpct_base_2025', avg(gm_pct_baseline), 'metrics.v_promo_performance (Mega Sale 2025)' FROM pp WHERE t = 'mega' AND start_date >= DATE '2025-01-01';
-- kedalaman diskon maksimum agar CM promo >= 0 (tanpa memperhitungkan lift): d* = 1 - (1 - GM_baseline) / (1 - fee)
INSERT INTO facts SELECT 'mega_depth_breakeven_cm_pct', 100.0 * (1 - (1 - (SELECT v FROM facts WHERE k = 'mega_gmpct_base_2025') / 100.0) / (1 - 0.115)), 'd* = 1 - (1 - GM baseline) / (1 - 11,5%)';
INSERT INTO facts SELECT 'mega_depth_breakeven_gm_pct', (SELECT v FROM facts WHERE k = 'mega_gmpct_base_2025'), 'd* = GM baseline (GM promo = 0)';
INSERT INTO facts SELECT 'app_cm_per_disc_h225', (SELECT v FROM facts WHERE k = 'p_h225_cm_ap') / (SELECT v FROM facts WHERE k = 'p_h225_disc_ap'), 'CM tambahan per Rp diskon App Payday H2 2025';
INSERT INTO facts SELECT 'scn_realokasi_rp', 0.5 * (SELECT v FROM facts WHERE k = 'p_h225_disc_mega'), '50% diskon Mega Sale H2 2025 dialihkan ke App Payday';
INSERT INTO facts SELECT 'scn_realokasi_gain_rp', 0.5 * (SELECT v FROM facts WHERE k = 'p_h225_disc_mega') * 0.5 * (SELECT v FROM facts WHERE k = 'app_cm_per_disc_h225'),
       'dialihkan x 50% imbal hasil historis App Payday (konservatif)';
INSERT INTO facts SELECT 'scn_promo_total_low_rp', -(SELECT v FROM facts WHERE k = 'p_h225_cm_mega'), 'hentikan Mega Sale: hindari CM negatif H2 2025';
INSERT INTO facts SELECT 'scn_promo_total_high_rp', -(SELECT v FROM facts WHERE k = 'p_h225_cm_mega') + (SELECT v FROM facts WHERE k = 'scn_realokasi_gain_rp'), 'hentikan Mega Sale + realokasi ke App Payday';
INSERT INTO facts SELECT 'scn_promo_pt_cm', 100.0 * (SELECT v FROM facts WHERE k = 'scn_promo_total_high_rp') / (SELECT v FROM facts WHERE k = 'net_h126'), 'skenario tinggi / net_h126 (proksi Net Sales semester)';

-- ====================================================== I5 toko
CREATE TEMP TABLE sp AS
SELECT store_code, region, CASE WHEN month_start < DATE '2026-01-01' THEN 'fy25' ELSE 'h126' END AS per,
       sum(net_sales_idr)::DOUBLE AS net, sum(net_sales_ex_b2b_idr)::DOUBLE AS net_xb, sum(store_target_idr)::DOUBLE AS tgt
FROM metrics.v_store_performance_monthly GROUP BY ALL;
CREATE TEMP TABLE yo AS
SELECT store_code, sum(net_sales_idr) FILTER (WHERE NOT is_b2b_bulk AND month_start >= DATE '2026-01-01')::DOUBLE AS h26,
       sum(net_sales_idr) FILTER (WHERE NOT is_b2b_bulk AND month_start BETWEEN DATE '2025-01-01' AND DATE '2025-06-01')::DOUBLE AS h25
FROM metrics.v_sales_monthly WHERE channel_name = 'Store' GROUP BY 1;
INSERT INTO facts SELECT 's_' || lower(replace(store_code, '-', '')) || '_ach_' || per, 100.0 * net / tgt, 'metrics.v_store_performance_monthly (target ALOKASI)' FROM sp GROUP BY store_code, per, net, tgt;
INSERT INTO facts SELECT 's_' || lower(replace(store_code, '-', '')) || '_gap_' || per, net - tgt, 'metrics.v_store_performance_monthly' FROM sp;
INSERT INTO facts SELECT 's_' || lower(replace(store_code, '-', '')) || '_yoy', 100.0 * (h26 / h25 - 1), 'metrics.v_sales_monthly: H1 2026 vs H1 2025, tanpa B2B' FROM yo;
INSERT INTO facts SELECT 's_sby01_ach_h126_xb2b', 100.0 * net_xb / tgt, 'metrics.v_store_performance_monthly: tanpa B2B' FROM sp WHERE store_code = 'SBY-01' AND per = 'h126';
INSERT INTO facts SELECT 's_prog4_gap_h126', sum(net - tgt), 'MDN-01 + SBY-02 + MLG-01 + SOL-01, H1 2026' FROM sp WHERE per = 'h126' AND store_code IN ('MDN-01', 'SBY-02', 'MLG-01', 'SOL-01');
INSERT INTO facts SELECT 's_prog4_cm_full_rp', -(SELECT v FROM facts WHERE k = 's_prog4_gap_h126') * (SELECT v FROM facts WHERE k = 'cmch_st_h126') / 100.0, 'gap 4 toko x CM Store H1 2026 (batas atas)';
INSERT INTO facts SELECT 's_prog4_cm_half_rp', 0.5 * (SELECT v FROM facts WHERE k = 's_prog4_cm_full_rp'), 'skenario 50% gap tertutup';
INSERT INTO facts SELECT 'store_yoy_median', median(100.0 * (h26 / h25 - 1)), 'median YoY seluruh toko Store (tanpa B2B)' FROM yo WHERE h25 > 0;
INSERT INTO facts SELECT 'store_yoy_total', 100.0 * (sum(h26) / sum(h25) - 1), 'YoY total Store (tanpa B2B)' FROM yo;

-- estimasi penjualan hilang/tertahan (indikatif): hari x rata-rata harian (hari SUCCESS, tanpa B2B) pada jendela sebelum dan sesudah
CREATE TEMP TABLE sd AS
SELECT sy.store_code, sy.business_date AS d, coalesce(sum(f.net_sales) FILTER (WHERE NOT f.is_b2b_bulk), 0) AS net
FROM dw.fact_pos_sync sy LEFT JOIN dw.dim_store st ON st.store_key = sy.store_key
LEFT JOIN dw.fact_sales f ON f.source_system = 'POS' AND f.sale_date = sy.business_date AND f.store_key = sy.store_key
WHERE sy.sync_status = 'SUCCESS' GROUP BY 1, 2;
INSERT INTO facts SELECT 'sby01_closed_days', count(*), 'dw.fact_pos_sync (STORE_CLOSED)' FROM dw.fact_pos_sync WHERE store_code = 'SBY-01' AND sync_status = 'STORE_CLOSED';
INSERT INTO facts SELECT 'sby01_est_lost_rp', round(49 * avg(net)), 'ESTIMASI: 49 hari x rata-rata harian 8 minggu sebelum+sesudah'
FROM sd WHERE store_code = 'SBY-01' AND (d BETWEEN DATE '2025-06-09' AND DATE '2025-08-03' OR d BETWEEN DATE '2025-09-22' AND DATE '2025-11-16');
INSERT INTO facts SELECT 'bdg02_failed_days', count(*), 'dw.fact_pos_sync (FAILED)' FROM dw.fact_pos_sync WHERE store_code = 'BDG-02' AND sync_status = 'FAILED';
INSERT INTO facts SELECT 'bdg02_est_lost_rp', round(7 * avg(net)), 'ESTIMASI: 7 hari x rata-rata harian 4 minggu sebelum+sesudah'
FROM sd WHERE store_code = 'BDG-02' AND (d BETWEEN DATE '2025-10-06' AND DATE '2025-11-02' OR d BETWEEN DATE '2025-11-10' AND DATE '2025-12-07');
INSERT INTO facts SELECT 'sby01_net_' || k, v, 'metrics.v_sales_monthly' FROM (
  SELECT 'jul25' AS k, sum(net_sales_idr)::DOUBLE AS v FROM m WHERE store_code = 'SBY-01' AND month_start = DATE '2025-07-01'
  UNION ALL SELECT 'aug25', sum(net_sales_idr) FROM m WHERE store_code = 'SBY-01' AND month_start = DATE '2025-08-01'
  UNION ALL SELECT 'sep25', sum(net_sales_idr) FROM m WHERE store_code = 'SBY-01' AND month_start = DATE '2025-09-01'
  UNION ALL SELECT 'oct25', sum(net_sales_idr) FROM m WHERE store_code = 'SBY-01' AND month_start = DATE '2025-10-01');
INSERT INTO facts SELECT 'bdg02_net_nov25', sum(net_sales_idr), 'metrics.v_sales_monthly' FROM m WHERE store_code = 'BDG-02' AND month_start = DATE '2025-11-01';
INSERT INTO facts SELECT 'online_yoy_' || lower(c), 100.0 * (sum(net) FILTER (WHERE sale_date >= DATE '2026-01-01') / sum(net) FILTER (WHERE sale_date BETWEEN DATE '2025-01-01' AND DATE '2025-06-30') - 1),
       'stg.online_line (ship_city), H1 2026 vs H1 2025' FROM (SELECT ship_city AS c, net, sale_date FROM stg.online_line WHERE disposition = 'FACT' AND ship_city IN ('Medan', 'Palembang')) GROUP BY c;
INSERT INTO facts SELECT 'online_yoy_all', 100.0 * (sum(net) FILTER (WHERE sale_date >= DATE '2026-01-01') / sum(net) FILTER (WHERE sale_date BETWEEN DATE '2025-01-01' AND DATE '2025-06-30') - 1), 'stg.online_line, seluruh kota'
FROM stg.online_line WHERE disposition = 'FACT';

-- koreksi region BGR-01 (bukti measurement artifact)
CREATE TEMP TABLE rg AS
SELECT CASE WHEN f.sale_date BETWEEN DATE '2025-01-01' AND DATE '2025-06-30' THEN 'h125' ELSE 'h225' END AS per, f.region_asof AS a, f.region_target_basis AS b, f.net_sales
FROM dw.fact_sales f WHERE f.channel_key = 1 AND f.sale_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';
CREATE TEMP TABLE rt AS
SELECT CASE WHEN month_start <= DATE '2025-06-01' THEN 'h125' ELSE 'h225' END AS per, region, sum(target_net_sales) AS tgt
FROM dw.fact_target WHERE target_scope = 'REGION' AND month_start BETWEEN DATE '2025-01-01' AND DATE '2025-12-01' GROUP BY 1, 2;
INSERT INTO facts SELECT 'reg_' || CASE region WHEN 'Jawa Barat' THEN 'jb' ELSE 'jkt' END || '_' || per || '_asof',
       100.0 * (SELECT sum(net_sales) FROM rg WHERE rg.per = rt.per AND rg.a = rt.region) / tgt, 'dw.fact_sales.region_asof vs dw.fact_target' FROM rt WHERE region IN ('Jawa Barat', 'Jabodetabek');
INSERT INTO facts SELECT 'reg_' || CASE region WHEN 'Jawa Barat' THEN 'jb' ELSE 'jkt' END || '_' || per || '_basis',
       100.0 * (SELECT sum(net_sales) FROM rg WHERE rg.per = rt.per AND rg.b = rt.region) / tgt, 'dw.fact_sales.region_target_basis vs dw.fact_target' FROM rt WHERE region IN ('Jawa Barat', 'Jabodetabek');
INSERT INTO facts SELECT 'bgr01_h225_rp', sum(net_sales_idr), 'metrics.v_sales_monthly (BGR-01 Jul-Des 2025)' FROM m WHERE store_code = 'BGR-01' AND month_start BETWEEN DATE '2025-07-01' AND DATE '2025-12-01';
INSERT INTO facts SELECT 'tgt_jb_' || strftime(month_start, '%Y%m'), target_net_sales_idr::DOUBLE, 'metrics.v_target_achievement' FROM metrics.v_target_achievement
WHERE channel_name = 'Store' AND region = 'Jawa Barat' AND month_start IN (DATE '2025-06-01', DATE '2025-07-01', DATE '2025-12-01', DATE '2026-01-01');

-- ====================================================== I6 retur
CREATE TEMP TABLE rr AS SELECT * FROM metrics.v_return_rate_monthly;
INSERT INTO facts SELECT 'fashion_refund_rp', sum(refund_idr) FILTER (WHERE category = 'Fashion')::DOUBLE, 'metrics.v_return_rate_monthly' FROM rr;
INSERT INTO facts SELECT 'total_refund_rp', sum(refund_idr)::DOUBLE, 'metrics.v_return_rate_monthly' FROM rr;
INSERT INTO facts SELECT 'fashion_refund_share_pct', 100.0 * sum(refund_idr) FILTER (WHERE category = 'Fashion') / sum(refund_idr), 'metrics.v_return_rate_monthly' FROM rr;
INSERT INTO facts SELECT 'rr_fashion_online_pct', 100.0 * sum(refund_idr) FILTER (WHERE category = 'Fashion' AND channel_name <> 'Store') / sum(net_sales_idr) FILTER (WHERE category = 'Fashion' AND channel_name <> 'Store'), 'metrics.v_return_rate_monthly (Fashion, online)' FROM rr;
INSERT INTO facts SELECT 'rr_fashion_store_pct', 100.0 * sum(refund_idr) FILTER (WHERE category = 'Fashion' AND channel_name = 'Store') / sum(net_sales_idr) FILTER (WHERE category = 'Fashion' AND channel_name = 'Store'), 'metrics.v_return_rate_monthly (Fashion, Store)' FROM rr;
INSERT INTO facts SELECT 'rr_other_online_pct', 100.0 * sum(refund_idr) FILTER (WHERE category <> 'Fashion' AND channel_name <> 'Store') / sum(net_sales_idr) FILTER (WHERE category <> 'Fashion' AND channel_name <> 'Store'), 'metrics.v_return_rate_monthly (non-Fashion, online)' FROM rr;
INSERT INTO facts SELECT 'rr_other_store_pct', 100.0 * sum(refund_idr) FILTER (WHERE category <> 'Fashion' AND channel_name = 'Store') / sum(net_sales_idr) FILTER (WHERE category <> 'Fashion' AND channel_name = 'Store'), 'metrics.v_return_rate_monthly (non-Fashion, Store)' FROM rr;
INSERT INTO facts SELECT 'fr_' || r, 100.0 * sum(refund_idr) FILTER (WHERE return_reason = reason) / sum(refund_idr), 'metrics.v_return_reason_monthly (Fashion)'
FROM metrics.v_return_reason_monthly, (VALUES ('ukuran', 'Ukuran tidak sesuai'), ('warna', 'Warna berbeda dari foto'), ('berubah', 'Berubah pikiran'), ('cacat', 'Barang cacat')) t(r, reason)
WHERE category = 'Fashion' GROUP BY r;
INSERT INTO facts SELECT 'rr_total_pct', 100.0 * sum(refund_idr) / sum(net_sales_idr), 'metrics.v_return_rate_monthly' FROM rr;
INSERT INTO facts SELECT 'rr_' || ch || '_total_pct', v, 'metrics.v_return_rate_monthly' FROM (
  SELECT CASE channel_name WHEN 'Store' THEN 'st' WHEN 'Website' THEN 'wb' WHEN 'Marketplace' THEN 'mp' ELSE 'ap' END AS ch, 100.0 * sum(refund_idr) / sum(net_sales_idr) AS v FROM rr GROUP BY channel_name);
INSERT INTO facts SELECT 'fashion_online_net_rp', sum(net_sales_idr) FILTER (WHERE category = 'Fashion' AND channel_name <> 'Store')::DOUBLE, 'metrics.v_return_rate_monthly' FROM rr;
INSERT INTO facts SELECT 'fashion_online_refund_rp', sum(refund_idr) FILTER (WHERE category = 'Fashion' AND channel_name <> 'Store')::DOUBLE, 'metrics.v_return_rate_monthly' FROM rr;
INSERT INTO facts SELECT 'fashion_excess_refund_year_rp',
       (SELECT v FROM facts WHERE k = 'fashion_online_net_rp') * ((SELECT v FROM facts WHERE k = 'rr_fashion_online_pct') - (SELECT v FROM facts WHERE k = 'rr_fashion_store_pct')) / 100.0 / 2.5,
       'net Fashion online x (RR online - RR Store) / 2,5 tahun';
INSERT INTO facts SELECT 'ukuran_share_fashion_pct', 100.0 * sum(refund_idr) FILTER (WHERE return_reason = 'Ukuran tidak sesuai' AND category = 'Fashion') / sum(refund_idr) FILTER (WHERE category = 'Fashion'), 'metrics.v_return_reason_monthly' FROM metrics.v_return_reason_monthly;
INSERT INTO facts SELECT 'ukuran_only_fashion', count(DISTINCT category) FILTER (WHERE return_reason = 'Ukuran tidak sesuai'), 'metrics.v_return_reason_monthly (jumlah kategori yang memiliki alasan ukuran)' FROM metrics.v_return_reason_monthly;
INSERT INTO facts SELECT 'cancel_rate_pct', 100.0 * sum(cancelled_net_sales_idr) / (sum(valid_net_sales_idr) FILTER (WHERE channel_name <> 'Store') + sum(cancelled_net_sales_idr)), 'metrics.v_cancellation_void_monthly' FROM metrics.v_cancellation_void_monthly;

-- ====================================================== anomali dan data
INSERT INTO facts SELECT 'b2b_rows', count(*), 'dw.fact_sales (is_b2b_bulk)' FROM dw.fact_sales WHERE is_b2b_bulk;
INSERT INTO facts SELECT 'b2b_rp', sum(net_sales), 'dw.fact_sales (is_b2b_bulk)' FROM dw.fact_sales WHERE is_b2b_bulk;
INSERT INTO facts SELECT 'trn99_rows', sum(n_copies), 'stg.pos_line (REJECT_STORE_NOT_IN_MASTER)' FROM stg.pos_line WHERE disposition = 'REJECT_STORE_NOT_IN_MASTER';
INSERT INTO facts SELECT 'sync_failed_days', failed_store_days, 'metrics.v_data_freshness' FROM metrics.v_data_freshness;
INSERT INTO facts SELECT 'data_through_ord', year(data_through_date) * 10000 + month(data_through_date) * 100 + day(data_through_date), 'metrics.v_data_freshness' FROM metrics.v_data_freshness;
INSERT INTO facts SELECT 'net_total', sum(net_sales)::DOUBLE, 'dw.fact_sales' FROM dw.fact_sales;

-- ====================================================== turunan aritmetika (agar tiap angka di brief punya sumber)
INSERT INTO facts SELECT 'cm_gap_st_mp', (SELECT v FROM facts WHERE k = 'cmch_st_h126') - (SELECT v FROM facts WHERE k = 'cmch_mp_h126'), 'CM% Store - CM% Marketplace, H1 2026 (pt = sen per Rupiah)';
INSERT INTO facts SELECT 'web_mig_still_pct', 100.0 * (SELECT v FROM facts WHERE k = 'web_mig_still') / (SELECT v FROM facts WHERE k = 'web_mig_total'), 'web_mig_still / web_mig_total';
INSERT INTO facts SELECT 'p_gm_clr_year', (SELECT v FROM facts WHERE k = 'p_gm_clr') / (SELECT v FROM facts WHERE k = 'p_n_clr'), 'p_gm_clr / jumlah kode (satu per tahun)';
INSERT INTO facts SELECT 's_mdn01_half_net_rp', -0.5 * (SELECT v FROM facts WHERE k = 's_mdn01_gap_h126'), '50% dari gap H1 2026 MDN-01';

SELECT k, v, src FROM facts ORDER BY k;
