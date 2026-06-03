# Parse NAV TILT-tidsserier til felles long-format
#
# Håndterer to formater:
#   - NYTT (≥ 2023-01): TILT100 (hovedgrupper) + TILT110–180 (undertyper),
#     én fil per TILT-kode per år.
#   - GAMMELT (≤ 2022-12): TILT030 (alle hovedgrupper og undertyper i én
#     fil per år, ark 4a/4b/4c = målgruppe, alder-blokker vertikalt).
#
# Utdata: to RDS i data/clean/parsed/
#   - hovedgruppe_tidsserie.rds  (kun hovedgrupper, undertype = NA)
#   - undertype_tidsserie.rds    (undertyper, hovedgruppe satt fra mapping)
#
# Skjema: (maalgruppe, hovedgruppe, undertype, periode, antall, prikket).

library(tidyverse)
library(readxl)
library(here)
library(fs)
library(lubridate)

dir_raw    <- here("data", "raw", "nav_excel", "tidsserie_alder")
dir_parsed <- here("data", "clean", "parsed")
dir_create(dir_parsed)

# 1. Mapping TILT-kode → hovedgruppenavn (gjelder TILT110–180) -----------

mapping_tilt_hovedgruppe <- c(
    TILT110 = "Lønnstilskudd",
    TILT120 = "Arbeidspraksis",
    TILT130 = "Opplæring",
    TILT140 = "Oppfølging",
    TILT150 = "Avklaringstiltak",
    TILT160 = "Arbeidsrettet rehabilitering",
    TILT170 = "Tilrettelagt arbeid",
    TILT180 = "Jobbskaping og egenetablering"   # NB: TILT180 inneholder
    # også Tilretteleggings-undertyper (Funksjonsassistanse, Inkluderings-
    # tilskudd, Tilskudd til ekspertbistand). Disse remappes nedenfor.
)

# TILT180-undertyper som hører hjemme under hovedgruppen "Tilrettelegging"
# (ikke "Jobbskaping og egenetablering"). Brukes i steg 5.
undertype_til_tilrettelegging <- c(
    "Funksjonsassistanse",
    "Inkluderingstilskudd",
    "Tilskudd til ekspertbistand"
)

# 2. Identifiser filer i nytt format -------------------------------------

filer <- dir_ls(dir_raw, regexp = "TILT") |>
    tibble(sti = _) |>
    mutate(
        filnavn = path_file(sti),
        tilt_kode = str_extract(filnavn, "TILT\\d{3}"),
        # Trekk ut YYYY og MM fra prefix. Formater: "202312_", "2026.04_"
        aar = str_extract(filnavn, "^\\d{4}") |> as.integer(),
        mnd = str_extract(filnavn, "(?<=^\\d{4}[._])\\d{2}") |> as.integer(),
        til_periode = make_date(aar, mnd, 1),
        # Bestem format
        fmt = case_when(
            tilt_kode == "TILT030" ~ "gammelt",
            tilt_kode %in% paste0("TILT", c(100, 110, 120, 130, 140, 150, 160, 170, 180)) ~ "nytt",
            TRUE ~ NA_character_
        )
    ) |>
    filter(!is.na(fmt))

cat("Identifisert ", nrow(filer), " TILT-filer (",
    sum(filer$fmt == "nytt"), " nytt format, ",
    sum(filer$fmt == "gammelt"), " gammelt format):\n", sep = "")
filer |> select(filnavn, tilt_kode, aar, mnd, fmt) |> print(n = Inf)

# 3. Hjelper: parse én "Arbeidsmarkedsstatus og tiltak"-ark ---------------
# Struktur: 3 blokker (Arbeidssøkere / Nedsatt arbeidsevne / Andre).
# Hver blokk: rad med "I alt X på tiltak" → så rader med hoved-/under-typer.
# Kolonner: kol 2 = "Gjennomsnitt hittil i år", kol 3–14 = jan–des.
# Måned-headere ligger i raden rett over "I alt"-raden.

fn_parse_blokker <- function(fil, aar) {
    # Ark-navnet varierer litt mellom filer: "Arbeidsmarkedsstatus og tiltaks"
    # (TILT100) vs "Arbeidsmarkedsstatus og tiltak" (TILT110+).
    ark_kandidater <- excel_sheets(fil)
    ark <- ark_kandidater[str_detect(ark_kandidater, "Arbeidsmarkedsstatus og tiltak")][1]
    if (is.na(ark)) stop("Fant ikke målgruppe-arket i ", path_file(fil))

    raw <- read_excel(fil, sheet = ark, col_names = FALSE,
                      .name_repair = "minimal")

    # Finn "I alt X på tiltak"-rader
    rot_rad <- which(
        str_detect(raw[[1]], "^I alt .* på tiltak\\.?$") |
        str_detect(raw[[1]], "^I alt .*, på tiltak\\.?$")
    )

    map_dfr(seq_along(rot_rad), function(i) {
        start <- rot_rad[i]
        slutt <- if (i < length(rot_rad)) rot_rad[i + 1] - 1 else nrow(raw)

        malgruppe <- raw[[1]][start] |>
            str_remove("^I alt\\s+") |>
            str_remove(",?\\s*på tiltak\\.?$") |>
            str_trim()

        # Måned-headere ligger i raden over "I alt"-raden (start - 1)
        if (start < 2) return(tibble())
        mnd_headere <- as.character(raw[start - 1, ])
        # kol 2 er "Gjennomsnitt hittil i år" — ignoreres
        mnd_indeks <- which(mnd_headere %in% c(
            "Januar","Februar","Mars","April","Mai","Juni",
            "Juli","August","September","Oktober","November","Desember"
        ))
        if (length(mnd_indeks) == 0) return(tibble())

        mnd_navn_til_nr <- c(
            "Januar"=1,"Februar"=2,"Mars"=3,"April"=4,"Mai"=5,"Juni"=6,
            "Juli"=7,"August"=8,"September"=9,"Oktober"=10,"November"=11,"Desember"=12
        )

        # Datarader: start til slutt, med ikke-NA i kol 1
        data_rader <- (start):slutt
        data_rader <- data_rader[!is.na(raw[[1]][data_rader])]

        map_dfr(data_rader, function(r) {
            kategori <- raw[[1]][r]
            er_i_alt <- str_detect(kategori, "^I alt")
            tibble(
                maalgruppe = malgruppe,
                kategori   = if (er_i_alt) "I alt" else kategori,
                periode    = make_date(aar, mnd_navn_til_nr[mnd_headere[mnd_indeks]], 1),
                antall_raw = as.character(raw[r, mnd_indeks])
            )
        })
    }) |>
        mutate(
            antall  = suppressWarnings(as.integer(antall_raw)),
            prikket = !is.na(antall_raw) & antall_raw == "*"
        ) |>
        select(-antall_raw)
}

# 3b. Hjelper: parse en TILT030-fil (gammelt format, før 2023) -----------
# Ark 4a/4b/4c per målgruppe; hver ark har alder-blokker vertikalt.
# Layout per alder-blokk:
#   rad N    : "<alder> <maalgruppe> på tiltak"
#   rad N+1  : måned-headere i kol 3-14
#   rad N+2  : "I alt <alder> <maalgruppe>..." med totaler kol 3-14
#   rad N+3  : tom
#   rad N+4– : hovedgruppe-rader (kol 1 = hovedgruppe, kol 2 = undertype)
#              + "I alt <hovedgruppe>"-rad

ark_til_maalgruppe <- c(
    "4a. Arbeidssøkere på tiltak Til"   = "Arbeidssøkere",
    "4b. Nedsatt arbeidsevne på tilt"   = "Nedsatt arbeidsevne",
    "4c. Andre på tiltak Tiltak  Ald"   = "Andre"
)

mnd_navn_til_nr <- c(
    "Januar"=1,"Februar"=2,"Mars"=3,"April"=4,"Mai"=5,"Juni"=6,
    "Juli"=7,"August"=8,"September"=9,"Oktober"=10,"November"=11,"Desember"=12
)

fn_parse_tilt030_ark <- function(fil, ark, malgruppe, aar) {
    raw <- read_excel(fil, sheet = ark, col_names = FALSE,
                      .name_repair = "minimal")

    # Finn alder-blokk-starter: rader i kol 1 med pattern "...<maalgruppe> på tiltak"
    # (men ikke "I alt"-rader)
    col1 <- as.character(raw[[1]])
    alder_rad <- which(
        !is.na(col1) &
        str_detect(col1, fixed(paste0(" ", tolower(malgruppe)))) &
        !str_starts(col1, "I alt") &
        !str_starts(col1, "Kilde")
    )

    if (length(alder_rad) == 0) return(tibble())

    map_dfr(seq_along(alder_rad), function(i) {
        start <- alder_rad[i]
        slutt <- if (i < length(alder_rad)) alder_rad[i + 1] - 1 else nrow(raw)

        # Måned-headere ligger i raden rett under alder-tittelen (start + 1)
        mnd_headere <- as.character(raw[start + 1, ])
        mnd_kol <- which(mnd_headere %in% names(mnd_navn_til_nr))
        if (length(mnd_kol) == 0) return(tibble())

        # Datarader: fra start+2 til slutt
        # Gyldige rader har noe i kol 2 (undertype)
        col2 <- as.character(raw[[2]])
        data_rader <- (start + 2):slutt
        data_rader <- data_rader[!is.na(col2[data_rader])]

        # Hovedgruppe propageres ned fra kol 1 (fylles ut når kol 1 ikke er NA)
        hovedgruppe_per_rad <- rep(NA_character_, nrow(raw))
        siste_hovedgruppe <- NA_character_
        for (r in seq_len(nrow(raw))) {
            if (!is.na(col1[r]) &&
                !str_starts(col1[r], "I alt") &&
                !str_detect(col1[r], fixed(paste0(" ", tolower(malgruppe)))) &&
                !str_starts(col1[r], "Kilde") &&
                col1[r] != "" &&
                !str_detect(col1[r], "^Januar - ")) {
                siste_hovedgruppe <- col1[r]
            }
            hovedgruppe_per_rad[r] <- siste_hovedgruppe
        }

        map_dfr(data_rader, function(r) {
            undertype <- col2[r]
            tibble(
                hovedgruppe = hovedgruppe_per_rad[r],
                undertype   = undertype,
                periode     = make_date(aar, mnd_navn_til_nr[mnd_headere[mnd_kol]], 1),
                antall_raw  = as.character(raw[r, mnd_kol])
            )
        })
    }) |>
        mutate(
            maalgruppe = malgruppe,
            antall = suppressWarnings(as.integer(antall_raw)),
            prikket = !is.na(antall_raw) & antall_raw == "*"
        ) |>
        select(maalgruppe, hovedgruppe, undertype, periode, antall, prikket)
}

# 4. Parse alle TILT100-filer → hovedgruppe-tidsserie ---------------------

cat("\n", strrep("-", 70), "\n", sep = "")
cat("Parser TILT100 (hovedgruppe-tidsserier)\n\n", sep = "")

hovedgruppe_long <- filer |>
    filter(tilt_kode == "TILT100") |>
    pmap_dfr(function(sti, aar, ...) {
        cat("  ", path_file(sti), "\n", sep = "")
        fn_parse_blokker(sti, aar) |>
            mutate(filkilde = path_file(sti))
    }) |>
    rename(hovedgruppe = kategori) |>
    # Dropp "I alt"-rader — vi har dem implisitt og rotnoden er på et annet sted
    filter(hovedgruppe != "I alt") |>
    mutate(undertype = NA_character_) |>
    select(maalgruppe, hovedgruppe, undertype, periode, antall, prikket, filkilde)

cat("\n  Rader: ", nrow(hovedgruppe_long), "\n", sep = "")
cat("  Periode: ", as.character(min(hovedgruppe_long$periode)),
    " – ", as.character(max(hovedgruppe_long$periode)), "\n", sep = "")
cat("  Målgrupper: ", paste(unique(hovedgruppe_long$maalgruppe), collapse = ", "), "\n", sep = "")
cat("  Hovedgrupper: ", paste(unique(hovedgruppe_long$hovedgruppe), collapse = ", "), "\n", sep = "")

# 5. Parse TILT110-180 → undertype-tidsserie ------------------------------

cat("\n", strrep("-", 70), "\n", sep = "")
cat("Parser TILT110–180 (undertype-tidsserier)\n\n", sep = "")

undertype_long <- filer |>
    filter(tilt_kode %in% paste0("TILT", c(110, 120, 130, 140, 150, 160, 170, 180))) |>
    pmap_dfr(function(sti, aar, tilt_kode, ...) {
        cat("  ", path_file(sti), "\n", sep = "")
        fn_parse_blokker(sti, aar) |>
            mutate(
                tilt_kode   = tilt_kode,
                hovedgruppe = mapping_tilt_hovedgruppe[tilt_kode],
                filkilde    = path_file(sti)
            )
    }) |>
    rename(undertype = kategori) |>
    filter(undertype != "I alt") |>
    # Remap TILT180-undertyper som hører til Tilrettelegging
    mutate(
        hovedgruppe = if_else(
            undertype %in% undertype_til_tilrettelegging,
            "Tilrettelegging",
            hovedgruppe
        )
    ) |>
    select(maalgruppe, hovedgruppe, undertype, periode, antall, prikket, filkilde)

cat("\n  Rader: ", nrow(undertype_long), "\n", sep = "")
cat("  Hovedgrupper representert: ",
    paste(unique(undertype_long$hovedgruppe), collapse = ", "), "\n", sep = "")

# 5b. Parse TILT030 (gammelt format, 2019-2022) ---------------------------

cat("\n", strrep("-", 70), "\n", sep = "")
cat("Parser TILT030 (gammelt format, 2019-2022)\n\n", sep = "")

tilt030_raw <- filer |>
    filter(fmt == "gammelt") |>
    pmap_dfr(function(sti, aar, ...) {
        cat("  ", path_file(sti), "\n", sep = "")
        map_dfr(names(ark_til_maalgruppe), function(ark) {
            fn_parse_tilt030_ark(sti, ark, ark_til_maalgruppe[[ark]], aar)
        }) |>
            mutate(filkilde = path_file(sti))
    })

cat("\n  Rader (rå, alder-detaljert): ", nrow(tilt030_raw), "\n", sep = "")

# Aggregér på tvers av alder. Tap av info: hvis én alder har * (prikket)
# mens andre har tall, blir totalen for-lav. Vi markerer "prikket = TRUE"
# hvis minst én alder-blokk var prikket — så pipelinen senere kan vurdere
# å skjule/dempe slike celler.
if (nrow(tilt030_raw) == 0) {
    tom <- tibble(
        maalgruppe = character(), hovedgruppe = character(), undertype = character(),
        periode = as.Date(character()), antall = integer(), prikket = logical(), filkilde = character()
    )
    tilt030_undertype   <- tom
    tilt030_hoofdgruppe <- tom
} else {

tilt030_undertype <- tilt030_raw |>
    filter(!is.na(undertype),
           !str_starts(undertype, "I alt")) |>
    # Mapping av undertyper som hører til Tilrettelegging-hovedgruppen
    # (i gammelt format finnes de typisk under "Jobbskaping og egenetablering")
    mutate(
        hovedgruppe = if_else(
            undertype %in% undertype_til_tilrettelegging,
            "Tilrettelegging",
            hovedgruppe
        )
    ) |>
    group_by(maalgruppe, hovedgruppe, undertype, periode, filkilde) |>
    summarise(
        antall = sum(antall, na.rm = TRUE),
        prikket = any(prikket),
        .groups = "drop"
    ) |>
    # Hvis alle alder-blokker var prikket og ingen tall fantes, blir
    # antall = 0 fra sum(.., na.rm=TRUE) — sett til NA istedet.
    mutate(antall = if_else(antall == 0 & prikket, NA_integer_, antall))

tilt030_hoofdgruppe <- tilt030_undertype |>
    group_by(maalgruppe, hovedgruppe, periode, filkilde) |>
    summarise(
        antall = sum(antall, na.rm = TRUE),
        prikket = any(prikket),
        .groups = "drop"
    ) |>
    mutate(
        antall = if_else(antall == 0 & prikket, NA_integer_, antall),
        undertype = NA_character_
    ) |>
    select(maalgruppe, hovedgruppe, undertype, periode, antall, prikket, filkilde)

cat("  Aggregert hovedgruppe: ", nrow(tilt030_hovedgruppe), " rader\n", sep = "")
cat("  Aggregert undertype:   ", nrow(tilt030_undertype), " rader\n", sep = "")

# Slå sammen med nytt-format-data
hovedgruppe_long <- bind_rows(hovedgruppe_long, tilt030_hovedgruppe)
undertype_long   <- bind_rows(undertype_long,
                              tilt030_undertype |>
                                  select(maalgruppe, hovedgruppe, undertype,
                                         periode, antall, prikket, filkilde))

cat("\n  Samlet periode etter merge: ",
    as.character(min(hovedgruppe_long$periode)), " – ",
    as.character(max(hovedgruppe_long$periode)), "\n", sep = "")

} # end else (tilt030 finnes)

# 6. Dedupliser — flere filer kan dekke samme periode --------------------
# Eks: 202312_TILT100 og 202412_TILT100 dekker ulike år; men hvis to filer
# dekker samme (kategori, periode, målgruppe), velger vi den fra nyeste fil.

dedupliser <- function(df) {
    df |>
        # Sortér slik at nyeste filkilde havner sist; distinct beholder først,
        # så vi reverserer.
        arrange(maalgruppe, hovedgruppe, undertype, periode, desc(filkilde)) |>
        distinct(maalgruppe, hovedgruppe, undertype, periode, .keep_all = TRUE) |>
        select(-filkilde)
}

hovedgruppe_long <- dedupliser(hovedgruppe_long)
undertype_long   <- dedupliser(undertype_long)

cat("\n  Etter dedup — hovedgruppe: ", nrow(hovedgruppe_long), " rader, ",
    "undertype: ", nrow(undertype_long), " rader\n", sep = "")

# 7. Sanity-sjekker -------------------------------------------------------

cat("\n", strrep("-", 70), "\n", sep = "")
cat("Sanity-sjekker\n\n", sep = "")

# Konsistens: sum av undertyper per hovedgruppe/målgruppe/periode skal
# stemme med tilsvarende rad i hovedgruppe_long
sjekk <- undertype_long |>
    group_by(maalgruppe, hovedgruppe, periode) |>
    summarise(sum_undertyper = sum(antall, na.rm = TRUE), .groups = "drop") |>
    left_join(
        hovedgruppe_long |> select(maalgruppe, hovedgruppe, periode, antall_hovedgruppe = antall),
        by = c("maalgruppe", "hovedgruppe", "periode")
    ) |>
    mutate(diff = sum_undertyper - antall_hovedgruppe)

avvik <- sjekk |> filter(!is.na(diff), abs(diff) > 0)
cat("  Konsistens-avvik: ", nrow(avvik), " (", round(100*nrow(avvik)/nrow(sjekk), 1), "%)\n", sep = "")
if (nrow(avvik) > 0) {
    cat("  Største 5 avvik:\n")
    avvik |> arrange(desc(abs(diff))) |> head(5) |> print()
}

# 8. Skriv til disk -------------------------------------------------------

write_rds(hovedgruppe_long, path(dir_parsed, "hovedgruppe_tidsserie.rds"))
write_csv(hovedgruppe_long, path(dir_parsed, "hovedgruppe_tidsserie.csv"))
write_rds(undertype_long,   path(dir_parsed, "undertype_tidsserie.rds"))
write_csv(undertype_long,   path(dir_parsed, "undertype_tidsserie.csv"))

cat("\n", strrep("=", 70), "\n", sep = "")
cat("Lagret:\n")
cat("  ", path(dir_parsed, "hovedgruppe_tidsserie.{rds,csv}"), "\n")
cat("  ", path(dir_parsed, "undertype_tidsserie.{rds,csv}"), "\n")
