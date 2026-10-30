-- name: Return Rate (Rp)
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=4 col=0 w=6 h=3
-- display: scalar
-- filter: period = v_return_rate_monthly.month_start
-- filter: channel = v_return_rate_monthly.channel_name
-- filter: region = v_return_rate_monthly.region_target_basis
-- filter: category = v_return_rate_monthly.category
-- viz: {"scalar.field":"return_rate_pct","column_settings":{"[\"name\", \"return_rate_pct\"]":{"prefix":"","suffix":" %","decimals":2}}}
-- note: Return Rate = refund / Net Sales; retur menurut tanggal retur.
SELECT round(100.0 * sum(refund_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS return_rate_pct
FROM metrics.v_return_rate_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
