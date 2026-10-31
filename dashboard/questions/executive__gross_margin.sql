-- name: Gross Margin
-- dashboard: kirana
-- tab: executive
-- pos: row=4 col=8 w=4 h=3
-- display: scalar
-- filter: period = v_sales_monthly.month_start
-- filter: channel = v_sales_monthly.channel_name
-- filter: region = v_sales_monthly.region_target_basis
-- filter: category = v_sales_monthly.category
-- viz: {"scalar.field":"gross_margin_pct","column_settings":{"[\"name\", \"gross_margin_pct\"]":{"prefix":"","suffix":" %","decimals":1}}}
SELECT round(100.0 * sum(gross_margin_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS gross_margin_pct
FROM metrics.v_sales_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
