-- Analisis dampak keputusan SCD (Task 2): bukan bagian build; dijalankan setelah kirana.duckdb selesai dibangun.
--   duckdb -readonly kirana.duckdb -markdown < sql/analysis/scd_impact.sql
-- (a) HPP as-of tanggal transaksi vs HPP terkini (products.current_unit_cost)
-- (b) Region as-of tanggal transaksi vs region saat ini, pada pencapaian terhadap target Store per region

-- ---------- (a) HPP ----------
CREATE OR REPLACE TEMP TABLE sales_cost AS
SELECT f.sale_date, f.channel_key, f.net_sales, f.cogs AS cogs_asof, f.qty * p.current_unit_cost AS cogs_current
FROM dw.fact_sales f JOIN dw.dim_product pr USING (product_key) JOIN stg.product p ON p.sku = pr.sku;

SELECT 'HPP: gross margin as-of vs HPP terkini' AS analisis,
       CASE WHEN year(sale_date) = 2026 THEN 'H1 2026' ELSE 'FY' || year(sale_date) END AS periode,
       sum(net_sales) AS net_sales,
       round(100.0 * (sum(net_sales) - sum(cogs_asof)) / sum(net_sales), 2) AS gm_pct_asof,
       round(100.0 * (sum(net_sales) - sum(cogs_current)) / sum(net_sales), 2) AS gm_pct_hpp_terkini,
       round(100.0 * (sum(net_sales) - sum(cogs_current)) / sum(net_sales) - 100.0 * (sum(net_sales) - sum(cogs_asof)) / sum(net_sales), 2) AS selisih_pt,
       sum(cogs_current) - sum(cogs_asof) AS selisih_cogs_rp
FROM sales_cost GROUP BY year(sale_date) ORDER BY 2;

SELECT 'HPP: baris yang HPP-nya berbeda' AS analisis, count(*) FILTER (WHERE cogs_asof <> cogs_current) AS baris_beda, count(*) AS baris_total,
       round(100.0 * count(*) FILTER (WHERE cogs_asof <> cogs_current) / count(*), 2) AS pct_baris
FROM sales_cost;

-- ---------- (b) Region: tiga pemetaan untuk achievement Store terhadap target per region ----------
--   A = region saat transaksi (region_asof)    B = peta awal tahun target (region_target_basis, DIPAKAI)    C = region saat ini (region_current)
CREATE OR REPLACE TEMP TABLE store_period AS
SELECT CASE WHEN f.sale_date BETWEEN DATE '2025-01-01' AND DATE '2025-06-30' THEN 'H1 2025'
            WHEN f.sale_date BETWEEN DATE '2025-07-01' AND DATE '2025-12-31' THEN 'H2 2025'
            WHEN f.sale_date BETWEEN DATE '2026-01-01' AND DATE '2026-06-30' THEN 'H1 2026' END AS periode,
       f.region_asof, f.region_target_basis, f.region_current, f.net_sales
FROM dw.fact_sales f WHERE f.channel_key = 1;

CREATE OR REPLACE TEMP TABLE target_period AS
SELECT CASE WHEN month_start BETWEEN DATE '2025-01-01' AND DATE '2025-06-01' THEN 'H1 2025'
            WHEN month_start BETWEEN DATE '2025-07-01' AND DATE '2025-12-01' THEN 'H2 2025' ELSE 'H1 2026' END AS periode,
       region, sum(target_net_sales) AS target
FROM dw.fact_target WHERE target_scope = 'REGION' GROUP BY 1, 2;

-- Target tidak disesuaikan saat BGR-01 pindah (1 Jul 2025): target Jawa Barat/Jabodetabek per bulan sekitar Jun-Jul 2025 dan Des 2025-Jan 2026
SELECT 'Target region sekitar pindah BGR-01 (Rp juta)' AS analisis, strftime(month_start, '%Y-%m') AS bulan,
       round(sum(target_net_sales_idr) FILTER (WHERE region = 'Jawa Barat') / 1e6) AS target_jawa_barat,
       round(sum(target_net_sales_idr) FILTER (WHERE region = 'Jabodetabek') / 1e6) AS target_jabodetabek
FROM metrics.v_target_achievement WHERE channel_name = 'Store' AND month_start IN (DATE '2025-06-01', DATE '2025-07-01', DATE '2025-12-01', DATE '2026-01-01')
GROUP BY month_start ORDER BY month_start;

-- Achievement per semester di tiga pemetaan: pemetaan yang benar tidak memunculkan lompatan di titik pindah (H1 -> H2 2025)
SELECT 'Region: achievement per semester' AS analisis, t.periode, t.region, t.target,
       round(100.0 * a.net_sales / t.target, 1) AS ach_A_saat_transaksi,
       round(100.0 * b.net_sales / t.target, 1) AS ach_B_dasar_target,
       round(100.0 * c.net_sales / t.target, 1) AS ach_C_saat_ini
FROM target_period t
LEFT JOIN (SELECT periode, region_asof AS region, sum(net_sales) AS net_sales FROM store_period WHERE periode IS NOT NULL GROUP BY 1, 2) a ON a.periode = t.periode AND a.region = t.region
LEFT JOIN (SELECT periode, region_target_basis AS region, sum(net_sales) AS net_sales FROM store_period WHERE periode IS NOT NULL GROUP BY 1, 2) b ON b.periode = t.periode AND b.region = t.region
LEFT JOIN (SELECT periode, region_current AS region, sum(net_sales) AS net_sales FROM store_period WHERE periode IS NOT NULL GROUP BY 1, 2) c ON c.periode = t.periode AND c.region = t.region
WHERE t.region IN ('Jawa Barat', 'Jabodetabek') ORDER BY t.region, t.periode;

SELECT 'Region: achievement FY2025' AS analisis, t.region,
       round(100.0 * sum(a.net_sales) / sum(t.target), 1) AS ach_A_saat_transaksi, round(100.0 * sum(b.net_sales) / sum(t.target), 1) AS ach_B_dasar_target,
       round(100.0 * sum(c.net_sales) / sum(t.target), 1) AS ach_C_saat_ini
FROM target_period t
LEFT JOIN (SELECT periode, region_asof AS region, sum(net_sales) AS net_sales FROM store_period WHERE periode IS NOT NULL GROUP BY 1, 2) a ON a.periode = t.periode AND a.region = t.region
LEFT JOIN (SELECT periode, region_target_basis AS region, sum(net_sales) AS net_sales FROM store_period WHERE periode IS NOT NULL GROUP BY 1, 2) b ON b.periode = t.periode AND b.region = t.region
LEFT JOIN (SELECT periode, region_current AS region, sum(net_sales) AS net_sales FROM store_period WHERE periode IS NOT NULL GROUP BY 1, 2) c ON c.periode = t.periode AND c.region = t.region
WHERE t.periode IN ('H1 2025', 'H2 2025') AND t.region IN ('Jawa Barat', 'Jabodetabek') GROUP BY t.region ORDER BY t.region;

SELECT 'Region: penjualan BGR-01 yang berbeda region antar pemetaan' AS analisis, count(*) AS baris, sum(f.net_sales) AS net_sales_rp,
       sum(f.net_sales) FILTER (WHERE f.sale_date BETWEEN DATE '2025-07-01' AND DATE '2025-12-31') AS net_sales_h2_2025_rp
FROM dw.fact_sales f WHERE f.region_asof <> f.region_target_basis OR f.region_asof <> f.region_current;
