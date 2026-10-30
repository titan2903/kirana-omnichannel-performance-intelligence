-- name: Return Rate per channel (%)
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=7 col=0 w=8 h=6
-- display: bar
-- filter: period = v_return_rate_monthly.month_start
-- filter: channel = v_return_rate_monthly.channel_name
-- filter: region = v_return_rate_monthly.region_target_basis
-- filter: category = v_return_rate_monthly.category
-- viz: {"graph.dimensions":["channel"],"graph.metrics":["return_rate_pct"],"graph.show_values":true,"series_settings":{"return_rate_pct":{"color":"#2a78d6","title":"Return Rate (%)"}},"graph.y_axis.title_text":"% dari Net Sales","graph.x_axis.title_text":"Channel"}
SELECT channel_name AS channel, round(100.0 * sum(refund_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS return_rate_pct
FROM metrics.v_return_rate_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
GROUP BY channel_name
ORDER BY return_rate_pct DESC
