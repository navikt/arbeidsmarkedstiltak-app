# Last ned NAV TILT-tidsserier (Fase 1b)
#
# Scraper NAV-landingssiden og årsarkivene, identifiserer TILT100-TILT180
# månedlige tidsserie-filer, og laster ned alt som mangler i
# data/raw/nav_excel/.
#
# URL-en til hver fil inneholder en versjonshash som endres ved hver
# oppdatering — derfor scraper vi sidene istedenfor å hardkode URL-er.

library(tidyverse)
library(rvest)
library(here)
library(fs)

# 1. Konfig --------------------------------------------------------------

base_url <- "https://www.nav.no"

# Sider å scrape: nåværende (siste publisering) + årsarkiv per ferdig år
sider <- tribble(
    ~aar,   ~url,
    "current", "https://www.nav.no/no/nav-og-samfunn/statistikk/arbeidssokere-og-stillinger-statistikk/tiltaksdeltakere",
    "2025",    "https://www.nav.no/no/nav-og-samfunn/statistikk/arbeidssokere-og-stillinger-statistikk/relatert-informasjon/arkiv-tiltaksdeltakere.2025",
    "2024",    "https://www.nav.no/no/nav-og-samfunn/statistikk/arbeidssokere-og-stillinger-statistikk/relatert-informasjon/arkiv-tiltaksdeltakere.2024",
    "2023",    "https://www.nav.no/no/nav-og-samfunn/statistikk/arbeidssokere-og-stillinger-statistikk/relatert-informasjon/arkiv-tiltaksdeltakere.2023"
)

dir_raw <- here("data", "raw", "nav_excel", "tidsserie_alder")
dir_create(dir_raw)

# 2. Hjelper: hent alle xlsx-lenker fra én side ---------------------------

fn_hent_lenker <- function(url) {
    sida <- read_html(url)

    lenker <- sida |>
        html_elements("a") |>
        keep(\(a) {
            href <- html_attr(a, "href")
            !is.na(href) &&
                str_detect(href, "\\.xlsx?(\\?|$)") &&
                str_detect(href, "TILT", negate = FALSE)
        })

    tibble(
        url        = map_chr(lenker, html_attr, "href"),
        anchor     = map_chr(lenker, html_text2)
    ) |>
        mutate(
            url = if_else(str_starts(url, "http"), url, paste0(base_url, url)),
            # Filnavn er siste segment, URL-dekodet
            filnavn = url |>
                str_extract("[^/]+\\.xlsx?(?=\\?|$)") |>
                utils::URLdecode()
        )
}

# 3. Bygg samlet liste -----------------------------------------------------

cat("Henter lenker fra", nrow(sider), "sider ...\n\n")

alle_lenker <- sider |>
    mutate(lenker = map(url, fn_hent_lenker)) |>
    select(aar_kilde = aar, lenker) |>
    unnest(lenker) |>
    # Bare månedlige tidsserier (TILT100-180), ikke årsgjennomsnitt-tabeller
    filter(
        str_detect(filnavn, "TILT1[0-8]0"),
        str_detect(filnavn, regex("Tidsserie.*maaned", ignore_case = TRUE))
    ) |>
    distinct(filnavn, .keep_all = TRUE)

cat("Fant ", nrow(alle_lenker), " TILT-tidsserie-filer.\n\n", sep = "")
print(alle_lenker |> select(aar_kilde, filnavn), n = Inf)

# 4. Last ned alt som mangler ---------------------------------------------

cat("\n", strrep("-", 70), "\n", sep = "")

resultater <- alle_lenker |>
    mutate(
        lokal = path(dir_raw, filnavn),
        finnes = file_exists(lokal)
    )

skip <- resultater |> filter(finnes)
nye  <- resultater |> filter(!finnes)

cat("Allerede lokalt: ", nrow(skip), " filer (hoppes over)\n", sep = "")
cat("Lastes ned:      ", nrow(nye), " filer\n\n", sep = "")

if (nrow(nye) > 0) {
    pwalk(nye, function(url, filnavn, lokal, ...) {
        cat("  → ", filnavn, " ... ", sep = "")
        download.file(url, lokal, mode = "wb", quiet = TRUE)
        cat("OK (", path_file(lokal), ", ",
            format(file_size(lokal)), ")\n", sep = "")
    })
}

# 5. Oppsummer -------------------------------------------------------------

cat("\n", strrep("=", 70), "\n", sep = "")
cat("Ferdig. Totalt i ", dir_raw, ":\n", sep = "")
dir_ls(dir_raw, regexp = "TILT") |>
    path_file() |>
    sort() |>
    walk(\(f) cat("  ", f, "\n"))
