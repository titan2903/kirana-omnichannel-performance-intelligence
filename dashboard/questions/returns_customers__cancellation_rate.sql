-- name: Cancellation Rate online
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=4 col=12 w=6 h=3
-- display: scalar
-- filter: period = v_cancellation_void_monthly.month_start
-- filter: channel = v_cancellation_void_monthly.channel_name
-- filter: region = v_cancellation_void_monthly.region_target_basis
-- viz: {"scalar.field":"cancellation_rate_pct","column_settings":{"[\"name\", \"cancellation_rate_pct\"]":{"prefix":"","suffix":" %","decimals":2}}}
-- note: Rp order CANCELLED / (COMPLETED + CANCELLED), channel online.
SELECT round(100.0 * sum(cancelled_net_sales_idr) / NULLIF(sum(valid_net_sales_idr) + sum(cancelled_net_sales_idr), 0), 2) AS cancellation_rate_pct
FROM metrics.v_cancellation_void_monthly
WHERE channel_name <> 'Store'
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
