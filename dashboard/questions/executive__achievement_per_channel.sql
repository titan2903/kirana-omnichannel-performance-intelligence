-- name: Pencapaian terhadap target per channel
-- dashboard: kirana
-- tab: executive
-- pos: row=7 col=0 w=12 h=5
-- display: table
-- filter: period = v_target_achievement.month_start
-- filter: channel = v_target_achievement.channel_name
-- filter: region = v_target_achievement.region
-- viz: {"table.column_formatting":[{"columns":["Status"],"type":"single","operator":"=","value":"Hijau","color":"#0ca30c","highlight_row":false,"id":1},{"columns":["Status"],"type":"single","operator":"=","value":"Kuning","color":"#fab219","highlight_row":false,"id":2},{"columns":["Status"],"type":"single","operator":"=","value":"Merah","color":"#d03b3b","highlight_row":false,"id":3}]}
-- note: Status: Hijau >=100%, Kuning 90-<100%, Merah <90% (ambang ASUMSI, metrics.ref_status_threshold).
SELECT channel_name AS "Channel", net_sales_idr AS "Net Sales (Rp)", target_idr AS "Target (Rp)", achievement_pct AS "Achievement (%)",
       CASE WHEN achievement_pct >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Hijau') THEN 'Hijau' WHEN achievement_pct >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'ACHIEVEMENT_PCT' AND status = 'Kuning') THEN 'Kuning' ELSE 'Merah' END AS "Status"
FROM (
  SELECT channel_name, sum(net_sales_idr) AS net_sales_idr, sum(target_net_sales_idr) AS target_idr,
         round(100.0 * sum(net_sales_idr) / NULLIF(sum(target_net_sales_idr), 0), 1) AS achievement_pct
  FROM metrics.v_target_achievement
WHERE target_net_sales_idr IS NOT NULL
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  GROUP BY channel_name
) t
ORDER BY achievement_pct
