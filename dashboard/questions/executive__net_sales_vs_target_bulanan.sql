-- name: Net Sales vs Target bulanan (Rp miliar)
-- dashboard: kirana
-- tab: executive
-- pos: row=12 col=0 w=12 h=6
-- display: line
-- filter: period = v_target_achievement.month_start
-- filter: channel = v_target_achievement.channel_name
-- filter: region = v_target_achievement.region
-- viz: {"graph.dimensions":["month_start"],"graph.metrics":["aktual","target"],"graph.show_values":false,"series_settings":{"aktual":{"color":"#2a78d6","title":"Aktual"},"target":{"color":"#8a8a85","title":"Target","line.style":"dashed"}},"graph.y_axis.title_text":"Rp miliar","graph.x_axis.title_text":"Bulan","legend.is_reversed":false}
-- note: Target hanya ada 2025-01 s.d. 2026-06; 2024 tanpa target (garis target kosong).
SELECT month_start, round(sum(net_sales_idr) / 1e9, 2) AS aktual, round(sum(target_net_sales_idr) / 1e9, 2) AS target
FROM metrics.v_target_achievement
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
GROUP BY month_start
ORDER BY month_start
