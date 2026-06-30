# =============================================================================
# app.R — Cultural Competence Matrix: interactive explorer (Shinylive build)
#
# This is a SELF-CONTAINED version of shiny/app.R, designed to run in the
# browser via Shinylive / webR (no server). Differences from shiny/app.R:
#   * all data is embedded inline (no file reads, no path issues in webR)
#   * scoring, theme, and palette are inlined
#   * charts use ggplot2 (renderPlot) instead of plotly, for webR compatibility
#
# The canonical, server-side app remains shiny/app.R. This file is what the
# GitHub Action compiles to static WebAssembly and publishes to GitHub Pages.
# =============================================================================

library(shiny)
library(dplyr)
library(tidyr)
library(ggplot2)
library(forcats)
library(scales)

# ----------------------------------------------------------------- embedded data
# Domain metadata (six domains; theory mapping).
domains <- tibble::tribble(
  ~domain_id, ~short_label,               ~betancourt_level,      ~access_type,
  "D1",       "Organizational Rep.",      "Organizational",       "Capacity",
  "D2",       "Structural Access",        "Structural",           "Capacity",
  "D3",       "Communication Fit",        "Structural/Clinical",  "Capacity",
  "D4",       "Trust",                    "Clinical",             "Realized",
  "D5",       "Respect & Dignity",        "Clinical",             "Realized",
  "D6",       "Pluralistic Care-Seeking", "Behavioral",           "Realized"
)
dom_levels <- domains$short_label

# Scored matrix (population x domain). Malayali = documented case;
# others are illustrative/synthetic.
mat_raw <- tibble::tribble(
  ~population,                  ~region,            ~case_type,                 ~domain_id, ~score,
  "Malayali (Sitheri Hills)",  "Tamil Nadu, India","Documented case",          "D1", 1,
  "Malayali (Sitheri Hills)",  "Tamil Nadu, India","Documented case",          "D2", 2,
  "Malayali (Sitheri Hills)",  "Tamil Nadu, India","Documented case",          "D3", 1,
  "Malayali (Sitheri Hills)",  "Tamil Nadu, India","Documented case",          "D4", 2,
  "Malayali (Sitheri Hills)",  "Tamil Nadu, India","Documented case",          "D5", 1,
  "Malayali (Sitheri Hills)",  "Tamil Nadu, India","Documented case",          "D6", 2,
  "Rural Latino immigrants",   "U.S. Southwest",   "Illustrative (synthetic)", "D1", 2,
  "Rural Latino immigrants",   "U.S. Southwest",   "Illustrative (synthetic)", "D2", 2,
  "Rural Latino immigrants",   "U.S. Southwest",   "Illustrative (synthetic)", "D3", 1,
  "Rural Latino immigrants",   "U.S. Southwest",   "Illustrative (synthetic)", "D4", 1,
  "Rural Latino immigrants",   "U.S. Southwest",   "Illustrative (synthetic)", "D5", 1,
  "Rural Latino immigrants",   "U.S. Southwest",   "Illustrative (synthetic)", "D6", 2,
  "Urban unhoused adults",     "U.S.",             "Illustrative (synthetic)", "D1", 1,
  "Urban unhoused adults",     "U.S.",             "Illustrative (synthetic)", "D2", 1,
  "Urban unhoused adults",     "U.S.",             "Illustrative (synthetic)", "D3", 2,
  "Urban unhoused adults",     "U.S.",             "Illustrative (synthetic)", "D4", 1,
  "Urban unhoused adults",     "U.S.",             "Illustrative (synthetic)", "D5", 0,
  "Urban unhoused adults",     "U.S.",             "Illustrative (synthetic)", "D6", 1,
  "Refugee resettlement cohort","Western Europe",  "Illustrative (synthetic)", "D1", 1,
  "Refugee resettlement cohort","Western Europe",  "Illustrative (synthetic)", "D2", 2,
  "Refugee resettlement cohort","Western Europe",  "Illustrative (synthetic)", "D3", 2,
  "Refugee resettlement cohort","Western Europe",  "Illustrative (synthetic)", "D4", 2,
  "Refugee resettlement cohort","Western Europe",  "Illustrative (synthetic)", "D5", 2,
  "Refugee resettlement cohort","Western Europe",  "Illustrative (synthetic)", "D6", 2,
  "Remote Indigenous community","Australia/Canada","Illustrative (synthetic)", "D1", 3,
  "Remote Indigenous community","Australia/Canada","Illustrative (synthetic)", "D2", 1,
  "Remote Indigenous community","Australia/Canada","Illustrative (synthetic)", "D3", 2,
  "Remote Indigenous community","Australia/Canada","Illustrative (synthetic)", "D4", 2,
  "Remote Indigenous community","Australia/Canada","Illustrative (synthetic)", "D5", 2,
  "Remote Indigenous community","Australia/Canada","Illustrative (synthetic)", "D6", 3
)

pop_levels <- unique(mat_raw$population)

mat_all <- mat_raw |>
  left_join(domains, by = "domain_id") |>
  mutate(
    population  = factor(population, levels = pop_levels),
    short_label = factor(short_label, levels = dom_levels)
  )

pluralism <- tibble::tribble(
  ~system,                          ~period,             ~period_order, ~reliance,
  "Traditional medicine (Ta-ta)",   "~2010 (pre-PHC)",   1,             0.70,
  "Primary Health Centre (PHC)",    "~2010 (pre-PHC)",   1,             0.20,
  "Community Health Centre (CHC)",  "~2010 (pre-PHC)",   1,             0.10,
  "Traditional medicine (Ta-ta)",   "2020 (fieldwork)",  2,             0.20,
  "Primary Health Centre (PHC)",    "2020 (fieldwork)",  2,             0.55,
  "Community Health Centre (CHC)",  "2020 (fieldwork)",  2,             0.25
) |>
  mutate(period = fct_reorder(period, period_order))

# ----------------------------------------------------------------- scoring
CCM_MAX_SCORE <- 3L
as_index <- function(mean_score) round(100 * mean_score / CCM_MAX_SCORE, 1)

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

classify_pattern <- function(capacity_index, realized_index) {
  gap <- capacity_index - realized_index
  dplyr::case_when(
    capacity_index < 50 & realized_index < 50 ~
      "Broad access deprivation - intervene across all levels",
    gap >= 15 & capacity_index >= 50 ~
      "Capacity present, conversion gap",
    gap <= -15 & realized_index >= 50 ~
      "Relational strengths, structural deficit",
    capacity_index >= 67 & realized_index >= 67 ~
      "Comparatively strong access across levels",
    TRUE ~ "Mixed profile - no single dominant gap"
  )
}

summarise_access <- function(mat) {
  compute_indices(mat) |>
    mutate(diagnostic = classify_pattern(capacity_index, realized_index))
}

# ----------------------------------------------------------------- theme & palette
CCM_GRADIENT_LOW  <- "#b2182b"; CCM_GRADIENT_MID <- "#f7f7f7"; CCM_GRADIENT_HIGH <- "#2166ac"
CCM_CAT_COLORS <- c("#1b4965", "#e07a5f", "#3d8c5f", "#8367c7", "#c08552", "#5fa8d3")

theme_ccm <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title    = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position  = "bottom",
      plot.margin = margin(12, 14, 10, 12)
    )
}

# ============================================================ UI
ui <- fluidPage(
  tags$head(tags$style(HTML("
    body{font-family:-apple-system,Arial,sans-serif;}
    .subtitle{color:#5a6b7d;margin-top:-6px;margin-bottom:14px;}
    h2{color:#16324a;font-weight:700;}
  "))),
  titlePanel("Cultural Competence Matrix"),
  div(class = "subtitle",
      "A visualization framework for public-health access in marginalized populations. ",
      "Malayali (Sitheri Hills) is the documented dissertation case; other populations are illustrative/synthetic."),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      checkboxGroupInput("pops", "Populations to display:",
                         choices = pop_levels, selected = pop_levels),
      tags$hr(),
      radioButtons("weighting", "Composite weighting:",
                   choices = c("Equal (all domains)" = "equal",
                               "Gate on structural access" = "gated"),
                   selected = "equal"),
      helpText("\"Gate\" scales the composite by the structural-access score, ",
               "reflecting that access is bounded by whether care is reachable.")
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        type = "tabs",
        tabPanel("Matrix heatmap", br(), plotOutput("heatmap", height = "440px")),
        tabPanel("Radar profiles", br(), plotOutput("radar", height = "520px")),
        tabPanel("Access indices", br(),
                 p("Capacity = system provision (D1-D3). Realized = dignified use (D4-D6). ",
                   "The diagnostic names where access is strong or weak."),
                 tableOutput("indices")),
        tabPanel("Pluralism transition", br(), plotOutput("pluralism", height = "440px"))
      )
    )
  )
)

# ============================================================ Server
server <- function(input, output, session) {

  mat <- reactive({
    req(input$pops)
    mat_all |> filter(population %in% input$pops) |> mutate(population = fct_drop(population))
  })

  output$heatmap <- renderPlot({
    df <- mat() |> mutate(short_label = fct_rev(short_label))
    ggplot(df, aes(population, short_label, fill = score)) +
      geom_tile(color = "white", linewidth = 1) +
      geom_text(aes(label = score), color = "grey15", fontface = "bold", size = 4.2) +
      scale_fill_gradient2(low = CCM_GRADIENT_LOW, mid = CCM_GRADIENT_MID,
                           high = CCM_GRADIENT_HIGH, midpoint = 1.5,
                           limits = c(0, 3), breaks = 0:3, name = "Score") +
      scale_x_discrete(position = "top") +
      labs(x = NULL, y = NULL, title = "Access scored across six domains") +
      theme_ccm() +
      theme(axis.text.x = element_text(angle = 18, hjust = 0, face = "bold"),
            panel.grid = element_blank())
  })

  output$radar <- renderPlot({
    df <- mat() |> select(population, short_label, score) |>
      mutate(short_label = factor(short_label, levels = dom_levels))
    closed <- df |> group_by(population) |>
      group_modify(~ bind_rows(.x, .x[1, ])) |> ungroup()
    ggplot(closed, aes(short_label, score, group = population,
                       color = population, fill = population)) +
      geom_polygon(alpha = 0.15, linewidth = 1) +
      geom_point(size = 2.4) +
      coord_polar() +
      scale_y_continuous(limits = c(0, 3), breaks = 0:3) +
      scale_color_manual(values = unname(CCM_CAT_COLORS), name = NULL) +
      scale_fill_manual(values = unname(CCM_CAT_COLORS), name = NULL) +
      labs(x = NULL, y = NULL, title = "Access profiles (shape of access)") +
      theme_ccm()
  })

  indices <- reactive({
    base <- summarise_access(mat())
    if (input$weighting == "gated") {
      gate <- mat() |> filter(domain_id == "D2") |>
        transmute(population, gate = score / 3)
      gated <- mat() |> left_join(gate, by = "population") |>
        group_by(population) |>
        summarise(composite_index = as_index(mean(score) * mean(gate) ^ 0.5), .groups = "drop")
      base <- base |> select(-composite_index) |>
        left_join(gated, by = "population") |>
        relocate(composite_index, .after = case_type) |>
        arrange(desc(composite_index))
    }
    base
  })

  output$indices <- renderTable({
    indices() |>
      transmute(Population = as.character(population), Region = region, Type = case_type,
                Composite = composite_index, Capacity = capacity_index,
                Realized = realized_index, `Conversion gap` = conversion_gap,
                Diagnostic = diagnostic)
  }, striped = TRUE, hover = TRUE, width = "100%")

  output$pluralism <- renderPlot({
    plur <- pluralism |>
      mutate(system = factor(system,
                             levels = c("Traditional medicine (Ta-ta)",
                                        "Primary Health Centre (PHC)",
                                        "Community Health Centre (CHC)")))
    ggplot(plur, aes(period, reliance, group = system, color = system)) +
      geom_line(linewidth = 1.3) + geom_point(size = 3) +
      scale_y_continuous(labels = percent, limits = c(0, 0.8)) +
      scale_color_manual(values = c("#3d8c5f", "#1b4965", "#e07a5f"), name = NULL) +
      labs(x = NULL, y = "Share of care-seeking (illustrative)",
           title = "Medical pluralism in transition (Sitheri Hills)") +
      theme_ccm()
  })
}

shinyApp(ui, server)
