-- name: Dari Net Sales ke Contribution Margin per channel (% Net Sales)
-- dashboard: kirana
-- tab: margin_promo
-- pos: row=4 col=12 w=12 h=6
-- display: bar
-- filter: period = v_sales_monthly.month_start
-- filter: channel = v_sales_monthly.channel_name
-- filter: region = v_sales_monthly.region_target_basis
-- filter: category = v_sales_monthly.category
-- viz: {"graph.dimensions":["channel"],"graph.metrics":["cogs_pct","biaya_channel_pct","contribution_margin_pct"],"stackable.stack_type":"stacked","graph.show_values":true,"series_settings":{"cogs_pct":{"color":"#2a78d6","title":"HPP (COGS)"},"biaya_channel_pct":{"color":"#eb6834","title":"Biaya channel"},"contribution_margin_pct":{"color":"#1baf7a","title":"Contribution Margin"}},"graph.y_axis.title_text":"% dari Net Sales","graph.x_axis.title_text":"Channel","graph.show_stack_values":"series"}
-- note: Biaya channel: Marketplace 9,0% -> 11,5% sejak 1 Apr 2025.
SELECT channel_name AS channel,
       round(100.0 * sum(cogs_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS cogs_pct,
       round(100.0 * sum(channel_fee_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS biaya_channel_pct,
       round(100.0 * sum(contribution_margin_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS contribution_margin_pct
FROM metrics.v_sales_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
GROUP BY channel_name
ORDER BY channel_name
