#!/usr/bin/env bash
# Bangun kirana.duckdb dari raw_data/ secara aman: build ke file sementara, tukar ke kirana.duckdb HANYA bila semua
# uji BLOCKING lolos. Build yang gagal tidak menimpa database yang sedang dipakai (Metabase).
#   bash scripts/build.sh            (jalankan dari mana saja; hentikan/restart Metabase sendiri bila perlu)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${OUT:-kirana.duckdb}
TMP="$OUT.building"
trap 'rm -f "$TMP" "$TMP.wal"' EXIT
rm -f "$TMP" "$TMP.wal"
if duckdb "$TMP" < "${MAIN:-sql/00_main.sql}"; then
  rm -f "$OUT.wal"
  mv -f "$TMP" "$OUT"
  echo "OK: $OUT diperbarui. Restart Metabase agar membaca file baru: docker compose restart metabase"
else
  echo "GAGAL: uji BLOCKING tidak lolos atau ada error. $OUT TIDAK diubah." >&2
  exit 1
fi
