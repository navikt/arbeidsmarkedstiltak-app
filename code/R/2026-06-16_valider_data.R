# Validering av pipeline-output mot NAV TILT-rådata
#
# Dobbelsjekker at JSON-filene i data/web/ stemmer med tallene fra nav.no:
#
#   1. Excel-sjekk: Les "I alt"-totaler direkte fra TILT100-Excel
#      (siste fil) og sammenlign med oversikt.json for samme periode.
#
#   2. Intern konsistens: Summer tiltakstyper_*.json per målgruppe/periode
#      og sammenlign med oversikt.json.
#
# Utdata: tydelig rapport i konsollen + eventuell rapport til fil.
# Kjøres etter full pipeline (steg 00–03).

library(tidyverse)
library(readxl)
library(jsonlite)
library(here)
library(fs)

dir_raw  <- here("data", "raw", "nav_excel", "tidsserie_alder")
dir_web  <- here("data", "web")

# ─── 1. Les ferdig JSON-output ───────────────────────────────────────────────

oversikt      <- fromJSON(path(dir_web, "oversikt.json"))        |> as_tibble()
tilt_as       <- fromJSON(path(dir_web, "tiltakstyper_arbeidssokere.json")) |> as_tibble()
tilt_na       <- fromJSON(path(dir_web, "tiltakstyper_nedsatt.json"))       |> as_tibble()
tilt_an       <- fromJSON(path(dir_web, "tiltakstyper_andre.json"))         |> as_tibble()
meta          <- fromJSON(path(dir_web, "metadata.json"))

cat("=== Valideringsrapport ===\n")
cat("Generert:       ", meta$generert, "\n")
cat("Sist oppdatert: ", meta$sist_oppdatert, "\n")
cat("Perioder i JSON:", n_distinct(oversikt$periode), "\n")
cat("Siste periode:  ", max(oversikt$periode), "\n\n")

# ─── 2. Hent Excel-referansetall fra TILT100 (siste fil) ─────────────────────
#
# TILT100 er "Tiltaksdeltakere. Hovedgruppe og demografi."
# Arket "Arbeidsmarkedsstatus og tiltak*" inneholder en rad
#   "I alt X på tiltak" per målgruppe — disse er de offisielle totalene.

cat(strrep("-", 60), "\n")
cat("Del 1 — Excel ↔ JSON\n\n")

# Finn siste TILT100-fil
tilt100_filer <- dir_ls(dir_raw, regexp = "TILT100") |>
    tibble(sti = _) |>
    mutate(filnavn = path_file(sti)) |>
    arrange(desc(filnavn))

siste_tilt100 <- tilt100_filer$sti[1]
cat("Bruker Excel-fil: ", path_file(siste_tilt100), "\n\n")

# Les Excel-arket
ark <- excel_sheets(siste_tilt100) |>
    keep(\(a) str_detect(a, "Arbeidsmarkedsstatus og tiltak"))
ark <- ark[1]

raw <- read_excel(siste_tilt100, sheet = ark,
                  col_names = FALSE, .name_repair = "minimal")

# Finn "I alt X på tiltak"-rader
rot_rad <- which(
    str_detect(raw[[1]], "^I alt .* på tiltak\\.?$") |
    str_detect(raw[[1]], "^I alt .*, på tiltak\\.?$")
)

mnd_navn_til_nr <- c(
    "Januar"=1,"Februar"=2,"Mars"=3,"April"=4,"Mai"=5,"Juni"=6,
    "Juli"=7,"August"=8,"September"=9,"Oktober"=10,"November"=11,"Desember"=12
)

# Finn aar fra filnavnet (første 4 siffer)
aar_fil <- as.integer(str_extract(path_file(siste_tilt100), "^\\d{4}"))

# Hent "I alt"-totaler per målgruppe
excel_totaler <- map_dfr(rot_rad, function(r) {
    malgruppe <- raw[[1]][r] |>
        str_remove("^I alt\\s+") |>
        str_remove(",?\\s*på tiltak\\.?$") |>
        str_trim()

    # Måned-headere er raden over
    if (r < 2) return(tibble())
    mnd_headere <- as.character(raw[r - 1, ])
    mnd_indeks  <- which(mnd_headere %in% names(mnd_navn_til_nr))
    if (length(mnd_indeks) == 0) return(tibble())

    tibble(
        maalgruppe = malgruppe,
        periode    = make_date(aar_fil, mnd_navn_til_nr[mnd_headere[mnd_indeks]], 1),
        excel_ial  = as.integer(as.character(raw[r, mnd_indeks]))
    )
}) |>
    # Recode for å matche JSON
    mutate(
        maalgruppe = dplyr::recode(maalgruppe,
            "Andre"                = "Andre på tiltak",
            "Arbeidssøkere"        = "Arbeidssøkere",
            "Nedsatt arbeidsevne"  = "Nedsatt arbeidsevne"
        )
    ) |>
    filter(!is.na(excel_ial))

# Sammenlign med oversikt.json (kun perioder som finnes i Excel-filen)
sjekk_excel <- oversikt |>
    mutate(periode = as.Date(periode)) |>
    inner_join(excel_totaler, by = c("maalgruppe", "periode")) |>
    mutate(
        diff      = antall - excel_ial,
        avvik_pct = round(100 * diff / excel_ial, 2)
    )

# Avvik ≤ PRIKK_TERSKEL er forventede prikke-avvik (se kommentar i parseren:
# "I alt"-rader droppes og prikket data blir NA i summen).
# Avvik > PRIKK_TERSKEL er potensielle datafeil.
PRIKK_TERSKEL <- 10L

avvik_excel      <- sjekk_excel |> filter(abs(diff) > 0)
avvik_ekte       <- sjekk_excel |> filter(abs(diff) > PRIKK_TERSKEL)
avvik_prikk      <- sjekk_excel |> filter(abs(diff) > 0, abs(diff) <= PRIKK_TERSKEL)

cat("Perioder sjekket (per målgruppe × måned): ", nrow(sjekk_excel), "\n")
cat("Avvik totalt:                             ", nrow(avvik_excel),
    " (", nrow(avvik_prikk), " forventet prikk, ",
    nrow(avvik_ekte), " ekte feil)\n\n", sep = "")

if (nrow(avvik_ekte) == 0 && nrow(avvik_prikk) == 0) {
    cat("✅ Alle tall matcher Excel-kilde nøyaktig.\n\n")
} else if (nrow(avvik_ekte) == 0) {
    cat("✅ Ingen ekte avvik (diff ≤ ", PRIKK_TERSKEL, "). ",
        nrow(avvik_prikk), " prikkavvik er forventet.\n\n", sep = "")
} else {
    cat("❌ EKTE avvik funnet (diff > ", PRIKK_TERSKEL, ") — sjekk pipeline:\n\n", sep = "")
    avvik_ekte |>
        arrange(desc(abs(diff))) |>
        select(maalgruppe, periode, json_antall = antall, excel_ial, diff, avvik_pct) |>
        print(n = 20)
    cat("\n")
}

if (nrow(avvik_prikk) > 0) {
    cat("Forventede prikkavvik (diff 1–", PRIKK_TERSKEL, "; ikke bekymringsfullt):\n", sep = "")
    avvik_prikk |>
        arrange(desc(abs(diff))) |>
        select(maalgruppe, periode, json_antall = antall, excel_ial, diff) |>
        print(n = 10)
    cat("\n")
}

# Vis siste tilgjengelige måned per målgruppe
cat("Siste periode per målgruppe (Excel):\n")
excel_totaler |>
    group_by(maalgruppe) |>
    filter(periode == max(periode), !is.na(excel_ial)) |>
    select(maalgruppe, periode, excel_ial) |>
    arrange(maalgruppe) |>
    print()

cat("\nSiste periode per målgruppe (JSON):\n")
oversikt |>
    mutate(periode = as.Date(periode)) |>
    group_by(maalgruppe) |>
    filter(periode == max(periode)) |>
    select(maalgruppe, periode, antall) |>
    arrange(maalgruppe) |>
    print()

# ─── 3. Intern konsistens: tiltakstyper → oversikt ───────────────────────────

cat("\n", strrep("-", 60), "\n", sep = "")
cat("Del 2 — Intern konsistens (tiltakstyper summert → oversikt)\n\n")

tiltakstyper_alle <- bind_rows(tilt_as, tilt_na, tilt_an)

sum_tiltakstyper <- tiltakstyper_alle |>
    mutate(periode = as.Date(periode)) |>
    group_by(maalgruppe, periode) |>
    summarise(sum_tiltakstyper = sum(antall, na.rm = TRUE), .groups = "drop")

sjekk_intern <- oversikt |>
    mutate(periode = as.Date(periode)) |>
    inner_join(sum_tiltakstyper, by = c("maalgruppe", "periode")) |>
    mutate(
        diff = antall - sum_tiltakstyper,
        avvik_pct = round(100 * diff / antall, 2)
    )

avvik_intern <- sjekk_intern |> filter(abs(diff) > 0)

cat("Perioder sjekket: ", nrow(sjekk_intern), "\n")
cat("Avvik (|diff| > 0):", nrow(avvik_intern), "\n\n")

if (nrow(avvik_intern) == 0) {
    cat("✅ Alle tiltakstyper summer korrekt opp til oversikt.json-totalene.\n\n")
} else {
    avvik_ekte_intern <- avvik_intern |> filter(abs(diff) > PRIKK_TERSKEL)
    avvik_prikk_intern <- avvik_intern |> filter(abs(diff) <= PRIKK_TERSKEL)

    if (nrow(avvik_ekte_intern) == 0) {
        cat("✅ Ingen ekte avvik (diff ≤ ", PRIKK_TERSKEL, "). ",
            nrow(avvik_prikk_intern), " prikkavvik er forventet.\n\n", sep = "")
    } else {
        cat("❌ EKTE interne avvik (diff > ", PRIKK_TERSKEL, "):\n\n", sep = "")
        avvik_ekte_intern |>
            arrange(desc(abs(diff))) |>
            head(15) |>
            select(maalgruppe, periode, oversikt_antall = antall,
                   sum_tiltakstyper, diff, avvik_pct) |>
            print()
        cat("\n")
    }

    cat("Avvik fordelt på målgruppe (alle inkl. prikk):\n")
    avvik_intern |>
        group_by(maalgruppe) |>
        summarise(
            n_avvik   = n(),
            max_avvik = max(abs(diff)),
            snitt_avvik = round(mean(abs(diff)), 1),
            .groups = "drop"
        ) |>
        print()
}

# ─── 4. Oppsummering ─────────────────────────────────────────────────────────

cat("\n", strrep("=", 60), "\n", sep = "")
cat("Oppsummering\n\n")

siste_periode <- max(as.Date(oversikt$periode))
cat("Siste periode i appdata: ", as.character(siste_periode), "\n")
cat("Antall målgrupper:       ", n_distinct(oversikt$maalgruppe), "\n")
cat("Excel-avvik:             ", nrow(avvik_excel), "\n")
cat("Intern konsistens-avvik: ", nrow(avvik_intern), "\n\n")

if (nrow(avvik_excel) == 0 && nrow(avvik_intern) == 0) {
    cat("✅ Data ser ut til å stemme. Klar for quarto render og publisering.\n")
} else if (nrow(avvik_ekte) > 0 || any(avvik_intern |> filter(abs(diff) > PRIKK_TERSKEL) |> nrow() > 0)) {
    cat("❌ Ekte avvik funnet — undersøk pipeline før publisering.\n")
} else {
    cat("✅ Kun prikkavvik (diff ≤ ", PRIKK_TERSKEL, "). Klar for quarto render og publisering.\n", sep = "")
}
