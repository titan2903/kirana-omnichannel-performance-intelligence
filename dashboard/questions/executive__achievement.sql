-- name: Achievement vs Target
-- dashboard: kirana
-- tab: executive
-- pos: row=4 col=4 w=4 h=3
-- display: gauge
-- filter: period = v_target_achievement.month_start
-- filter: channel = v_target_achievement.channel_name
-- filter: region = v_target_achievement.region
-- viz: {"gauge.range":[0,150],"gauge.segments":[{"min":0,"max":90,"color":"#d03b3b","label":"Merah <90%"},{"min":90,"max":100,"color":"#fab219","label":"Kuning 90-<100%"},{"min":100,"max":150,"color":"#0ca30c","label":"Hijau >=100%"}],"column_settings":{"[\"name\", \"achievement_pct\"]":{"suffix":"%","decimals":1}}}
-- note: Hanya bulan yang memiliki target (2025-01 s.d. 2026-06). Kategori tidak berlaku: target tidak per kategori.
SELECT round(100.0 * sum(net_sales_idr) / NULLIF(sum(target_net_sales_idr), 0), 1) AS achievement_pct
FROM metrics.v_target_achievement
WHERE target_net_sales_idr IS NOT NULL
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
