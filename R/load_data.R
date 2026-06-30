# =============================================================================
# load_data.R
# Read and validate the Cultural Competence Matrix example data.
# All functions return tidy tibbles and fail loudly on malformed input.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

#' Resolve a path relative to the project root.
#'
#' Lets the same code run from the project root, from scripts/, or from shiny/.
#' @param ... path components passed to file.path()
ccm_path <- function(...) {
  candidates <- c(".", "..", "../..")
  for (base in candidates) {
    p <- file.path(base, ...)
    if (file.exists(p)) return(p)
  }
  # Fall back to the first candidate so the error message is informative.
  file.path(candidates[1], ...)
}

#' Stop with a friendly message when a private data file is absent.
#'
#' The scored dataset is not published with the repository (see data/README.md);
#' this keeps the failure mode clear for anyone who clones without the data.
require_data_file <- function(path) {
  if (!file.exists(path)) {
    stop(
      "Data file not found: ", path, "\n",
      "The scored dataset is private and available on request. ",
      "See data/README.md, then place the CSV(s) in data/.",
      call. = FALSE
    )
  }
  path
}

#' Load domain metadata (one row per domain).
load_domains <- function(path = ccm_path("data", "domains_metadata.csv")) {
  meta <- readr::read_csv(path, show_col_types = FALSE)
  required <- c("domain_id", "domain", "short_label",
                "betancourt_level", "andersen_stage", "access_type")
  stopifnot(all(required %in% names(meta)))
  meta |>
    mutate(
      domain_id   = factor(domain_id, levels = unique(domain_id)),
      short_label = factor(short_label, levels = unique(short_label))
    )
}

#' Load the scored matrix in long (tidy) form and join domain metadata.
#'
#' @return tibble: population, region, case_type, domain_id, domain,
#'   short_label, betancourt_level, andersen_stage, access_type,
#'   score (0-3), provenance
load_matrix <- function(path  = ccm_path("data", "example_matrix.csv"),
                        meta  = load_domains()) {
  raw <- readr::read_csv(require_data_file(path), show_col_types = FALSE)
  required <- c("population", "region", "case_type",
                "domain_id", "score", "provenance")
  stopifnot(all(required %in% names(raw)))

  # Validation: scores must be integers within the 0-3 ordinal range.
  if (any(raw$score < 0 | raw$score > 3, na.rm = TRUE)) {
    stop("Scores must lie on the 0-3 ordinal scale.")
  }

  raw |>
    left_join(meta, by = "domain_id") |>
    mutate(
      population  = factor(population, levels = unique(population)),
      domain_id   = factor(domain_id, levels = levels(meta$domain_id)),
      short_label = factor(short_label, levels = levels(meta$short_label))
    )
}

#' Load the medical-pluralism transition data (Sitheri case illustration).
load_pluralism <- function(path = ccm_path("data", "pluralism_transition.csv")) {
  readr::read_csv(require_data_file(path), show_col_types = FALSE) |>
    mutate(period = forcats::fct_reorder(period, period_order))
}
