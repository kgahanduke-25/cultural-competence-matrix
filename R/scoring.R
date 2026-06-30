# =============================================================================
# scoring.R
# Scoring logic for the Cultural Competence Matrix.
#
# The matrix records an ordinal 0-3 score per (population x domain):
#   0 = absent / hostile, 1 = minimal, 2 = partial / conditional, 3 = strong.
#
# These functions turn the raw cells into interpretable summaries:
#   * domain-level indices (per population)
#   * capacity vs. realized access split (after Andersen's Behavioral Model)
#   * Betancourt-level roll-ups (organizational / structural / clinical)
#   * a transferable diagnostic label describing the access "shape"
#
# Nothing here is specific to any one population: swap the data, keep the code.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# Maximum value of the ordinal scale; indices are expressed as a 0-100 percent
# of this maximum so that profiles with different domain counts stay comparable.
CCM_MAX_SCORE <- 3L

#' Convert a mean 0-3 score to a 0-100 index.
as_index <- function(mean_score) round(100 * mean_score / CCM_MAX_SCORE, 1)

#' Composite and sub-indices for every population.
#'
#' @param mat tidy matrix from load_matrix()
#' @return one row per population with:
#'   composite_index  - mean across all domains (0-100)
#'   capacity_index   - mean across Capacity domains (system provision side)
#'   realized_index   - mean across Realized domains (dignified use side)
#'   conversion_gap   - capacity_index - realized_index (positive = capacity
#'                      outruns realization; the access "leak")
compute_indices <- function(mat) {
  by_access <- mat |>
    group_by(population, region, case_type, access_type) |>
    summarise(mean_score = mean(score), .groups = "drop") |>
    mutate(index = as_index(mean_score)) |>
    select(-mean_score) |>
    pivot_wider(names_from = access_type, values_from = index)

  composite <- mat |>
    group_by(population) |>
    summarise(composite_index = as_index(mean(score)), .groups = "drop")

  by_access |>
    left_join(composite, by = "population") |>
    mutate(
      Capacity       = coalesce(Capacity, 0),
      Realized       = coalesce(Realized, 0),
      conversion_gap = round(Capacity - Realized, 1)
    ) |>
    rename(capacity_index = Capacity, realized_index = Realized) |>
    relocate(composite_index, .after = case_type) |>
    arrange(desc(composite_index))
}

#' Mean score by Betancourt level for each population (0-3 scale).
#'
#' Domains tagged "Structural/Clinical" contribute to both levels so the
#' roll-up reflects the construct spanning two levels of the health system.
compute_level_profile <- function(mat) {
  mat |>
    separate_rows(betancourt_level, sep = "/") |>
    mutate(betancourt_level = trimws(betancourt_level)) |>
    group_by(population, betancourt_level) |>
    summarise(level_index = as_index(mean(score)), .groups = "drop")
}

#' Assign a transferable diagnostic label to an access profile.
#'
#' Thresholds are deliberately simple and population-independent; they describe
#' WHERE the access system is strong or weak, which tells a program which level
#' (organizational / structural / clinical) to intervene at.
#'
#' @param capacity_index,realized_index 0-100 indices from compute_indices()
classify_pattern <- function(capacity_index, realized_index) {
  cap  <- capacity_index
  real <- realized_index
  gap  <- cap - real

  dplyr::case_when(
    cap < 50 & real < 50 ~
      "Broad access deprivation - intervene across all levels",
    gap >= 15 & cap >= 50 ~
      "Capacity present, conversion gap - infrastructure exists but does not translate into trusted, dignified use",
    gap <= -15 & real >= 50 ~
      "Relational strengths, structural deficit - trust/dignity outrun the system's reach",
    cap >= 67 & real >= 67 ~
      "Comparatively strong access across levels",
    TRUE ~
      "Mixed profile - no single dominant gap"
  )
}

#' Convenience: indices + diagnostic label in one table.
summarise_access <- function(mat) {
  compute_indices(mat) |>
    mutate(diagnostic = classify_pattern(capacity_index, realized_index))
}
