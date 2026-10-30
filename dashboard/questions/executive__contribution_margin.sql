-- name: Contribution Margin
-- dashboard: kirana
-- tab: executive
-- pos: row=4 col=12 w=4 h=3
-- display: scalar
-- filter: period = v_sales_monthly.month_start
-- filter: channel = v_sales_monthly.channel_name
-- filter: region = v_sales_monthly.region_target_basis
-- filter: category = v_sales_monthly.category
-- viz: {"scalar.field":"contribution_margin_pct","column_settings":{"[\"name\", \"contribution_margin_pct\"]":{"prefix":"","suffix":" %","decimals":2}}}
-- note: Contribution Margin = Gross Margin dikurangi biaya channel (tarif as-of).
SELECT round(100.0 * sum(contribution_margin_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS contribution_margin_pct
FROM metrics.v_sales_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
