# Instruksjon til Claude — arbeidsmarkedstiltak-app

Denne fila er skrevet for en **ny Claude-økt** i dette repoet. Les hele fila først.

---

## 1. Hva dette er

En **datafortelling** som viser statistikk over deltakere på NAVs arbeidsmarkedstiltak
— månedlige tidsserier per hovedgruppe og tiltakstype, for tre målgrupper:
**Arbeidssøkere**, **Nedsatt arbeidsevne** og **Andre på tiltak**.

Teknisk stack: **Quarto + OJS + Observable Plot**. All R-logikk kjøres lokalt og
skriver ferdig JSON til `data/web/`, som datafortellingen leser i klienten. Ingen
serverkjøring kreves — sluttproduktet er statisk HTML.

Datakilde: NAV TILT-statistikk (åpne data fra nav.no), oppdateres månedlig.

**Publisert:** https://data.ansatt.nav.no/story/dd400ca2-e4d8-43cb-8d10-bb2352375a59

---

## 2. Nåværende tilstand (juni 2026)

Alt er satt opp og fungerer:

- ✅ Repo på `navikt/arbeidsmarkedstiltak-app`, publisert til NAVs datamarkedsplass
- ✅ Automatisk månedlig oppdatering via GitHub Actions (cron dag 20)
- ✅ Tre målgrupper med ekte data: Arbeidssøkere, Nedsatt arbeidsevne, Andre på tiltak
- ✅ Alle JSON-filer populert og sjekket inn — **siste data: mai 2026**

Nøkkelfiler som skal finnes:

```
arbeidsmarkedstiltak.qmd
code/R/2026-05-24_00_last_ned.R
code/R/2026-05-24_01_parse_nav.R
code/R/2026-05-24_02_aggreger.R
code/R/2026-05-24_03_eksporter_json.R
code/R/2026-06-16_valider_data.R      ← valideringsscript (nytt)
data/web/oversikt.json
data/web/hoofdgrupper.json
data/web/tiltakstyper_arbeidssokere.json
data/web/tiltakstyper_nedsatt.json
data/web/tiltakstyper_andre.json
data/web/metadata.json
data/clean/tiltakskode_kategorier.csv
```

---

## 3. Månedlig oppdatering

Når NAV publiserer ny TILT-fil (typisk rundt dag 20 hver måned):

**Automatisk:** GitHub Actions-workflowen kjører pipeline og committer ny data.
Sjekk Actions-fanen for å se om den kjørte OK.

**Manuelt (hvis Actions feilet eller du vil kjøre lokalt):**

```bash
Rscript code/R/2026-05-24_00_last_ned.R   # last ned fra nav.no
Rscript code/R/2026-05-24_01_parse_nav.R
Rscript code/R/2026-05-24_02_aggreger.R
Rscript code/R/2026-05-24_03_eksporter_json.R
Rscript code/R/2026-06-16_valider_data.R  # valider mot Excel-kilde
quarto render arbeidsmarkedstiltak.qmd
# deretter commit data/web/*.json og push
```

`update.sh --force` kjører steg 1–4 i én kommando.

### Valideringsscript

`code/R/2026-06-16_valider_data.R` kjøres etter pipeline og gjør:

1. **Excel ↔ JSON**: Leser "I alt"-totaler fra siste TILT100-fil og sammenligner
   med `oversikt.json`. Avvik ≤ 10 regnes som forventede prikkavvik (NAV prikkmerker
   celler med `*` som blir NA i summen). Avvik > 10 er ekte datafeil.
2. **Intern konsistens**: Summer `tiltakstyper_*.json` per målgruppe/periode og
   sammenligner med `oversikt.json`. Avvik er typisk forventede prikkavvik.

Scriptet avslutter med `✅ Klar for quarto render` hvis ingen ekte feil finnes.

---

## 4. Kjente særheter

- **TILT030 (gammelt format, pre-2023):** Finnes ikke lenger på nav.no. Parseren
  håndterer tom liste med en guard. Ingen tiltak nødvendig.
- **Brudd-flagg:** Gjelder kun Arbeidssøkere (registeromlegging apr–jul 2025).
  Nedsatt arbeidsevne og Andre på tiltak er upåvirket.
- **Andre på tiltak:** Ca. 5 % av totalen (4 622 apr 2026). Tiltakstype-data
  er tilgjengelig via TILT110–180 og eksporteres til `tiltakstyper_andre.json`.

---

## 5. Viktige rammer

- Kun NAVs **åpne, aggregerte** TILT-statistikk — ingen individdata i repoet
- `data/raw/` og `data/clean/` er gitignored (unntatt `tiltakskode_kategorier.csv`)
- `data/web/*.json` SKAL være sjekket inn og oppdatert etter hver pipeline-kjøring
