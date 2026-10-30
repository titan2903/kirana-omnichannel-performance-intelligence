-- name: Net Sales bulanan per channel (Rp miliar)
-- dashboard: kirana
-- tab: executive
-- pos: row=12 col=12 w=12 h=6
-- display: bar
-- filter: period = v_sales_monthly.month_start
-- filter: channel = v_sales_monthly.channel_name
-- filter: region = v_sales_monthly.region_target_basis
-- filter: category = v_sales_monthly.category
-- viz: {"graph.dimensions":["month_start","channel"],"graph.metrics":["net_sales_miliar"],"stackable.stack_type":"stacked","series_settings":{"Store":{"color":"#2a78d6"},"Marketplace":{"color":"#eb6834"},"Mobile App":{"color":"#1baf7a"},"Website":{"color":"#eda100"}},"graph.y_axis.title_text":"Rp miliar","graph.x_axis.title_text":"Bulan"}
SELECT month_start, channel_name AS channel, round(sum(net_sales_idr) / 1e9, 2) AS net_sales_miliar
FROM metrics.v_sales_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
GROUP BY month_start, channel_name
ORDER BY month_start, channel_name
