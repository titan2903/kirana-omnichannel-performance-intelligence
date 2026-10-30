-- name: Active Members dan Repeat Rate per tahun
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=19 col=12 w=12 h=8
-- display: table
-- filter: period = v_members_period.period_start
-- filter: channel = v_members_period.channel_name
SELECT period_label AS "Periode", channel_name AS "Channel", active_members AS "Active Members", repeat_members AS "Repeat Members", repeat_rate_pct AS "Repeat Rate (%)"
FROM metrics.v_members_period
WHERE period_type = 'Tahun'
  [[AND {{period}}]]
  [[AND {{channel}}]]
ORDER BY period_start, channel_name
