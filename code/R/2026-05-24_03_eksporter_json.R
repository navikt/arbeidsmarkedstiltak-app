# Eksporter aggregerte tabeller til JSON for OJS-konsum (data/web/).
#
# OJS i Quarto leser disse via `FileAttachment("data/web/X.json").json()`.
# Plot.js og d3 håndterer ISO-dato-strenger ("YYYY-MM-DD") direkte; vi
# konverterer Date → ISO via jsonlite::toJSON med `POSIXt = "ISO8601"`.
#
# Inn:  data/clean/parsed/{oversikt,hovedgruppe,tiltakstype}_aggregert.rds
# Ut:   data/web/{oversikt,hovedgrupper,tiltakstyper}.json
#
# Format: array av objekter (long-format) — enkleste struktur for OJS:
#   [{"maalgruppe": "...", "periode": "2019-01-01", "antall": 123, ...}, ...]
#
# Compact (ikke pretty) for å holde nedlasting små. Hver fil < 500 KB —
# tiltakstyper splittes per målgruppe (Tab 3 kaskaderer på målgruppe først,
# så lasting per fil er naturlig).

library(tidyverse)
library(here)
library(fs)
library(jsonlite)

dir_parsed <- here("data", "clean", "parsed")
dir_web    <- here("data", "web")
dir_create(dir_web)

# `prikket` beholdes i RDS men droppes fra JSON — sparer ~50 KB per fil
# og brukes ikke i frontend ennå. Re-eksporter hvis vi trenger den senere.
fn_les_uten_prikket <- function(fil) {
    read_rds(fil) |> select(-any_of("prikket"))
}

oversikt    <- fn_les_uten_prikket(path(dir_parsed, "oversikt_aggregert.rds"))
hovedgruppe <- fn_les_uten_prikket(path(dir_parsed, "hovedgruppe_aggregert.rds"))
tiltakstype <- fn_les_uten_prikket(path(dir_parsed, "tiltakstype_aggregert.rds"))

# Skriver — bruker jsonlite::toJSON for kontroll over Date-formatering.
# `dataframe = "rows"` gir array av objekter. `na = "null"` skriver NA som
# JSON null (Plot.js dropper disse i serier automatisk).

fn_skriv_json <- function(df, fil) {
    json <- toJSON(
        df,
        dataframe = "rows",
        Date      = "ISO8601",
        na        = "null",
        auto_unbox = TRUE,
        pretty    = FALSE
    )
    write(json, fil)
    cat("  ", path_file(fil), " — ",
        format(file_info(fil)$size, big.mark = " "), " bytes (",
        nrow(df), " rader)\n", sep = "")
}

cat("Skriver JSON-filer til ", dir_web, ":\n", sep = "")

fn_skriv_json(oversikt,    path(dir_web, "oversikt.json"))
fn_skriv_json(hovedgruppe, path(dir_web, "hovedgrupper.json"))

# Splitt tiltakstyper per målgruppe — samlet ville fila bli >500 KB.
# Filnavn: tiltakstyper_arbeidssokere.json, tiltakstyper_nedsatt.json.
maalgruppe_til_slug <- c(
    "Arbeidssøkere"       = "arbeidssokere",
    "Nedsatt arbeidsevne" = "nedsatt"
)

for (mg in names(maalgruppe_til_slug)) {
    fn_skriv_json(
        tiltakstype |> filter(maalgruppe == mg),
        path(dir_web, paste0("tiltakstyper_", maalgruppe_til_slug[[mg]], ".json"))
    )
}

# Sjekk: ingen fil over 500 KB ------------------------------------------

storrelser <- dir_info(dir_web, glob = "*.json")
for_store <- storrelser |> filter(size > "500K")
if (nrow(for_store) > 0) {
    cat("\nADVARSEL: ", nrow(for_store), " fil(er) over 500 KB — vurder splitting:\n", sep = "")
    print(for_store |> select(path, size))
} else {
    cat("\nAlle JSON-filer er under 500 KB.\n")
}

# Skriv også en liten metadata-fil som frontend kan vise (siste oppdatering,
# antall målgrupper/hovedgrupper, periode-spenn). Lar appen vise "Sist
# oppdatert: 2026-04" i footeren uten å re-traversere selve dataene.

metadata <- list(
    sist_oppdatert  = as.character(max(oversikt$periode)),
    tidligste       = as.character(min(oversikt$periode)),
    maalgrupper     = unique(oversikt$maalgruppe),
    n_hovedgrupper  = n_distinct(paste(hovedgruppe$maalgruppe, hovedgruppe$hovedgruppe)),
    n_tiltakstyper  = n_distinct(paste(tiltakstype$maalgruppe, tiltakstype$hovedgruppe, tiltakstype$undertype)),
    generert        = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
)

write_json(metadata, path(dir_web, "metadata.json"),
           auto_unbox = TRUE, pretty = TRUE)
cat("  metadata.json   — generert ", metadata$generert, "\n", sep = "")
