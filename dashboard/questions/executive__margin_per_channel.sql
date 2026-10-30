-- name: Margin terhadap target per channel
-- dashboard: kirana
-- tab: executive
-- pos: row=7 col=12 w=12 h=5
-- display: table
-- filter: period = v_margin_vs_target.month_start
-- filter: channel = v_margin_vs_target.channel_name
-- viz: {"table.column_formatting":[{"columns":["Status"],"type":"single","operator":"=","value":"Hijau","color":"#0ca30c","highlight_row":false,"id":1},{"columns":["Status"],"type":"single","operator":"=","value":"Kuning","color":"#fab219","highlight_row":false,"id":2},{"columns":["Status"],"type":"single","operator":"=","value":"Merah","color":"#d03b3b","highlight_row":false,"id":3}]}
-- note: Hanya bulan bertarget. Region/Kategori tidak berlaku (target GM per channel). Status: selisih >=0 pt Hijau, sampai -2 pt Kuning, lebih buruk Merah.
SELECT channel_name AS "Channel", gm_pct AS "Gross Margin (%)", target_gm AS "Target GM (%)", round(gm_pct - target_gm, 2) AS "Selisih (pt)",
       cm_pct AS "Contribution Margin (%)",
       CASE WHEN gm_pct - target_gm >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'MARGIN_GAP_PT' AND status = 'Hijau') THEN 'Hijau'
            WHEN gm_pct - target_gm >= (SELECT min_value FROM metrics.ref_status_threshold WHERE kpi = 'MARGIN_GAP_PT' AND status = 'Kuning') THEN 'Kuning'
            ELSE 'Merah' END AS "Status"
FROM (
  SELECT channel_name, round(100.0 * sum(gross_margin_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS gm_pct,
         round(100.0 * sum(contribution_margin_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS cm_pct,
         round(sum(target_gm_pct * net_sales_idr) / NULLIF(sum(net_sales_idr), 0), 2) AS target_gm
  FROM metrics.v_margin_vs_target
WHERE target_gm_pct IS NOT NULL
  [[AND {{period}}]]
  [[AND {{channel}}]]
  GROUP BY channel_name
) t
ORDER BY gm_pct - target_gm
