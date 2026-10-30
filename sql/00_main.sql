-- 00_main: satu-satunya entry point. Bangun ulang seluruh database dari raw_data/.
--   duckdb kirana.duckdb < sql/00_main.sql      (jalankan dari root project; hentikan Metabase dulu)
-- Urutan: load -> staging -> model -> rekonsiliasi -> metrics (semantic layer) -> uji kualitas
-- Idempoten: hanya CREATE OR REPLACE; tanpa random()/now(); verifikasi:
--   bash .claude/skills/kirana-pipeline/scripts/idempotency_check.sh
.bail on
.read sql/01_load.sql
.read sql/02_staging.sql
.read sql/03_model.sql
.read sql/04_reconciliation.sql
.read sql/05_metrics.sql
.read sql/06_tests.sql

-- Gerbang: pipeline berhenti dengan error bila ada uji BLOCKING yang gagal.
SELECT CASE
         WHEN count(*) FILTER (WHERE severity = 'BLOCKING' AND status = 'FAIL') > 0
           THEN error('Uji BLOCKING gagal: ' || string_agg(test_id, ', ') FILTER (WHERE severity = 'BLOCKING' AND status = 'FAIL'))
         ELSE 'OK: ' || count(*) FILTER (WHERE severity = 'BLOCKING') || ' uji BLOCKING lolos, '
              || count(*) FILTER (WHERE severity = 'WARNING' AND status = 'FAIL') || ' WARNING terdokumentasi'
       END AS build_status
FROM dq.test_results;
