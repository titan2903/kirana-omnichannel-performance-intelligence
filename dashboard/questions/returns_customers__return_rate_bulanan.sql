-- name: Return Rate bulanan per channel (%)
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=13 col=0 w=12 h=6
-- display: line
-- filter: period = v_return_rate_monthly.month_start
-- filter: channel = v_return_rate_monthly.channel_name
-- filter: region = v_return_rate_monthly.region_target_basis
-- filter: category = v_return_rate_monthly.category
-- viz: {"graph.dimensions":["month_start","channel"],"graph.metrics":["return_rate_pct"],"series_settings":{"Store":{"color":"#2a78d6"},"Marketplace":{"color":"#eb6834"},"Mobile App":{"color":"#1baf7a"},"Website":{"color":"#eda100"}},"graph.y_axis.title_text":"% dari Net Sales","graph.x_axis.title_text":"Bulan"}
SELECT month_start, channel_name AS channel, round(100.0 * sum(refund_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS return_rate_pct
FROM metrics.v_return_rate_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
GROUP BY month_start, channel_name
ORDER BY month_start, channel_name
