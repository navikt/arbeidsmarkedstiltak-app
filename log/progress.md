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
