-- name: Net Sales
-- dashboard: kirana
-- tab: executive
-- pos: row=4 col=0 w=4 h=3
-- display: scalar
-- filter: period = v_sales_monthly.month_start
-- filter: channel = v_sales_monthly.channel_name
-- filter: region = v_sales_monthly.region_target_basis
-- filter: category = v_sales_monthly.category
-- viz: {"scalar.field":"net_sales_miliar","column_settings":{"[\"name\", \"net_sales_miliar\"]":{"prefix":"Rp ","suffix":" miliar","decimals":2}}}
-- note: Net Sales = penjualan bersih setelah diskon/voucher, tanpa pajak, sebelum retur. Termasuk B2B bulk.
SELECT round(sum(net_sales_idr) / 1e9, 2) AS net_sales_miliar
FROM metrics.v_sales_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
