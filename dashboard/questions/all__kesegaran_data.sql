-- name: Kesegaran data dan status sinkronisasi POS
-- dashboard: kirana
-- tab: *
-- pos: row=1 col=0 w=24 h=3
-- display: table
-- viz: {"table.pivot":false,"table.cell_column":"Data sampai"}
-- note: Indikator kesegaran data. Hari sync GAGAL = penjualan tidak tercatat (bukan nol); hari tutup = kejadian bisnis (renovasi).
SELECT strftime(data_through_date, '%d %b %Y') AS "Data sampai",
       sync_success_pct AS "Sync POS berhasil (%)",
       failed_store_days AS "Toko-hari sync gagal",
       closed_store_days AS "Toko-hari tutup",
       strftime(last_failed_date, '%d %b %Y') AS "Sync gagal terakhir",
       stores_with_failed_sync AS "Toko terdampak sync gagal"
FROM metrics.v_data_freshness
