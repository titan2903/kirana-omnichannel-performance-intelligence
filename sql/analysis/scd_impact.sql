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

-- ---------- (b) Region ----------
CREATE OR REPLACE TEMP TABLE store_period AS
SELECT CASE WHEN f.sale_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31' THEN 'FY2025'
            WHEN f.sale_date BETWEEN DATE '2026-01-01' AND DATE '2026-06-30' THEN 'H1 2026' END AS periode,
       f.region_asof, f.region_current, f.net_sales
FROM dw.fact_sales f WHERE f.channel_key = 1;

CREATE OR REPLACE TEMP TABLE target_period AS
SELECT CASE WHEN month_start BETWEEN DATE '2025-01-01' AND DATE '2025-12-01' THEN 'FY2025' ELSE 'H1 2026' END AS periode,
       region, sum(target_net_sales) AS target
FROM dw.fact_target WHERE target_scope = 'REGION' GROUP BY 1, 2;

SELECT 'Region: achievement Store per region' AS analisis, t.periode, t.region, t.target,
       a.net_sales AS aktual_asof, round(100.0 * a.net_sales / t.target, 1) AS ach_pct_asof,
       c.net_sales AS aktual_region_saat_ini, round(100.0 * c.net_sales / t.target, 1) AS ach_pct_region_saat_ini,
       round(100.0 * c.net_sales / t.target - 100.0 * a.net_sales / t.target, 1) AS selisih_pt,
       c.net_sales - a.net_sales AS selisih_rp
FROM target_period t
LEFT JOIN (SELECT periode, region_asof AS region, sum(net_sales) AS net_sales FROM store_period WHERE periode IS NOT NULL GROUP BY 1, 2) a
  ON a.periode = t.periode AND a.region = t.region
LEFT JOIN (SELECT periode, region_current AS region, sum(net_sales) AS net_sales FROM store_period WHERE periode IS NOT NULL GROUP BY 1, 2) c
  ON c.periode = t.periode AND c.region = t.region
ORDER BY t.periode, t.region;

SELECT 'Region: penjualan toko yang berpindah region bila pakai region saat ini (saat ini hanya BGR-01)' AS analisis,
       string_agg(DISTINCT s.store_code, ', ') AS toko, count(*) AS baris, sum(f.net_sales) AS net_sales_rp, min(f.sale_date) AS dari, max(f.sale_date) AS sampai
FROM dw.fact_sales f JOIN dw.dim_store s USING (store_key) WHERE f.region_asof <> f.region_current;
