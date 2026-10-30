-- name: Gross dan Contribution Margin bulanan (%)
-- dashboard: kirana
-- tab: executive
-- pos: row=18 col=0 w=12 h=5
-- display: line
-- filter: period = v_sales_monthly.month_start
-- filter: channel = v_sales_monthly.channel_name
-- filter: region = v_sales_monthly.region_target_basis
-- filter: category = v_sales_monthly.category
-- viz: {"graph.dimensions":["month_start"],"graph.metrics":["gross_margin","contribution_margin"],"series_settings":{"gross_margin":{"color":"#2a78d6","title":"Gross Margin"},"contribution_margin":{"color":"#eb6834","title":"Contribution Margin"}},"graph.y_axis.title_text":"% dari Net Sales","graph.x_axis.title_text":"Bulan","graph.y_axis.auto_range":true}
SELECT month_start,
       round(100.0 * sum(gross_margin_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS gross_margin,
       round(100.0 * sum(contribution_margin_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS contribution_margin
FROM metrics.v_sales_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
GROUP BY month_start
ORDER BY month_start
