-- name: Achievement Store per region (klik region untuk melihat tokonya)
-- dashboard: kirana
-- tab: channel_region_store
-- pos: row=4 col=0 w=12 h=7
-- display: table
-- filter: period = v_target_achievement.month_start
-- filter: region = v_target_achievement.region
-- viz: {"table.column_formatting":[{"columns":["Status"],"type":"single","operator":"=","value":"Hijau","color":"#0ca30c","highlight_row":false,"id":1},{"columns":["Status"],"type":"single","operator":"=","value":"Kuning","color":"#fab219","highlight_row":false,"id":2},{"columns":["Status"],"type":"single","operator":"=","value":"Merah","color":"#d03b3b","highlight_row":false,"id":3}],"column_settings":{"[\"name\", \"region\"]":{"column_title":"Region"}}}
-- click: {"type":"crossfilter","parameterMapping":{"region":{"id":"region","source":{"type":"column","id":"region","name":"region"},"target":{"type":"parameter","id":"region"}}}}
-- note: Drill-down: klik baris region -> filter Region dashboard terisi -> tabel toko di bawah menampilkan toko pada region itu. Channel/Kategori tidak berlaku (kartu Store saja).
SELECT region AS region, net_sales_idr AS "Net Sales (Rp)", target_idr AS "Target (Rp)", achievement_pct AS "Achievement (%)",
       CASE WHEN achievement_pct >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Hijau') THEN 'Hijau' WHEN achievement_pct >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Kuning') THEN 'Kuning' ELSE 'Merah' END AS "Status"
FROM (
  SELECT region, sum(net_sales_idr) AS net_sales_idr, sum(target_net_sales_idr) AS target_idr,
         round(100.0 * sum(net_sales_idr) / NULLIF(sum(target_net_sales_idr), 0), 1) AS achievement_pct
  FROM metrics.v_target_achievement
WHERE channel_name = 'Store' AND target_net_sales_idr IS NOT NULL
  [[AND {{period}}]]
  [[AND {{region}}]]
  GROUP BY region
) t
ORDER BY achievement_pct
