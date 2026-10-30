-- 01_load: baca file mentah apa adanya (read-only).
-- Input : raw_data/*   Output: TEMP view raw_* (hanya ada selama sesi build; TIDAK disimpan di kirana.duckdb)
-- Alasan TEMP: raw memuat PII (customers.csv) dan path relatif ke raw_data/ yang tidak ada di container Metabase.
--              Database hasil build hanya memuat stg/dw/dq/metrics, semuanya bebas PII.
-- Semua kolom dibaca sebagai VARCHAR; pengubahan tipe dilakukan di 02_staging dengan try_cast.
INSTALL excel; LOAD excel;

CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS dq;
CREATE SCHEMA IF NOT EXISTS metrics;

CREATE OR REPLACE TEMP VIEW raw_pos         AS SELECT * FROM read_csv('raw_data/sales_pos_transactions.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_online      AS SELECT * FROM read_csv('raw_data/sales_online_orders.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_products    AS SELECT * FROM read_csv('raw_data/products.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_cost        AS SELECT * FROM read_csv('raw_data/product_cost_history.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_stores      AS SELECT * FROM read_csv('raw_data/stores.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_region_hist AS SELECT * FROM read_csv('raw_data/store_region_history.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_events      AS SELECT * FROM read_csv('raw_data/store_events.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_customers   AS SELECT * FROM read_csv('raw_data/customers.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_returns     AS SELECT * FROM read_csv('raw_data/returns.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_promos      AS SELECT * FROM read_csv('raw_data/promotions.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_fees        AS SELECT * FROM read_csv('raw_data/channel_fee_rates.csv', all_varchar = true);
CREATE OR REPLACE TEMP VIEW raw_sync        AS SELECT * FROM read_csv('raw_data/pos_sync_log.csv', all_varchar = true);

-- Excel target: judul di baris 1, header di baris 3 -> range eksplisit (tanpa range hanya baris judul yang terbaca).
-- Baris kosong di bawah tabel disaring dengan Channel IS NOT NULL.
CREATE OR REPLACE TEMP VIEW raw_target_2025 AS
SELECT * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target Net Sales 2025', range = 'A3:N20', header = true) WHERE Channel IS NOT NULL;
CREATE OR REPLACE TEMP VIEW raw_target_2026 AS
SELECT * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target Net Sales H1 2026', range = 'A3:H20', header = true) WHERE Channel IS NOT NULL;
CREATE OR REPLACE TEMP VIEW raw_target_gm AS
SELECT * FROM read_xlsx('raw_data/sales_targets_2025_2026.xlsx', sheet = 'Target GM', header = true);
