#!/usr/bin/env Rscript
# =============================================================================
# generate_figures.R
# Produce the four polished figures for the Cultural Competence Matrix.
# Run from the project root:  Rscript scripts/generate_figures.R
# Outputs PNGs to figures/.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(forcats)
})

# ---- Load project code & data ----------------------------------------------
source(file.path("R", "load_data.R"))
source(file.path("R", "scoring.R"))
source(file.path("R", "theme_ccm.R"))

meta      <- load_domains()
mat       <- load_matrix(meta = meta)
indices   <- summarise_access(mat)
pluralism <- load_pluralism()

dir.create("figures", showWarnings = FALSE)

CASE <- "Malayali (Sitheri Hills)"
CAPTION <- paste0(
  "Cultural Competence Matrix | ordinal 0-3 (0 = absent, 3 = strong). ",
  "Malayali = documented dissertation case; other populations illustrative/synthetic."
)

# =============================================================================
# Figure 1 - Scored matrix heatmap (the hero view)
# domains (rows, grouped by Betancourt level) x populations (columns)
# =============================================================================
heat_df <- mat |>
  mutate(short_label = fct_rev(short_label))  # top-to-bottom D1..D6

fig1 <- ggplot(heat_df, aes(x = population, y = short_label, fill = score)) +
  geom_tile(color = "white", linewidth = 1.1) +
  geom_text(aes(label = score), color = "grey15", fontface = "bold", size = 4) +
  scale_fill_gradient2(
    low = CCM_GRADIENT_LOW, mid = CCM_GRADIENT_MID, high = CCM_GRADIENT_HIGH,
    midpoint = 1.5, limits = c(0, 3), breaks = 0:3,
    name = "Score"
  ) +
  scale_x_discrete(position = "top") +
  labs(
    title    = "Cultural Competence Matrix: access scored across six domains",
    subtitle = "Each cell is an ordinal 0-3 score; columns are populations, rows are domains",
    x = NULL, y = NULL, caption = CAPTION
  ) +
  theme_ccm() +
  theme(
    axis.text.x = element_text(angle = 20, hjust = 0, face = "bold"),
    panel.grid  = element_blank()
  )

ggsave("figures/01_matrix_heatmap.png", fig1, width = 10, height = 6, dpi = 200)

# =============================================================================
# Figure 2 - Radar / spider profiles (contrast two populations)
# Shows the *shape* of access: where each population is strong vs weak.
# =============================================================================
radar_pops <- c(CASE, "Remote Indigenous community")

radar_df <- mat |>
  filter(population %in% radar_pops) |>
  select(population, short_label, score) |>
  mutate(short_label = factor(short_label, levels = levels(meta$short_label)))

# Close the polygon by repeating the first domain at the end.
radar_closed <- radar_df |>
  group_by(population) |>
  group_modify(~ bind_rows(.x, .x[1, ])) |>
  ungroup() |>
  mutate(theta = as.integer(short_label))

fig2 <- ggplot(radar_closed,
               aes(x = short_label, y = score,
                   group = population, color = population, fill = population)) +
  geom_polygon(alpha = 0.18, linewidth = 1.1) +
  geom_point(size = 2.6) +
  coord_polar() +
  scale_y_continuous(limits = c(0, 3), breaks = 0:3) +
  scale_color_manual(values = unname(CCM_CAT_COLORS), name = NULL) +
  scale_fill_manual(values = unname(CCM_CAT_COLORS),  name = NULL) +
  labs(
    title    = "Access profiles: documented case vs. an illustrative contrast",
    subtitle = "Sitheri shows structural presence with organizational/clinical gaps;\nthe Indigenous contrast inverts that shape",
    x = NULL, y = NULL, caption = CAPTION
  ) +
  theme_ccm() +
  theme(legend.position = "bottom",
        panel.grid.major = element_line(color = "grey88"))

ggsave("figures/02_radar_profiles.png", fig2, width = 8.5, height = 7.5, dpi = 200)

# =============================================================================
# Figure 3 - Capacity vs. Realized access (dumbbell) = the "conversion gap"
# Andersen's potential vs. realized access, one row per population.
# =============================================================================
gap_df <- indices |>
  mutate(population = fct_reorder(population, composite_index)) |>
  select(population, capacity_index, realized_index, conversion_gap)

gap_long <- gap_df |>
  pivot_longer(c(capacity_index, realized_index),
               names_to = "kind", values_to = "index") |>
  mutate(kind = recode(kind,
                       capacity_index = "Capacity (provision)",
                       realized_index = "Realized (dignified use)"))

fig3 <- ggplot(gap_df, aes(y = population)) +
  geom_segment(aes(x = realized_index, xend = capacity_index,
                   yend = population),
               color = "grey75", linewidth = 1.6) +
  geom_point(data = gap_long,
             aes(x = index, color = kind), size = 4.2) +
  geom_text(aes(x = pmax(capacity_index, realized_index) + 4,
                label = sprintf("gap %+0.0f", conversion_gap)),
            hjust = 0, size = 3.2, color = "grey35") +
  scale_color_manual(values = c("Capacity (provision)" = "#2166ac",
                                "Realized (dignified use)" = "#e07a5f"),
                     name = NULL) +
  scale_x_continuous(limits = c(0, 108), breaks = seq(0, 100, 25)) +
  labs(
    title    = "The conversion gap: does built capacity become dignified use?",
    subtitle = "Distance between dots = access that the system provides but does not realize (Andersen)",
    x = "Access index (0-100)", y = NULL, caption = CAPTION
  ) +
  theme_ccm() +
  theme(legend.position = "bottom")

ggsave("figures/03_conversion_gap.png", fig3, width = 9.5, height = 6, dpi = 200)

# =============================================================================
# Figure 4 - Medical pluralism transition (Sitheri case)
# Slope chart of reliance on each therapeutic system over time.
# =============================================================================
plur <- pluralism |>
  mutate(system = factor(system,
                         levels = c("Traditional medicine (Ta-ta)",
                                    "Primary Health Centre (PHC)",
                                    "Community Health Centre (CHC)")))

fig4 <- ggplot(plur, aes(x = period, y = reliance,
                         group = system, color = system)) +
  geom_line(linewidth = 1.4) +
  geom_point(size = 3.4) +
  geom_text(
    data = filter(plur, period_order == 2),
    aes(label = scales::percent(reliance, accuracy = 1)),
    hjust = -0.25, size = 3.4, show.legend = FALSE
  ) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 0.8)) +
  scale_color_manual(values = c("#3d8c5f", "#1b4965", "#e07a5f"), name = NULL) +
  expand_limits(x = 2.6) +
  labs(
    title    = "Medical pluralism in transition (Sitheri Hills)",
    subtitle = "Schematic of the dissertation's directional finding: ethnomedicine contracts as the PHC embeds",
    x = NULL, y = "Share of care-seeking (illustrative)",
    caption = "Schematic of a qualitative directional finding, not measured percentages."
  ) +
  theme_ccm() +
  theme(legend.position = "bottom")

ggsave("figures/04_pluralism_transition.png", fig4, width = 8.5, height = 6, dpi = 200)

# ---- Console summary ---------------------------------------------------------
message("Saved 4 figures to figures/.")
print(indices |> select(population, composite_index, capacity_index,
                         realized_index, conversion_gap, diagnostic))
