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

## 2026-06-02 — Økt 2: Fiks av lenke til NAV-statistikk

**Mål:** Oppdatere ødelagt kildelenke i bunnteksten.

**Gjort:**
- Erstattet utdatert lenke `nav.no/arbeid/statistikk/arbeidsmarkedstiltak` med ny offisiell URL:
  `nav.no/no/nav-og-samfunn/statistikk/arbeidssokere-og-stillinger-statistikk/tiltaksdeltakere`
- Rendret og verifisert at appen bygger uten feil

**Status:** Lenke i kildefooter fungerer nå korrekt ✅
