# arbeidsmarkedstiltak-app

Datafortelling som viser statistikk over deltakere på NAVs arbeidsmarkedstiltak — månedlige tidsserier per hovedgruppe og tiltakstype, for begge målgrupper (nedsatt arbeidsevne og ordinære arbeidssøkere).

Bygget som statisk **Quarto + OJS + Observable Plot**: all R-logikk kjøres lokalt og skriver ferdig JSON til `data/web/`, som datafortellingen leser i klienten. Ingen serverkjøring kreves.

Datakilde: NAV TILT-statistikk (åpne data fra nav.no). Oppdateres månedlig.

> Dette er en selvstendig kopi klargjort for publisering som datafortelling via jobb-konto (github.com/navikt). Den har ingen kobling til den private hjemmesiden eller dens kopi.

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

## Publisering (datafortelling)

Følg NAVs interne oppskrift for å publisere en datafortelling. Stegene som er
spesifikke for det oppsettet (token, _quarto.yml-publiseringsblokk, nada-/CLI-kall)
legges til når oppskriften følges — se TODO-markører nedenfor.

1. Opprett repo under github.com/navikt og push denne mappa.
2. Render lokalt for å verifisere: `quarto render arbeidsmarkedstiltak.qmd`
3. Publiser etter datafortelling-oppskriften.

## Oppdateringsrutine (månedlig)

Når NAV publiserer ny TILT-fil:

1. `Rscript code/R/2026-05-24_00_last_ned.R`     — last ned til `data/raw/`
2. `Rscript code/R/2026-05-24_01_parse_nav.R`
3. `Rscript code/R/2026-05-24_02_aggreger.R`
4. `Rscript code/R/2026-05-24_03_eksporter_json.R` — oppdaterer `data/web/*.json`
5. `quarto render` og publiser på nytt.

`update.sh` automatiserer steg 1–4 (idempotent — trygt å kjøre flere ganger).

**Automatisk:** `.github/workflows/maanedlig-oppdatering.yml` kjører steg 1–4 via
GitHub Actions én gang i måneden (cron, dag 20) og committer ny data automatisk.
Publiseringssteget kobles på etter NAVs datafortelling-oppskrift — se workflow-fila
og `instruksjon.md`.

## TODO før første publisering

- [ ] Bekreft at datafortelling-oppskriften godtar separate `data/web/*.json` (ev. sett `embed-resources: true` i qmd-frontmatter for å inline alt i én HTML).
- [ ] Legg til ev. `_quarto.yml` / publiseringskonfig som oppskriften krever.
- [ ] Vurder NAV-profilering (farger/typografi) — dagens tema arvet grønntonen (#1a6b4a) fra den private siden; bytt om ønskelig.

## Lisens

Data følger NAV-statistikkens åpne lisensvilkår.

