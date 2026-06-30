# =============================================================================
# setup.R - install the packages this project depends on.
# Run once:  Rscript scripts/setup.R
# =============================================================================
pkgs <- c("dplyr", "tidyr", "readr", "ggplot2", "forcats",
          "scales", "plotly", "shiny")

to_install <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(to_install)) {
  install.packages(to_install, repos = "https://cloud.r-project.org")
} else {
  message("All required packages are already installed.")
}
