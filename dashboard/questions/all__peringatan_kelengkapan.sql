-- name: Penanda data tidak lengkap per toko-bulan
-- dashboard: kirana
-- tab: *
-- pos: row=0 col=0 w=12 h=5
-- display: table
-- filter: period = v_data_completeness.month_start
-- viz: {"table.column_formatting":[{"columns":["Status"],"type":"single","operator":"=","value":"Tidak lengkap","color":"#d03b3b","highlight_row":false,"id":1},{"columns":["Status"],"type":"single","operator":"=","value":"Toko tutup","color":"#fab219","highlight_row":false,"id":2}]}
-- note: Hanya periode/toko bermasalah. Filter: Periode. Channel/Region/Kategori tidak berlaku (kelengkapan adalah atribut toko-bulan).
SELECT strftime(month_start, '%Y-%m') AS "Bulan", store_code AS "Toko", completeness_status AS "Status", note AS "Keterangan"
FROM metrics.v_data_completeness
WHERE completeness_status <> 'Lengkap'
  [[AND {{period}}]]
ORDER BY month_start, store_code
