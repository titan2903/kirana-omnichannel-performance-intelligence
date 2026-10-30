-- name: Net Sales vs target alokasi bulanan (Rp juta)
-- dashboard: detail_toko
-- tab: detail
-- pos: row=4 col=0 w=12 h=6
-- display: line
-- filter: period = v_store_performance_monthly.month_start
-- filter: store = v_store_performance_monthly.store_code
-- viz: {"graph.dimensions":["month_start"],"graph.metrics":["aktual","target_alokasi"],"series_settings":{"aktual":{"color":"#2a78d6","title":"Aktual"},"target_alokasi":{"color":"#8a8a85","title":"Target alokasi","line.style":"dashed"}},"graph.y_axis.title_text":"Rp juta","graph.x_axis.title_text":"Bulan"}
SELECT month_start, round(sum(net_sales_idr) / 1e6, 1) AS aktual, round(sum(store_target_idr) / 1e6, 1) AS target_alokasi
FROM metrics.v_store_performance_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{store}}]]
GROUP BY month_start
ORDER BY month_start
