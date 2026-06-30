# =============================================================================
# theme_ccm.R
# Shared visual identity for the Cultural Competence Matrix figures.
# A restrained, publication-style theme plus a consistent ordinal palette.
# =============================================================================

suppressPackageStartupMessages(library(ggplot2))

# Sequential palette for the 0-3 ordinal scale (colour-blind safe, low -> high).
CCM_ORDINAL_COLORS <- c(
  "0" = "#b2182b",  # absent / hostile
  "1" = "#ef8a62",  # minimal
  "2" = "#67a9cf",  # partial / conditional
  "3" = "#2166ac"   # strong / concordant
)

# Continuous gradient (for tile fills) anchored at the same endpoints.
CCM_GRADIENT_LOW  <- "#b2182b"
CCM_GRADIENT_MID  <- "#f7f7f7"
CCM_GRADIENT_HIGH <- "#2166ac"

# Qualitative palette for populations / categories.
CCM_CAT_COLORS <- c(
  "#1b4965", "#e07a5f", "#3d8c5f", "#8367c7", "#c08552", "#5fa8d3"
)

#' Project ggplot2 theme.
theme_ccm <- function(base_size = 12, base_family = "") {
  theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      plot.title       = element_text(face = "bold", size = base_size * 1.35,
                                       margin = margin(b = 4)),
      plot.subtitle    = element_text(color = "grey35",
                                      margin = margin(b = 12)),
      plot.caption     = element_text(color = "grey45", size = base_size * 0.75,
                                      hjust = 0, margin = margin(t = 12)),
      axis.title       = element_text(color = "grey25"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey92"),
      legend.position  = "right",
      legend.title     = element_text(face = "bold", size = base_size * 0.85),
      strip.text       = element_text(face = "bold", color = "grey20"),
      plot.margin      = margin(16, 18, 12, 16)
    )
}
