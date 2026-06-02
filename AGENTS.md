# AGENTS.md — Retningslinjer for LLM-agenter

Dette dokumentet leses av GitHub Copilot ved oppstart av hver økt i `arbeidsmarkedstiltak-app`-repoet.

---

## Om prosjektet

Dette repoet inneholder kildekode og dokumentasjon for en **datafortelling** om arbeidsmarkedstiltak i NAV.
Formålet er å gjøre statistikk over antall deltakere på Navs arbeidsmarkedstiltak lettere å navigere og forstå.

Datafortellingen er bygget med **Quarto** (`.qmd`-filer), og rendres til HTML-rapport.

---

## ⚠️ KRITISK — Faktiske registerdata må aldri inn i dette repoet

Dette er den **aller viktigste regelen**. Den slår alle andre regler.

**Definisjon:** *Faktiske registerdata* = mikrodata fra NAV/DVH/SSB/FREG som beskriver virkelige personer (uansett om identifisert, pseudonymisert eller delvis aggregert til lavt nivå).

### Tillatte filer i repoet

| Filtype | Eksempel | Status |
|---------|---------|--------|
| `.qmd`, `.R`, `.py`, `.sql` | Kildekode og skript | ✅ OK |
| `.md`, `.yaml`, `.json` | Konfigurasjon og dokumentasjon | ✅ OK |
| `.csv`, `.xlsx` o.l. | Aggregerte kodelister / metadata | ✅ OK hvis aggregert |
| `.csv`, `.parquet` o.l. | Mikrodata / registereksporter | ❌ Aldri |

**Hvis slik data havner i repoet:**

1. **Slett umiddelbart** fra arbeidskopien — uten å spørre først
2. **Si fra til brukeren** med en gang
3. **Aldri commit, aldri push** — selv ikke «midlertidig»

---

## Mappestruktur (planlagt)

```
arbeidsmarkedstiltak-app/
├── data/              ← kun aggregerte, ikke-sensitive data
├── R/                 ← hjelpefunksjoner og dataprosessering
├── figures/           ← genererte figurer (ikke commites automatisk)
├── docs/              ← rendret HTML-output fra Quarto
├── _quarto.yml        ← Quarto-prosjektkonfigurasjon
├── index.qmd          ← hovedside / forside
├── AGENTS.md          ← denne filen
└── README.md
```

---

## Teknisk oppsett

- **Verktøy:** Quarto + R (tidyverse)
- **Rendering:** `quarto render` fra prosjektrot
- **Output:** HTML (primært), eventuelt PDF

```r
# Render enkeltdokument:
quarto::quarto_render("index.qmd")

# Render hele prosjektet:
# quarto render (fra terminal i prosjektrot)
```

---

## Kodestil

Følg global stilguide i `C:\Users\L158017\.copilot\kodestil.md`.

### R (sammendrag)
- **tidyverse**-pakker der det er naturlig
- Native pipe `|>` (ikke `%>%`)
- 4 mellomrom for innrykk
- `snake_case` for variabel- og funksjonsnavn
- Kommentarer forklarer **hvorfor**, ikke hva

### Quarto / Markdown
- Skriv tekst på **norsk**
- Bruk beskrivende chunk-labels (`#| label: fig-deltakere-over-tid`)
- Skjul kode fra sluttbruker der det er naturlig (`echo: false`)
- Bruk `fig-cap` og `tbl-cap` for figurer og tabeller

---

## Språk

- Svar og forklaringer: **norsk**
- Variabelnavn i kode: **engelske, `snake_case`**
- Filnavn: **snake_case**
- Innhold i rapporten (tekst, aksetitler, figurtekster): **norsk**

---

## Git-rutine

```bash
git add .
git commit -m "kort beskrivelse på norsk"
git push
```

Commit-meldinger skal være på **norsk imperativ**, f.eks.:
- `Legg til figur over deltakere per tiltakstype`
- `Fiks feil i beregning av andel`
- `Oppdater README med kjøreinstuksjoner`

---

## Regler som alltid gjelder

- **Slett aldri skript eller dokumentasjon** — uansett grunn
- **Jobb innenfor prosjektets rotmappe** — ingen operasjoner utenfor uten eksplisitt instruks
- **Ingen mikrodata i git** — kun aggregater, kodelister, metadata og skript committes
- Gjør presise, kirurgiske endringer — ikke endre kode som ikke er relevant for oppgaven
- Ved usikkerhet om omfang eller atferd — spør brukeren før du handler
