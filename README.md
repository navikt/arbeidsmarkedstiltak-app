# arbeidsmarkedstiltak-app

Datafortelling som viser statistikk over deltakere på NAVs arbeidsmarkedstiltak — månedlige tidsserier per hovedgruppe og tiltakstype, for begge målgrupper (nedsatt arbeidsevne og ordinære arbeidssøkere).

Bygget som statisk **Quarto + OJS + Observable Plot**: all R-logikk kjøres lokalt og skriver ferdig JSON til `data/web/`, som datafortellingen leser i klienten. Ingen serverkjøring kreves.

Datakilde: NAV TILT-statistikk (åpne data fra nav.no). Oppdateres månedlig.

**Publisert:** https://data.ansatt.nav.no/story/dd400ca2-e4d8-43cb-8d10-bb2352375a59

## Struktur

```
arbeidsmarkedstiltak-app/
├── arbeidsmarkedstiltak.qmd   # Selve datafortellingen (OJS + Plot, leser data/web/*.json)
├── code/R/                    # Data-pipeline (kjøres lokalt før publisering)
│   ├── 2026-05-24_00_last_ned.R       # Last ned NAV TILT-Excel → data/raw/
│   ├── 2026-05-24_01_parse_nav.R      # Parse → data/clean/parsed/
│   ├── 2026-05-24_02_aggreger.R       # Aggreger → *_aggregert.rds
│   └── 2026-05-24_03_eksporter_json.R # Eksporter → data/web/*.json
├── data/
│   ├── raw/    # NAV TILT-Excel — månedlige snapshots (gitignored)
│   ├── clean/  # Mellomfiler (gitignored). tiltakskode_kategorier.csv er sjekket inn
│   └── web/    # JSON som datafortellingen leser (SJEKKET INN)
└── output/     # Eventuelle eksporterte tabeller/figurer
```

## Publisering

Fortellingen publiseres automatisk til **NAVs interne datamarkedsplass** via GitHub Actions:

- **Ved push til `main`** → `.github/workflows/publiser-datafortelling.yml` renderer og laster opp
- **Månedlig (dag 20)** → `.github/workflows/maanedlig-oppdatering.yml` henter ny TILT-data, committer og publiserer

Story ID: `dd400ca2-e4d8-43cb-8d10-bb2352375a59`  
Secret i repo: `TEAM_TOKEN` (hentes fra [datamarkedsplassen](https://data.ansatt.nav.no/user/tokens))

## Oppdateringsrutine (månedlig)

Når NAV publiserer ny TILT-fil:

1. `Rscript code/R/2026-05-24_00_last_ned.R`     — last ned til `data/raw/`
2. `Rscript code/R/2026-05-24_01_parse_nav.R`
3. `Rscript code/R/2026-05-24_02_aggreger.R`
4. `Rscript code/R/2026-05-24_03_eksporter_json.R` — oppdaterer `data/web/*.json`
5. `quarto render` og publiser på nytt.

`update.sh` automatiserer steg 1–4 (idempotent — trygt å kjøre flere ganger).

**Automatisk:** `.github/workflows/maanedlig-oppdatering.yml` kjører steg 1–4 via
GitHub Actions én gang i måneden (cron, dag 20), committer ny data og publiserer til datamarkedsplassen.

## Lisens

Data følger NAV-statistikkens åpne lisensvilkår.

