-- name: Contribution Margin bulanan per channel (%)
-- dashboard: kirana
-- tab: margin_promo
-- pos: row=10 col=0 w=12 h=6
-- display: line
-- filter: period = v_sales_monthly.month_start
-- filter: channel = v_sales_monthly.channel_name
-- filter: region = v_sales_monthly.region_target_basis
-- filter: category = v_sales_monthly.category
-- viz: {"graph.dimensions":["month_start","channel"],"graph.metrics":["contribution_margin_pct"],"series_settings":{"Store":{"color":"#2a78d6"},"Marketplace":{"color":"#eb6834"},"Mobile App":{"color":"#1baf7a"},"Website":{"color":"#eda100"}},"graph.y_axis.title_text":"% dari Net Sales","graph.x_axis.title_text":"Bulan"}
SELECT month_start, channel_name AS channel, round(100.0 * sum(contribution_margin_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS contribution_margin_pct
FROM metrics.v_sales_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
GROUP BY month_start, channel_name
ORDER BY month_start, channel_name
