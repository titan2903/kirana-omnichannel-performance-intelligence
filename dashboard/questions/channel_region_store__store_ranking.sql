-- name: Kinerja per toko (klik toko untuk detail)
-- dashboard: kirana
-- tab: channel_region_store
-- pos: row=11 col=0 w=24 h=13
-- display: table
-- filter: period = v_store_performance_monthly.month_start
-- filter: region = v_store_performance_monthly.region
-- viz: {"column_settings":{"[\"name\", \"store_code\"]":{"column_title":"Toko"}},"table.column_formatting":[{"columns":["Status"],"type":"single","operator":"=","value":"Hijau","color":"#0ca30c","highlight_row":false,"id":1},{"columns":["Status"],"type":"single","operator":"=","value":"Kuning","color":"#fab219","highlight_row":false,"id":2},{"columns":["Status"],"type":"single","operator":"=","value":"Merah","color":"#d03b3b","highlight_row":false,"id":3},{"columns":["Kelengkapan data"],"type":"single","operator":"starts-with","value":"Tidak lengkap","color":"#d03b3b","highlight_row":false,"id":4},{"columns":["Kelengkapan data"],"type":"single","operator":"starts-with","value":"Toko tutup","color":"#fab219","highlight_row":false,"id":5}]}
-- click: {"type":"link","linkType":"dashboard","targetId":"{{detail_dashboard_id}}","parameterMapping":{"store":{"id":"store","source":{"type":"column","id":"store_code","name":"store_code"},"target":{"type":"parameter","id":"store"}}}}
-- note: Target toko = ALOKASI (asumsi): target region x pangsa penjualan tahun lalu; bukan target resmi FP&A. Periode tanpa target tidak ditampilkan.
SELECT store_code AS store_code, arg_max(region, month_start) AS "Region",
       sum(net_sales_idr) AS "Net Sales (Rp)", round(sum(store_target_idr))::BIGINT AS "Target alokasi (Rp)", achievement_pct AS "Achievement (%)",
       CASE WHEN achievement_pct >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Hijau') THEN 'Hijau' WHEN achievement_pct >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Kuning') THEN 'Kuning' ELSE 'Merah' END AS "Status",
       CASE WHEN sum(failed_days) > 0 THEN 'Tidak lengkap: sync gagal ' || sum(failed_days)::VARCHAR || ' hari'
            WHEN sum(closed_days) > 0 THEN 'Toko tutup ' || sum(closed_days)::VARCHAR || ' hari'
            ELSE 'Lengkap' END AS "Kelengkapan data"
FROM (
  SELECT store_code, month_start, region, net_sales_idr, store_target_idr, failed_days, closed_days,
         round(100.0 * sum(net_sales_idr) OVER (PARTITION BY store_code) / NULLIF(sum(store_target_idr) OVER (PARTITION BY store_code), 0), 1) AS achievement_pct
  FROM metrics.v_store_performance_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{region}}]]
) t
GROUP BY store_code, achievement_pct
ORDER BY achievement_pct
