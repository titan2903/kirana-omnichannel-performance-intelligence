#!/usr/bin/env bash
# Bangun ulang DB dua kali dari sql/00_main.sql, lalu bandingkan fingerprint
# (jumlah baris + hash isi, tak peduli urutan) semua tabel/view non-internal.
# Pakai: bash idempotency_check.sh   (override: MAIN=... DB=... DUCKDB=...)
set -euo pipefail
cd "$(dirname "$0")/.."   # root project
MAIN=${MAIN:-sql/00_main.sql}
DB=${DB:-/tmp/kirana_idem_$$.duckdb}
DUCKDB=${DUCKDB:-duckdb}
trap 'rm -f "$DB" "$DB.wal" /tmp/idem_$$_*' EXIT

fingerprint() {
  local q
  q=$("$DUCKDB" "$DB" -noheader -list -c "
    select string_agg('select ''' || s || '.' || n || ''' as obj, count(*) as n, coalesce(sum(hash(t)::hugeint),0) as h from ' || s || '.' || n || ' t', ' union all ' order by s, n)
    from (select schema_name s, table_name n from duckdb_tables()
          union all select schema_name, view_name from duckdb_views() where not internal)")
  "$DUCKDB" "$DB" -csv -c "select * from ($q) order by obj"
}

for i in 1 2; do
  rm -f "$DB" "$DB.wal"
  "$DUCKDB" "$DB" < "$MAIN" > /dev/null
  fingerprint > "/tmp/idem_$$_$i.csv"
done

if diff -q "/tmp/idem_$$_1.csv" "/tmp/idem_$$_2.csv" > /dev/null; then
  echo "IDEMPOTENT: $(($(wc -l < /tmp/idem_$$_1.csv) - 1)) objek identik di dua run"
else
  echo "TIDAK IDEMPOTEN. Objek berbeda:"; diff "/tmp/idem_$$_1.csv" "/tmp/idem_$$_2.csv" || true
  exit 1
fi
