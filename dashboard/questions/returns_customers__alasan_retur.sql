-- name: Alasan retur (% nilai refund)
-- dashboard: kirana
-- tab: returns_customers
-- pos: row=7 col=16 w=8 h=6
-- display: row
-- filter: period = v_return_reason_monthly.month_start
-- filter: channel = v_return_reason_monthly.channel_name
-- filter: region = v_return_reason_monthly.region_target_basis
-- filter: category = v_return_reason_monthly.category
-- viz: {"graph.dimensions":["alasan"],"graph.metrics":["pangsa_refund_pct"],"graph.show_values":true,"series_settings":{"pangsa_refund_pct":{"color":"#2a78d6","title":"Pangsa refund (%)"}},"graph.x_axis.title_text":"% dari total refund","graph.y_axis.title_text":"Alasan"}
SELECT return_reason AS alasan, round(100.0 * sum(refund_idr) / NULLIF(sum(sum(refund_idr)) OVER (), 0), 1) AS pangsa_refund_pct
FROM metrics.v_return_reason_monthly
WHERE 1=1
  [[AND {{period}}]]
  [[AND {{channel}}]]
  [[AND {{region}}]]
  [[AND {{category}}]]
GROUP BY return_reason
ORDER BY pangsa_refund_pct
