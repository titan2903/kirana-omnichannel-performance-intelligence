-- name: Net Sales per kategori (Rp juta)
-- dashboard: detail_toko
-- tab: detail
-- pos: row=4 col=12 w=12 h=6
-- display: row
-- filter: period = v_sales_monthly.month_start
-- filter: store = v_sales_monthly.store_code
-- viz: {"graph.dimensions":["category"],"graph.metrics":["net_sales_juta"],"graph.show_values":true,"series_settings":{"net_sales_juta":{"color":"#2a78d6","title":"Net Sales"}},"graph.x_axis.title_text":"Rp juta","graph.y_axis.title_text":"Kategori"}
SELECT category, round(sum(net_sales_idr) / 1e6, 1) AS net_sales_juta
FROM metrics.v_sales_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{store}}]]
GROUP BY category
ORDER BY net_sales_juta
