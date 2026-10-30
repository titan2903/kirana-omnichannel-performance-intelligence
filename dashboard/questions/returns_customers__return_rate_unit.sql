-- name: Return Rate (unit)
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=4 col=6 w=6 h=3
-- display: scalar
-- filter: period = v_return_rate_monthly.month_start
-- filter: channel = v_return_rate_monthly.channel_name
-- filter: region = v_return_rate_monthly.region_target_basis
-- filter: category = v_return_rate_monthly.category
-- viz: {"scalar.field":"return_rate_unit_pct","column_settings":{"[\"name\", \"return_rate_unit_pct\"]":{"prefix":"","suffix":" %","decimals":2}}}
SELECT round(100.0 * sum(return_qty) / NULLIF(sum(qty_sold), 0), 2) AS return_rate_unit_pct
FROM metrics.v_return_rate_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
