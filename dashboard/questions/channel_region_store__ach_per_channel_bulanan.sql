-- name: Achievement bulanan per channel (%)
-- dashboard: kirana
-- tab: channel_region_store
-- pos: row=4 col=12 w=12 h=7
-- display: line
-- filter: period = v_target_achievement.month_start
-- filter: channel = v_target_achievement.channel_name
-- filter: region = v_target_achievement.region
-- viz: {"graph.dimensions":["month_start","channel"],"graph.metrics":["achievement_pct"],"series_settings":{"Store":{"color":"#2a78d6"},"Marketplace":{"color":"#eb6834"},"Mobile App":{"color":"#1baf7a"},"Website":{"color":"#eda100"}},"graph.show_goal":true,"graph.goal_value":100,"graph.goal_label":"Target 100%","graph.y_axis.title_text":"% dari target","graph.x_axis.title_text":"Bulan"}
SELECT month_start, channel_name AS channel, round(100.0 * sum(net_sales_idr) / NULLIF(sum(target_net_sales_idr), 0), 1) AS achievement_pct
FROM metrics.v_target_achievement
WHERE target_net_sales_idr IS NOT NULL
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
GROUP BY month_start, channel_name
ORDER BY month_start, channel_name
