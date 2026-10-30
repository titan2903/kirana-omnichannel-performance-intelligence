-- name: Kelengkapan data toko per bulan
-- dashboard: detail_toko
-- tab: detail
-- pos: row=10 col=0 w=24 h=5
-- display: table
-- filter: period = v_data_completeness.month_start
-- filter: store = v_data_completeness.store_code
-- viz: {"table.column_formatting":[{"columns":["Status"],"type":"single","operator":"=","value":"Tidak lengkap","color":"#d03b3b","highlight_row":false,"id":1},{"columns":["Status"],"type":"single","operator":"=","value":"Toko tutup","color":"#fab219","highlight_row":false,"id":2}]}
SELECT strftime(month_start, '%Y-%m') AS "Bulan", store_code AS "Toko", completeness_status AS "Status", note AS "Keterangan"
FROM metrics.v_data_completeness
WHERE completeness_status <> 'Lengkap'
  [[AND {{period}}]]
  [[AND {{store}}]]
ORDER BY month_start
