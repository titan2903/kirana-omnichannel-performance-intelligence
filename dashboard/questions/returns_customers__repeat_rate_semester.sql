-- name: Repeat Rate per semester dan channel (%)
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=19 col=0 w=12 h=8
-- display: bar
-- filter: period = v_members_period.period_start
-- filter: channel = v_members_period.channel_name
-- viz: {"graph.dimensions":["semester","channel"],"graph.metrics":["repeat_rate_pct"],"series_settings":{"Store":{"color":"#2a78d6"},"Marketplace":{"color":"#eb6834"},"Mobile App":{"color":"#1baf7a"},"Website":{"color":"#eda100"},"Semua channel":{"color":"#52514e"}},"graph.y_axis.title_text":"% member repeat","graph.x_axis.title_text":"Semester"}
-- note: Repeat = member dengan >=2 struk pada semester itu. Bandingkan hanya semester sama panjang (H1 dengan H1).
SELECT period_label AS semester, channel_name AS channel, repeat_rate_pct
FROM metrics.v_members_period
WHERE period_type = 'Semester'
  [[AND {{period}}]]
  [[AND {{channel}}]]
ORDER BY period_start, channel_name
