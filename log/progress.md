# Logg — arbeidsmarkedstiltak-app

---

## 2026-06-02 — Økt 1: Oppsett og første publisering

**Mål:** Sette opp repo på navikt og publisere datafortellingen på datamarkedsplassen.

**Gjort:**
- Klonet nytt repo `navikt/arbeidsmarkedstiltak-app` til `Documents/copilot/`
- Opprettet `AGENTS.md` med instruksjoner for LLM-agenter
- Overført prosjektinnhold fra zip (`arbeidsmarkedstiltak-nav/`) og organisert til roten av repoet
- Lagt til `.github/workflows/publiser-datafortelling.yml` — renderer og publiserer ved push til `main`
- Oppdatert `maanedlig-oppdatering.yml` — publiserer automatisk etter månedlig datahenting
- Lagt inn `TEAM_TOKEN` som GitHub Actions-secret i repoet
- **Første publisering vellykket** ✅

**Status:**
- Fortellingen er live på datamarkedsplassen (intern, prod)
- Automatisk månedlig oppdatering er satt opp (cron dag 20)

**Neste steg (fremtidige økter):**
- Vurder NAV-profilering (farger/typografi — nå arvet grønntone `#1a6b4a`)
- Oppdater `actions/checkout` til versjon som støtter Node.js 24 (advarsel i Actions, frist 16. juni 2026)
- Evt. legge til flere tiltakstyper eller filtreringsmuligheter i fortellingen

---

## 2026-06-03 — Økt 3: Legg til «Andre på tiltak» som valgbar målgruppe

**Mål:** Inkludere den tredje NAV-målgruppen «Andre på tiltak» i hele appen.

**Bakgrunn:** Gruppen fantes i rådata men ble eksplisitt filtrert ut i R-pipeline.
Første-tab viste derfor bare Arbeidssøkere + Nedsatt arbeidsevne uten å opplyse om det.

**Gjort:**
- `02_aggreger.R`: Fjernet filter som droppet «Andre»; omdøper `"Andre"` → `"Andre på tiltak"` for klarere visning
- `03_eksporter_json.R`: Lagt til `"Andre på tiltak" = "andre"` → eksporterer `tiltakstyper_andre.json`
- `data/web/tiltakstyper_andre.json`: Stub (`[]`) slik at render ikke feiler før pipeline kjøres med rådata
- `arbeidsmarkedstiltak.qmd`:
  - Tab 1: fjerde KPI-boks for «Andre» — vises kondisjonelt når data finnes; oransje `#c05621` i linjegraf
  - Tab 2/3: radio-knapp inkluderer «Andre på tiltak»
  - Tab 3: filinnlasting for `tiltakstyper_andre.json` + tom-tilstand-melding ved tom stub
  - Null-guard i Tab 2 KPI-cellen (NaN-krasj når data ikke finnes i oversikt.json ennå)
  - CSS: `kpi-grid` bruker `auto-fit` for å romme 3 eller 4 bokser uten layout-brudd

**Status:**
- Kode committed og pushet til `main` — publisering kjøres via Actions
- «Andre på tiltak» vises i UI, men KPI/grafer er tomme inntil rådata lastes ned og pipeline kjøres
- Neste steg: kjør `update.sh --force` (evt. steg 00–03 manuelt) for å populere `tiltakstyper_andre.json` og «Andre»-rader i øvrige JSON-filer


**Mål:** Oppdatere ødelagt kildelenke i bunnteksten.

**Gjort:**
- Erstattet utdatert lenke `nav.no/arbeid/statistikk/arbeidsmarkedstiltak` med ny offisiell URL:
  `nav.no/no/nav-og-samfunn/statistikk/arbeidssokere-og-stillinger-statistikk/tiltaksdeltakere`
- Rendret og verifisert at appen bygger uten feil

**Status:** Lenke i kildefooter fungerer nå korrekt ✅

---

## 2026-06-16 — Økt 5: Oppdater til mai 2026-data + valideringsscript

**Mål:** Laste inn mai 2026-data og etablere programmatisk validering mot nav.no-kilde.

**Gjort:**

- Kjørt `00_last_ned.R`: Lastet ned 9 nye `202605_TILT*`-filer fra nav.no.
  NAV byttet filnavnformat fra `2026.04_` (med punkt) til `202605_` (uten punkt).
- Fikset `01_parse_nav.R`: Regex for `mnd`-ekstraksjon fra filnavn støtter nå
  begge formater (`YYYYMM_` og `YYYY.MM_`). Endring: `(?<=^\\d{4}[._])\\d{2}`
  → `^\\d{4}\\.?(\\d{2})` med `group = 1`.
- Kjørt full pipeline (steg 01 → 03). Alle JSON-er oppdatert til mai 2026:
  - Arbeidssøkere: 12 580 (mai 2026)
  - Nedsatt arbeidsevne: 67 603 (mai 2026)
  - Andre på tiltak: 4 885 (mai 2026)
- Nytt valideringsscript `code/R/2026-06-16_valider_data.R`:
  - Leser "I alt"-totaler fra TILT100-Excel og sammenligner med `oversikt.json`
  - Summerer `tiltakstyper_*.json` og sammenligner med `oversikt.json`
  - Skiller mellom prikkavvik (≤ 10, forventet) og ekte feil (> 10)
  - Avslutter med tydelig status: ✅ / ❌

**Valideringsresultat:**

- Excel-avvik: 8 (alle ≤ 3, forventet prikking)
- Intern konsistens-avvik: 63 (alle ≤ 7, forventet prikking)
- ✅ Ingen ekte feil — klar for publisering



**Mål:** Populere «Andre på tiltak»-kategorien med faktiske tall fra nav.no.

**Bakgrunn:** Koden fra Økt 3 var klar, men pipelinen hadde ikke blitt kjørt med rådata —
`tiltakstyper_andre.json` lå som tom stub `[]` og «Andre»-radene manglet i `oversikt.json`.

**Gjort:**
- Lastet ned 36 TILT-Excel-filer fra nav.no (TILT100–180, årganger 2023–2026)
- Fikset parser-krasj i `01_parse_nav.R`: tom TILT030-blokk (gammelt format, pre-2023)
  krasjmet på manglende kolonne `undertype` — lagt til guard for 0-rad-tilfellet
- Kjørt full pipeline (steg 00 → 03) — alle JSON-er oppdatert med ekte data:
  - `oversikt.json`: 3 målgrupper (Arbeidssøkere 13 032, Nedsatt 67 470, Andre 4 622 — apr 2026)
  - `tiltakstyper_andre.json`: 1 040 rader med tiltakstype-fordeling for Andre-gruppen
  - `hoofdgrupper.json`, `metadata.json` og øvrige JSON-er oppdatert
- Quarto rendret uten feil
- Committed og pushet til `main`

**Status:** Alle tre målgrupper har ekte data i appen ✅
