#!/usr/bin/env bash
# Paket pengumpulan: dist/UAS_BI_<NIM>_<Nama>_SQL.zip dan salinan Dashboard PDF. Laporan dibuat oleh scripts/build_report.py.
#   KIRANA_NIM=... KIRANA_NAMA="Nama Lengkap" bash scripts/package_submission.sh
# Isi zip: sql/, dashboard/ (SQL kartu, layout, skrip), scripts/, reports/insights (fakta + template), hasil uji (CSV), README, compose.
# Tidak ikut: raw_data/, *.duckdb, .env, .claude/, docs/, ekspor gambar dashboard.
set -euo pipefail
cd "$(dirname "$0")/.."
NIM=${KIRANA_NIM:-"[NIM]"}; NAMA=${KIRANA_NAMA:-"[Nama Lengkap]"}; BASE="UAS_BI_${NIM}_${NAMA// /}"
OUT=$(realpath -m "${1:-dist}"); mkdir -p "$OUT"; STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
[ -f kirana.duckdb ] || { echo "kirana.duckdb belum ada: bash scripts/build.sh"; exit 1; }
mkdir -p "$STAGE/hasil_uji"
for t in test_results test_results_demo reconciliation net_sales_bridge; do
  duckdb -readonly kirana.duckdb -c "COPY (SELECT * FROM dq.$t) TO '$STAGE/hasil_uji/$t.csv' (HEADER)"
done
cp -r sql scripts compose.yaml .env.example README.md "$STAGE/"
mkdir -p "$STAGE/dashboard" "$STAGE/reports/insights"
cp -r dashboard/questions dashboard/layout.json dashboard/provision.py dashboard/export.py dashboard/README.md dashboard/wireframe "$STAGE/dashboard/"
cp reports/insights/facts.sql reports/insights/brief.tpl.md reports/insights/insight_registry.md "$STAGE/reports/insights/"
cp reports/*.md "$STAGE/reports/"
find "$STAGE" -name '__pycache__' -prune -exec rm -rf {} +
# pemeriksaan akhir isi zip: tanpa berkas data mentah dan kredensial
if find "$STAGE" -name '*.duckdb' -o -name '.env' -o -path '*raw_data*' | grep -q .; then echo "GAGAL: berkas terlarang di paket"; exit 1; fi
rm -f "$OUT/${BASE}_SQL.zip"; (cd "$STAGE" && zip -qr "$OUT/${BASE}_SQL.zip" .)
[ -f dashboard/export/Dashboard_KIRANA.pdf ] && cp dashboard/export/Dashboard_KIRANA.pdf "$OUT/${BASE}_Dashboard.pdf"
ls -la "$OUT" | grep "$BASE"; unzip -l "$OUT/${BASE}_SQL.zip" | tail -1
