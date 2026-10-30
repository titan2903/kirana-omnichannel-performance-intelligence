-- name: Jumlah Transaksi
-- dashboard: kirana
-- tab: executive
-- pos: row=4 col=16 w=4 h=3
-- display: scalar
-- filter: period = v_txn_monthly.month_start
-- filter: channel = v_txn_monthly.channel_name
-- filter: region = v_txn_monthly.region_target_basis
-- viz: {"scalar.field":"transaksi","scalar.compact_primary_number":false}
-- note: Kategori tidak berlaku: satu struk dapat memuat lebih dari satu kategori.
SELECT sum(transactions) AS transaksi
FROM metrics.v_txn_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
