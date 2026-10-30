-- name: Void Rate POS
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=4 col=18 w=6 h=3
-- display: scalar
-- filter: period = v_cancellation_void_monthly.month_start
-- filter: channel = v_cancellation_void_monthly.channel_name
-- filter: region = v_cancellation_void_monthly.region_target_basis
-- viz: {"scalar.field":"void_rate_pct","column_settings":{"[\"name\", \"void_rate_pct\"]":{"prefix":"","suffix":" %","decimals":3}}}
-- note: Rp baris asli yang di-void / (valid + di-void), channel Store.
SELECT round(100.0 * sum(voided_net_sales_idr) / NULLIF(sum(valid_net_sales_idr) + sum(voided_net_sales_idr), 0), 3) AS void_rate_pct
FROM metrics.v_cancellation_void_monthly
WHERE channel_name = 'Store'
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
