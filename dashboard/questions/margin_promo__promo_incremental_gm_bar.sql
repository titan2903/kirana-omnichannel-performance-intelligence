-- name: Margin kotor tambahan per jenis promo (Rp juta)
-- dashboard: kirana
-- tab: margin_promo
-- pos: row=23 col=0 w=12 h=7
-- display: row
-- filter: period = v_promo_performance.start_date
-- viz: {"graph.dimensions":["promo_type"],"graph.metrics":["margin_tambahan_juta"],"graph.show_values":true,"series_settings":{"margin_tambahan_juta":{"color":"#2a78d6","title":"Margin kotor tambahan"}},"graph.x_axis.title_text":"Jenis promo","graph.y_axis.title_text":"Rp juta (setelah biaya diskon)"}
-- note: Negatif = promo menggerus margin dibanding baseline.
SELECT promo_type, round(sum(incremental_gross_margin_idr) / 1e6, 1) AS margin_tambahan_juta
FROM metrics.v_promo_performance
WHERE 1=1
  [[AND {{period}}]]
GROUP BY promo_type
ORDER BY margin_tambahan_juta
