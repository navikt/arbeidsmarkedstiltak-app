#!/usr/bin/env bash
# update.sh — månedlig oppdatering av datafortellingen.
#
# Kjør manuelt eller fra cron. Idempotent: trygt å kjøre flere ganger samme
# måned. Laster bare ned nye filer og melder fra bare hvis JSON-output endret seg.
#
# NAV publiserer TILT-statistikken månedlig. Eksakt dato er ikke verifisert
# mot offisielle kilder — vi venter til dag 20 som trygg buffer. Juster MIN_DAG
# hvis NAV publiserer tidligere/senere.
#
# Bruk:
#   ./update.sh            — normal kjøring (sjekker dato)
#   ./update.sh --force    — kjør selv om det er før dag 20
#
# Skriptet auto-committer og auto-publiserer IKKE. Etter at det melder om ny
# data: verifiser, kjør `quarto render`, og publiser etter datafortelling-
# oppskriften — deretter commit.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
LOG="$REPO/log/update.log"
MIN_DAG=20

force=false
for arg in "$@"; do
    case "$arg" in
        --force) force=true ;;
        *) echo "Ukjent flagg: $arg"; exit 2 ;;
    esac
done

ts() { date -Iseconds; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

mkdir -p "$(dirname "$LOG")"
log "=== Oppdatering startet ==="

dag=$(date +%-d)
if [[ "$force" != "true" && "$dag" -lt "$MIN_DAG" ]]; then
    log "Dag $dag < $MIN_DAG. Avbryter (bruk --force for å overstyre)."
    exit 0
fi

cd "$REPO"

# Snapshot av JSON-filer før pipeline. Ignorerer metadata.json fordi
# `generert`-feltet endres ved hver kjøring og gir falske diffs.
snapshot() {
    find data/web -name "*.json" ! -name "metadata.json" -exec md5sum {} + 2>/dev/null | sort
}
json_pre=$(snapshot || true)

log "Kjører pipeline 00 → 03 ..."
Rscript code/R/2026-05-24_00_last_ned.R       >>"$LOG" 2>&1
Rscript code/R/2026-05-24_01_parse_nav.R      >>"$LOG" 2>&1
Rscript code/R/2026-05-24_02_aggreger.R       >>"$LOG" 2>&1
Rscript code/R/2026-05-24_03_eksporter_json.R >>"$LOG" 2>&1

json_post=$(snapshot || true)

if [[ "$json_pre" == "$json_post" ]]; then
    log "Ingen endring i data/web/ — ingen ny NAV-data ennå."
    exit 0
fi

log "Ny data oppdaget. Diff:"
diff <(echo "$json_pre") <(echo "$json_post") | tee -a "$LOG" || true

log "=== Ny data klar. Manuelle steg gjenstår: ==="
log "  1. quarto render arbeidsmarkedstiltak.qmd  (verifiser lokalt)"
log "  2. Publiser etter datafortelling-oppskriften"
log "  3. git commit -am 'Månedlig oppdatering YYYY-MM'"
