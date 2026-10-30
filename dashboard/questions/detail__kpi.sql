-- name: Ringkasan toko
-- dashboard: detail_toko
-- tab: detail
-- pos: row=1 col=0 w=24 h=3
-- display: table
-- filter: period = v_store_performance_monthly.month_start
-- filter: store = v_store_performance_monthly.store_code
-- viz: {"table.column_formatting":[{"columns":["Status"],"type":"single","operator":"=","value":"Hijau","color":"#0ca30c","highlight_row":false,"id":1},{"columns":["Status"],"type":"single","operator":"=","value":"Kuning","color":"#fab219","highlight_row":false,"id":2},{"columns":["Status"],"type":"single","operator":"=","value":"Merah","color":"#d03b3b","highlight_row":false,"id":3}]}
-- note: Target toko = ALOKASI (asumsi), bukan target resmi.
SELECT store_code AS "Toko", arg_max(region, month_start) AS "Region", sum(net_sales_idr) AS "Net Sales (Rp)",
       round(sum(store_target_idr))::BIGINT AS "Target alokasi (Rp)",
       round(100.0 * sum(net_sales_idr) / NULLIF(sum(store_target_idr), 0), 1) AS "Achievement (%)",
       CASE WHEN round(100.0 * sum(net_sales_idr) / NULLIF(sum(store_target_idr), 0), 1) >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Hijau') THEN 'Hijau' WHEN round(100.0 * sum(net_sales_idr) / NULLIF(sum(store_target_idr), 0), 1) >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Kuning') THEN 'Kuning' ELSE 'Merah' END AS "Status",
       sum(failed_days) AS "Hari sync gagal", sum(closed_days) AS "Hari tutup"
FROM metrics.v_store_performance_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{store}}]]
GROUP BY store_code
ORDER BY store_code
