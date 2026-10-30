-- name: Average Order Value
-- dashboard: kirana
-- tab: executive
-- pos: row=4 col=20 w=4 h=3
-- display: scalar
-- filter: period = v_txn_monthly.month_start
-- filter: channel = v_txn_monthly.channel_name
-- filter: region = v_txn_monthly.region_target_basis
-- viz: {"scalar.field":"aov_rp","column_settings":{"[\"name\", \"aov_rp\"]":{"prefix":"Rp ","suffix":"","decimals":0}}}
-- note: AOV = SUM(Net Sales) / SUM(transaksi).
SELECT round(sum(net_sales_idr)::DOUBLE / NULLIF(sum(transactions), 0))::BIGINT AS aov_rp
FROM metrics.v_txn_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
