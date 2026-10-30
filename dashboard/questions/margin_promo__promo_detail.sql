-- name: Detail per kode promo
-- dashboard: kirana
-- tab: margin_promo
-- pos: row=23 col=12 w=12 h=7
-- display: table
-- filter: period = v_promo_performance.start_date
-- viz: {"table.column_formatting":[{"columns":["Margin tambahan (Rp)"],"type":"single","operator":"<","value":0,"color":"#d03b3b","highlight_row":false,"id":1}]}
SELECT promo_code AS "Kode", promo_type AS "Jenis", lift_net_pct AS "Lift Net Sales (%)", gm_change_pt AS "Perubahan GM (pt)",
       incremental_gross_margin_idr AS "Margin tambahan (Rp)", discount_idr AS "Diskon (Rp)"
FROM metrics.v_promo_performance
WHERE 1=1
  [[AND {{period}}]]
ORDER BY incremental_gross_margin_idr
