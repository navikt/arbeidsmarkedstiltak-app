# Aggreger parserens long-format-tabeller til de tre output-skjemaene som
# appens tre tabs trenger:
#   - oversikt:    målgruppe × periode (Tab 1 — KPI + linjegraf)
#   - hovedgruppe: målgruppe × hovedgruppe × periode (Tab 2 — small multiples)
#   - tiltakstype: målgruppe × hovedgruppe × undertype × periode (Tab 3 — drill-down)
#
# Inn:  data/clean/parsed/hovedgruppe_tidsserie.rds, undertype_tidsserie.rds
# Ut:   data/clean/parsed/{oversikt,hovedgruppe,tiltakstype}_aggregert.{rds,csv}
#
# Beslutninger (jf. designplanen):
#   - Kun målgruppene Arbeidssøkere + Nedsatt arbeidsevne (drop "Andre"; ikke
#     appens skop, jf. CLAUDE.md "Datadekning")
#   - Q4: absolutte tall, ingen indeksering. Avledede felter beregnes i OJS
#     hvis nødvendig
#   - Q3: ingen markering av format-bruddet 2023 (TILT030 → TILT100 er
#     allerede harmonisert av parseren)
#   - Statistikkbruddet april-juli 2025 (nytt arbeidssøkerregister) flagges
#     med kolonnen `brudd` — frontend velger om den vil dempe/skjule/merke

library(tidyverse)
library(here)
library(fs)
library(lubridate)

dir_parsed <- here("data", "clean", "parsed")

hovedgruppe_long <- read_rds(path(dir_parsed, "hovedgruppe_tidsserie.rds"))
undertype_long   <- read_rds(path(dir_parsed, "undertype_tidsserie.rds"))

# 1. Filtrer til appens målgrupper ---------------------------------------

maalgrupper_app <- c("Arbeidssøkere", "Nedsatt arbeidsevne")

hovedgruppe_long <- hovedgruppe_long |> filter(maalgruppe %in% maalgrupper_app)
undertype_long   <- undertype_long   |> filter(maalgruppe %in% maalgrupper_app)

# 2. Statistikkbrudd-flagg ------------------------------------------------
# NAV la om arbeidssøkerregisteret våren 2025; mars-tall til september-tall
# faller fra ~18k til ~9k for Arbeidssøkere. Nedsatt arbeidsevne er ikke
# berørt på samme måte, men flagges også fordi enkelt-tiltak kan ha mindre
# brudd. Frontend kan filtrere på `brudd == TRUE` for å dempe punktene.

periode_brudd <- seq(as.Date("2025-04-01"), as.Date("2025-07-01"), by = "month")

fn_legg_til_brudd <- function(df) {
    df |>
        mutate(
            brudd = maalgruppe == "Arbeidssøkere" & periode %in% periode_brudd
        )
}

# 3. Oversikt — sum av alle hovedgrupper per (målgruppe, periode) ---------

oversikt <- hovedgruppe_long |>
    group_by(maalgruppe, periode) |>
    summarise(
        antall  = sum(antall, na.rm = TRUE),
        prikket = any(prikket),
        .groups = "drop"
    ) |>
    fn_legg_til_brudd()

cat("Oversikt: ", nrow(oversikt), " rader (",
    n_distinct(oversikt$maalgruppe), " målgrupper × ",
    n_distinct(oversikt$periode), " perioder)\n", sep = "")

# 4. Hovedgruppe — direkte fra parsed, men ryddet ------------------------

hovedgruppe <- hovedgruppe_long |>
    select(maalgruppe, hovedgruppe, periode, antall, prikket) |>
    arrange(maalgruppe, hovedgruppe, periode) |>
    fn_legg_til_brudd()

cat("Hovedgruppe: ", nrow(hovedgruppe), " rader (",
    n_distinct(paste(hovedgruppe$maalgruppe, hovedgruppe$hovedgruppe)),
    " målgruppe×hovedgruppe-kombinasjoner)\n", sep = "")

# 5. Tiltakstype — flat (målgruppe, hovedgruppe, undertype, periode) -----

tiltakstype <- undertype_long |>
    select(maalgruppe, hovedgruppe, undertype, periode, antall, prikket) |>
    arrange(maalgruppe, hovedgruppe, undertype, periode) |>
    fn_legg_til_brudd()

cat("Tiltakstype: ", nrow(tiltakstype), " rader (",
    n_distinct(paste(tiltakstype$maalgruppe, tiltakstype$hovedgruppe, tiltakstype$undertype)),
    " unike serier)\n", sep = "")

# 6. Sanity-sjekk: oversikt-totaler skal være >= hovedgruppe-totaler -----

cat("\n", strrep("-", 70), "\n", sep = "")
cat("Sanity-sjekk: oversikt vs sum av hovedgrupper\n\n", sep = "")

sjekk <- hovedgruppe |>
    group_by(maalgruppe, periode) |>
    summarise(sum_hovedgrupper = sum(antall, na.rm = TRUE), .groups = "drop") |>
    left_join(
        oversikt |> select(maalgruppe, periode, oversikt_antall = antall),
        by = c("maalgruppe", "periode")
    ) |>
    mutate(diff = sum_hovedgrupper - oversikt_antall)

avvik <- sjekk |> filter(abs(diff) > 0)
cat("  Konsistens-avvik: ", nrow(avvik), "/", nrow(sjekk),
    " (skal være 0 — oversikt = sum av hovedgrupper)\n", sep = "")

# 7. Skriv til disk ------------------------------------------------------

write_rds(oversikt,    path(dir_parsed, "oversikt_aggregert.rds"))
write_csv(oversikt,    path(dir_parsed, "oversikt_aggregert.csv"))
write_rds(hovedgruppe, path(dir_parsed, "hovedgruppe_aggregert.rds"))
write_csv(hovedgruppe, path(dir_parsed, "hovedgruppe_aggregert.csv"))
write_rds(tiltakstype, path(dir_parsed, "tiltakstype_aggregert.rds"))
write_csv(tiltakstype, path(dir_parsed, "tiltakstype_aggregert.csv"))

cat("\n", strrep("=", 70), "\n", sep = "")
cat("Lagret til ", dir_parsed, ":\n", sep = "")
cat("  oversikt_aggregert.{rds,csv}    — Tab 1\n")
cat("  hovedgruppe_aggregert.{rds,csv} — Tab 2\n")
cat("  tiltakstype_aggregert.{rds,csv} — Tab 3\n")
