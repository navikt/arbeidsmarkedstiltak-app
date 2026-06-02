# Instruksjon til Claude — oppsett av datafortellingen på jobb-PC (NAV)

Denne fila er skrevet for en **ny Claude-økt på jobb-PC-en**, som ikke har tilgang
til den opprinnelige samtalen eller til den private hjemmesiden der appen ble laget.
Les hele fila først. Den forteller hva prosjektet er, hva som allerede er gjort, og
hva du (Claude) skal hjelpe brukeren med å fullføre.

---

## 1. Hva dette er

En **datafortelling** som viser statistikk over deltakere på NAVs arbeidsmarkedstiltak
— månedlige tidsserier per hovedgruppe og tiltakstype, for to målgrupper (nedsatt
arbeidsevne og ordinære arbeidssøkere).

Teknisk stack: **Quarto + OJS + Observable Plot**. All R-logikk kjøres lokalt og
skriver ferdig JSON til `data/web/`, som datafortellingen leser i klienten. Ingen
serverkjøring kreves — sluttproduktet er statisk HTML.

Datakilde: NAV TILT-statistikk (åpne data fra nav.no), oppdateres månedlig.

## 2. Opphav og hva som er gjort

Denne mappa er en **selvstendig, renset kopi** av en privat versjon som lå på en
personlig hjemmeside (Quarto Pub). Kopien er bevisst strippet for alt som koblet mot
den private siden: Shinylive-rester, render-output (`*.html`, `*_files/`), interne
notater, dokumenter og legacy-filer. Den skal stå helt på egne bein.

Det som **er på plass og verifisert lokalt før overføring**:

- `arbeidsmarkedstiltak.qmd` — selve datafortellingen (OJS + Observable Plot)
- `code/R/` — komplett pipeline i fire steg (00 last ned → 03 eksporter JSON)
- `data/web/*.json` — de fem JSON-filene datafortellingen leser (SJEKKET INN, klare)
- `data/clean/tiltakskode_kategorier.csv` — kategorimapping (sjekket inn)
- `README.md`, `update.sh`, `.gitignore`, tomme `log/` og `output/`

Mappa var **ikke** et git-repo ved overføring (ingen `.git/`). Den ble pakket som zip
og lastet ned hit. Brukeren oppretter nå et nytt repo under **github.com/navikt**.

## 3. Hva du (Claude) skal hjelpe med

Målet er å få datafortellingen publisert via NAVs interne datafortelling-oppskrift,
fra et repo under github.com/navikt. Gå gjennom punktene under sammen med brukeren.

### 3a. Verifiser at innholdet kom helt over

Sjekk at disse finnes og ikke er tomme:

```
arbeidsmarkedstiltak.qmd
code/R/2026-05-24_00_last_ned.R
code/R/2026-05-24_01_parse_nav.R
code/R/2026-05-24_02_aggreger.R
code/R/2026-05-24_03_eksporter_json.R
data/web/hovedgrupper.json
data/web/oversikt.json
data/web/tiltakstyper_arbeidssokere.json
data/web/tiltakstyper_nedsatt.json
data/web/metadata.json
data/clean/tiltakskode_kategorier.csv
```

`data/web/*.json` er hele poenget — uten dem viser fortellingen tomme plott. De skal
allerede ligge i zip-en; pipelinen trenger **ikke** kjøres for å se fortellingen.

### 3b. Render lokalt for å bekrefte at den fungerer

```bash
quarto render arbeidsmarkedstiltak.qmd
```

Forventet: render fullfører på få sekunder, og HTML-en viser KPI-rad + interaktive
plott (hovedgrupper, tiltakstyper for begge målgrupper). Hvis plottene er tomme:
sjekk at `data/web/*.json` faktisk ligger der og at stiene i qmd-en stemmer.

### 3c. Initialiser git og opprett navikt-repo

Brukeren gjør dette fra jobb-kontoen sin:

```bash
git init
git add .
git commit -m "Initial: datafortelling arbeidsmarkedstiltak"
# opprett tomt repo under github.com/navikt, legg til som remote, push
```

`.gitignore` er allerede satt opp riktig: `data/raw/` og `data/clean/` holdes utenfor
git (untatt `tiltakskode_kategorier.csv`), mens `data/web/*.json` SKAL inn. Ikke endre
dette uten grunn.

### 3d. Følg NAVs datafortelling-oppskrift (det som gjenstår)

Disse punktene krevde tilgang til NAVs interne oppskrift og kunne ikke fullføres på
privat maskin. Hjelp brukeren å lukke dem:

- [ ] **Bekreft at oppskriften godtar separate `data/web/*.json`.** Hvis publiserings-
      løsningen krever én selvstendig fil, sett `embed-resources: true` i qmd-
      frontmatteren for å inline alt i én HTML.
- [ ] **Legg til `_quarto.yml` / publiseringskonfig** som oppskriften krever (token,
      publiseringsblokk, ev. `nada`-/CLI-kall).
- [ ] **Vurder NAV-profilering.** Temaet arvet i dag grønntonen `#1a6b4a` og en del
      inline CSS fra den private siden (se `<style>`-blokken i qmd-frontmatteren).
      Bytt til NAV-farger/typografi hvis ønskelig.

## 4. Månedlig oppdatering — to spor

### Lokalt (manuelt)

Når NAV publiserer ny TILT-fil, kan pipelinen kjøres lokalt (krever R + pakkene i
skriptene). `update.sh` automatiserer steg 1–4 og er idempotent:

```bash
./update.sh          # sjekker dato (venter til dag 20 som buffer)
./update.sh --force  # kjør uansett
```

Skriptet auto-committer og auto-publiserer **ikke**. Etter at det melder om ny data:
`quarto render`, verifiser, publiser etter oppskriften, deretter commit.

### Automatisk (GitHub Actions — schedulering)

`.github/workflows/maanedlig-oppdatering.yml` kjører pipelinen **automatisk én gang i
måneden** (cron: dag 20 kl. 06:00 UTC) og kan også startes manuelt fra Actions-fanen.
Den setter opp R, installerer pakkene, kjører pipeline 00→03, og committer
`data/web/`-endringer tilbake til repoet **bare hvis det faktisk kom ny statistikk**.

Det du (Claude) må hjelpe brukeren å sjekke/fullføre når repoet ligger på navikt:

- [ ] **Actions må være aktivert** i navikt-repoet (Settings → Actions). Noen
      organisasjoner har dette avskrudd som standard.
- [ ] **Skrivetilgang for workflowen.** Den bruker `permissions: contents: write` for å
      kunne committe data tilbake. Sjekk at Settings → Actions → "Workflow permissions"
      tillater "Read and write permissions" hvis pushen feiler.
- [ ] **Publiseringssteget er ikke koblet på ennå.** Workflowen oppdaterer og committer
      data, men publiserer ikke. Nederst i yml-fila ligger en utkommentert blokk som
      viser hvor `quarto-dev/quarto-actions/setup` + publiseringskall og `NADA_TOKEN`
      (eller tilsvarende secret) skal inn. Fyll den ut etter NAVs datafortelling-
      oppskrift, og legg secrets under Settings → Secrets and variables → Actions.
- [ ] **Verifiser cron-tiden.** Juster `cron`-uttrykket hvis NAV publiserer på en annen
      dag enn forutsatt (dag 20).

Detaljer står i `README.md`, i toppkommentaren i `update.sh`, og i kommentarene i
selve workflow-fila.

## 5. Viktige rammer

- Dette repoet skal **ikke** referere til, lenke til eller avhenge av den private
  hjemmesiden eller dens repo. Det er en selvstendig leveranse.
- Persondata: pipelinen bruker kun NAVs **åpne, aggregerte** TILT-statistikk. Ingen
  individdata, fødselsnumre eller interne URL-er skal inn i repoet.
- Når oppsettet er fullført: oppdater `README.md` med de faktiske publiserings-
  stegene (erstatt TODO-markørene) slik at neste oppdatering blir rett fram.
