-- name: Return Rate per kategori (%)
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=7 col=8 w=8 h=6
-- display: row
-- filter: period = v_return_rate_monthly.month_start
-- filter: channel = v_return_rate_monthly.channel_name
-- filter: region = v_return_rate_monthly.region_target_basis
-- filter: category = v_return_rate_monthly.category
-- viz: {"graph.dimensions":["category"],"graph.metrics":["return_rate_pct"],"graph.show_values":true,"series_settings":{"return_rate_pct":{"color":"#2a78d6","title":"Return Rate (%)"}},"graph.x_axis.title_text":"% dari Net Sales","graph.y_axis.title_text":"Kategori"}
SELECT category, round(100.0 * sum(refund_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS return_rate_pct
FROM metrics.v_return_rate_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
GROUP BY category
ORDER BY return_rate_pct
