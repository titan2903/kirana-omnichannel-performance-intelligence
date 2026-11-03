-- name: Efektivitas promo per jenis: lift dan dampak margin
-- dashboard: kirana
-- tab: margin_promo
-- pos: row=16 col=0 w=24 h=7
-- display: table
-- filter: period = v_promo_performance.start_date
-- viz: {"table.column_formatting":[{"columns":["Margin kotor tambahan (Rp)"],"type":"single","operator":"<","value":0,"color":"#d03b3b","highlight_row":false,"id":1},{"columns":["Margin kotor tambahan (Rp)"],"type":"single","operator":">","value":0,"color":"#0ca30c","highlight_row":false,"id":2}]}
-- note: Baseline = hari yang sama +/-1 s.d. 4 minggu tanpa promo beririsan; Net Sales sudah netto diskon. Filter: Periode (tanggal mulai promo). Channel/Region/Kategori tidak berlaku: tiap promo dinilai pada scope-nya sendiri.
SELECT promo_type AS "Jenis promo", count(*) AS "Kode promo",
       -- rasio dihitung ulang dari pembilang/penyebut gabungan (bukan AVG rasio per kode)
       round(100.0 * (sum(net_sales_idr) / NULLIF(sum(baseline_net_sales_idr), 0) - 1), 1) AS "Lift Net Sales (%)",
       round(100.0 * (sum(qty) / NULLIF(sum(baseline_qty), 0) - 1), 1) AS "Lift unit (%)",
       round(100.0 * (sum(gross_margin_idr) / NULLIF(sum(net_sales_idr), 0) - sum(baseline_gross_margin_idr) / NULLIF(sum(baseline_net_sales_idr), 0)), 2) AS "Perubahan GM (pt)",
       sum(incremental_net_sales_idr) AS "Net Sales tambahan (Rp)", sum(incremental_gross_margin_idr) AS "Margin kotor tambahan (Rp)",
       sum(discount_idr) AS "Diskon (Rp)", round(100.0 * sum(discount_idr) / NULLIF(sum(budget_idr), 0), 1) AS "Pemakaian anggaran (%)"
FROM metrics.v_promo_performance
WHERE 1=1
  [[AND {{period}}]]
GROUP BY promo_type
ORDER BY sum(incremental_gross_margin_idr) DESC
