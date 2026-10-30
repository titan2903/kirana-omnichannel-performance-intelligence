-- Task 1 / profiling 1: inventaris 13 file raw_data (baris, kunci, keunikan, rentang tanggal)
-- Input : raw_data/*  (read-only; dibaca langsung, tidak ada tabel yang ditulis)
-- Jalankan dari root project, tanpa file DB agar tidak mengunci kirana.duckdb:
--   duckdb -markdown < sql/profiling/01_file_inventory.sql
INSTALL excel; LOAD excel;

CREATE TEMP TABLE inventory AS
SELECT 'sales_pos_transactions.csv' AS file, count(*) AS n_rows, 'trx_id + line_no' AS natural_key,
       count(DISTINCT (trx_id, line_no)) AS key_distinct,
       min(trx_datetime) AS min_date, max(trx_datetime) AS max_date
FROM read_csv('raw_data/sales_pos_transactions.csv', all_varchar = true)
UNION ALL
SELECT 'sales_online_orders.csv', count(*), 'order_no + line_no', count(DISTINCT (order_no, line_no)),
       min(strptime(order_date, '%d/%m/%Y %H:%M'))::VARCHAR, max(strptime(order_date, '%d/%m/%Y %H:%M'))::VARCHAR
FROM read_csv('raw_data/sales_online_orders.csv', all_varchar = true)
UNION ALL
SELECT 'products.csv', count(*), 'sku', count(DISTINCT sku), min(launch_date)::VARCHAR, max(launch_date)::VARCHAR
FROM read_csv('raw_data/products.csv')
UNION ALL
SELECT 'product_cost_history.csv', count(*), 'sku + valid_from', count(DISTINCT (sku, valid_from)),
       min(valid_from)::VARCHAR, max(valid_from)::VARCHAR
FROM read_csv('raw_data/product_cost_history.csv')
UNION ALL
SELECT 'stores.csv', count(*), 'store_code', count(DISTINCT store_code), min(open_date)::VARCHAR, max(open_date)::VARCHAR
FROM read_csv('raw_data/stores.csv')
UNION ALL
SELECT 'store_region_history.csv', count(*), 'store_code + valid_from', count(DISTINCT (store_code, valid_from)),
       min(valid_from)::VARCHAR, max(valid_from)::VARCHAR
FROM read_csv('raw_data/store_region_history.csv')
UNION ALL
SELECT 'store_events.csv', count(*), 'store_code + start_date', count(DISTINCT (store_code, start_date)),
       min(start_date)::VARCHAR, max(end_date)::VARCHAR
FROM read_csv('raw_data/store_events.csv')
UNION ALL
SELECT 'customers.csv', count(*), 'customer_id', count(DISTINCT customer_id), min(join_date)::VARCHAR, max(join_date)::VARCHAR
FROM read_csv('raw_data/customers.csv')
UNION ALL
SELECT 'returns.csv', count(*), 'return_id', count(DISTINCT return_id), min(return_date)::VARCHAR, max(return_date)::VARCHAR
FROM read_csv('raw_data/returns.csv')
UNION ALL
SELECT 'promotions.csv', count(*), 'promo_code', count(DISTINCT promo_code), min(start_date)::VARCHAR, max(end_date)::VARCHAR
FROM read_csv('raw_data/promotions.csv')
UNION ALL
SELECT 'channel_fee_rates.csv', count(*), 'channel + valid_from', count(DISTINCT (channel, valid_from)),
       min(valid_from)::VARCHAR, max(valid_from)::VARCHAR
FROM read_csv('raw_data/channel_fee_rates.csv')
UNION ALL
SELECT 'pos_sync_log.csv', count(*), 'store_code + business_date', count(DISTINCT (store_code, business_date)),
       min(business_date)::VARCHAR, max(business_date)::VARCHAR
FROM read_csv('raw_data/pos_sync_log.csv')
UNION ALL
-- Excel: header baris 3, bulan melebar; hitung sel data (baris x bulan) bukan baris
SELECT 'sales_targets_2025_2026.xlsx [2025]', count(*), 'channel + region', count(DISTINCT (Channel, Region)), 'Jan-25', 'Dec-25'
FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target Net Sales 2025', range = 'A3:N20', header = true) WHERE Channel IS NOT NULL
UNION ALL
SELECT 'sales_targets_2025_2026.xlsx [H1 2026]', count(*), 'channel + region', count(DISTINCT (Channel, Region)), 'Jan-26', 'Jun-26'
FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target Net Sales H1 2026', range = 'A3:H20', header = true) WHERE Channel IS NOT NULL
UNION ALL
SELECT 'sales_targets_2025_2026.xlsx [Target GM]', count(*), 'channel', count(DISTINCT Channel), '2025', 'H1 2026'
FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target GM', header = true);

SELECT file, n_rows, natural_key, key_distinct, n_rows - key_distinct AS dup_key_rows, min_date, max_date
FROM inventory ORDER BY file;

-- Null per kolom (hanya yang punya null). UNPIVOT membuang sel NULL, jadi null = total baris - sel terisi;
-- daftar kolom diambil dari DESCRIBE agar kolom yang 100% kosong tetap muncul (tidak hilang dari hasil).
-- Hanya hitungan; tidak ada nilai PII ditampilkan.
CREATE TEMP TABLE null_counts AS
SELECT 'sales_pos_transactions.csv' AS file, d.column_name,
       (SELECT count(*) FROM read_csv('raw_data/sales_pos_transactions.csv', all_varchar = true)) - coalesce(u.filled, 0) AS n_null, (SELECT count(*) FROM read_csv('raw_data/sales_pos_transactions.csv', all_varchar = true)) AS n_rows
FROM (DESCRIBE SELECT * FROM read_csv('raw_data/sales_pos_transactions.csv', all_varchar = true)) d
LEFT JOIN (SELECT column_name, count(*) AS filled
           FROM (UNPIVOT (SELECT * FROM read_csv('raw_data/sales_pos_transactions.csv', all_varchar = true)) ON COLUMNS(*) INTO NAME column_name VALUE v) GROUP BY column_name) u
  ON u.column_name = d.column_name
UNION ALL
SELECT 'sales_online_orders.csv' AS file, d.column_name,
       (SELECT count(*) FROM read_csv('raw_data/sales_online_orders.csv', all_varchar = true)) - coalesce(u.filled, 0) AS n_null, (SELECT count(*) FROM read_csv('raw_data/sales_online_orders.csv', all_varchar = true)) AS n_rows
FROM (DESCRIBE SELECT * FROM read_csv('raw_data/sales_online_orders.csv', all_varchar = true)) d
LEFT JOIN (SELECT column_name, count(*) AS filled
           FROM (UNPIVOT (SELECT * FROM read_csv('raw_data/sales_online_orders.csv', all_varchar = true)) ON COLUMNS(*) INTO NAME column_name VALUE v) GROUP BY column_name) u
  ON u.column_name = d.column_name
UNION ALL
SELECT 'returns.csv' AS file, d.column_name,
       (SELECT count(*) FROM read_csv('raw_data/returns.csv', all_varchar = true)) - coalesce(u.filled, 0) AS n_null, (SELECT count(*) FROM read_csv('raw_data/returns.csv', all_varchar = true)) AS n_rows
FROM (DESCRIBE SELECT * FROM read_csv('raw_data/returns.csv', all_varchar = true)) d
LEFT JOIN (SELECT column_name, count(*) AS filled
           FROM (UNPIVOT (SELECT * FROM read_csv('raw_data/returns.csv', all_varchar = true)) ON COLUMNS(*) INTO NAME column_name VALUE v) GROUP BY column_name) u
  ON u.column_name = d.column_name
UNION ALL
SELECT 'customers.csv' AS file, d.column_name,
       (SELECT count(*) FROM read_csv('raw_data/customers.csv', all_varchar = true)) - coalesce(u.filled, 0) AS n_null, (SELECT count(*) FROM read_csv('raw_data/customers.csv', all_varchar = true)) AS n_rows
FROM (DESCRIBE SELECT * FROM read_csv('raw_data/customers.csv', all_varchar = true)) d
LEFT JOIN (SELECT column_name, count(*) AS filled
           FROM (UNPIVOT (SELECT * FROM read_csv('raw_data/customers.csv', all_varchar = true)) ON COLUMNS(*) INTO NAME column_name VALUE v) GROUP BY column_name) u
  ON u.column_name = d.column_name
UNION ALL
SELECT 'products.csv' AS file, d.column_name,
       (SELECT count(*) FROM read_csv('raw_data/products.csv', all_varchar = true)) - coalesce(u.filled, 0) AS n_null, (SELECT count(*) FROM read_csv('raw_data/products.csv', all_varchar = true)) AS n_rows
FROM (DESCRIBE SELECT * FROM read_csv('raw_data/products.csv', all_varchar = true)) d
LEFT JOIN (SELECT column_name, count(*) AS filled
           FROM (UNPIVOT (SELECT * FROM read_csv('raw_data/products.csv', all_varchar = true)) ON COLUMNS(*) INTO NAME column_name VALUE v) GROUP BY column_name) u
  ON u.column_name = d.column_name
UNION ALL
SELECT 'stores.csv' AS file, d.column_name,
       (SELECT count(*) FROM read_csv('raw_data/stores.csv', all_varchar = true)) - coalesce(u.filled, 0) AS n_null, (SELECT count(*) FROM read_csv('raw_data/stores.csv', all_varchar = true)) AS n_rows
FROM (DESCRIBE SELECT * FROM read_csv('raw_data/stores.csv', all_varchar = true)) d
LEFT JOIN (SELECT column_name, count(*) AS filled
           FROM (UNPIVOT (SELECT * FROM read_csv('raw_data/stores.csv', all_varchar = true)) ON COLUMNS(*) INTO NAME column_name VALUE v) GROUP BY column_name) u
  ON u.column_name = d.column_name
UNION ALL
SELECT 'pos_sync_log.csv' AS file, d.column_name,
       (SELECT count(*) FROM read_csv('raw_data/pos_sync_log.csv', all_varchar = true)) - coalesce(u.filled, 0) AS n_null, (SELECT count(*) FROM read_csv('raw_data/pos_sync_log.csv', all_varchar = true)) AS n_rows
FROM (DESCRIBE SELECT * FROM read_csv('raw_data/pos_sync_log.csv', all_varchar = true)) d
LEFT JOIN (SELECT column_name, count(*) AS filled
           FROM (UNPIVOT (SELECT * FROM read_csv('raw_data/pos_sync_log.csv', all_varchar = true)) ON COLUMNS(*) INTO NAME column_name VALUE v) GROUP BY column_name) u
  ON u.column_name = d.column_name;

SELECT file, column_name, n_null, round(100.0 * n_null / n_rows, 2) AS pct_null
FROM null_counts WHERE n_null > 0 ORDER BY file, n_null DESC;
