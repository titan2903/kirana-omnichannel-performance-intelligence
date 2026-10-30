-- name: Active Members bulanan per channel
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=13 col=12 w=12 h=6
-- display: line
-- filter: period = v_members_period.period_start
-- filter: channel = v_members_period.channel_name
-- viz: {"graph.dimensions":["month_start","channel"],"graph.metrics":["active_members"],"series_settings":{"Store":{"color":"#2a78d6"},"Marketplace":{"color":"#eb6834"},"Mobile App":{"color":"#1baf7a"},"Website":{"color":"#eda100"}},"graph.y_axis.title_text":"Member unik","graph.x_axis.title_text":"Bulan"}
-- note: Member unik per bulan dan channel (tidak dijumlahkan antar channel). Struk B2B dikecualikan. Region/Kategori tidak berlaku.
SELECT period_start AS month_start, channel_name AS channel, active_members
FROM metrics.v_members_period
WHERE period_type = 'Bulan' AND channel_name <> 'Semua channel'
  [[AND {{period}}]]
  [[AND {{channel}}]]
ORDER BY period_start, channel_name
