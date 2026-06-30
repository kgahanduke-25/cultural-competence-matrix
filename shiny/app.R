# =============================================================================
# app.R - Cultural Competence Matrix: interactive explorer
#
# A small Shiny app that lets a user select populations, inspect the scored
# matrix as an interactive heatmap and radar, read the computed access indices
# and diagnostic labels, and view the medical-pluralism transition.
#
# Run from the project root:
#   shiny::runApp("shiny")
# or from this directory:
#   shiny::runApp()
# =============================================================================

# Fail early with a clear message if a dependency is missing
# (install them with: Rscript scripts/setup.R).
.deps <- c("shiny", "dplyr", "tidyr", "ggplot2", "plotly", "forcats")
.missing <- .deps[!vapply(.deps, requireNamespace, logical(1), quietly = TRUE)]
if (length(.missing)) {
  stop("Missing packages: ", paste(.missing, collapse = ", "),
       ". Run: Rscript scripts/setup.R", call. = FALSE)
}

suppressPackageStartupMessages({
  library(shiny)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(plotly)
  library(forcats)
})

# ---- Source project code (works whether launched from root or shiny/) -------
# shiny::runApp("shiny") sets the working directory to shiny/, so locate the
# project root by searching upward for the R/ source directory.
find_project_root <- function() {
  for (p in c(".", "..", "../..")) {
    if (file.exists(file.path(p, "R", "scoring.R"))) return(p)
  }
  stop("Could not locate project root (R/scoring.R not found).")
}
.root <- find_project_root()
source(file.path(.root, "R", "load_data.R"))
source(file.path(.root, "R", "scoring.R"))
source(file.path(.root, "R", "theme_ccm.R"))

meta      <- load_domains()
mat_all   <- load_matrix(meta = meta)
pluralism <- load_pluralism()
all_pops  <- levels(mat_all$population)

# ============================================================ UI
ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { font-family: 'Helvetica Neue', Arial, sans-serif; }
    .well { background:#f7f9fb; border:none; }
    h2 { font-weight:700; }
    .subtitle { color:#5a5a5a; margin-top:-6px; margin-bottom:14px; }
    .diag { font-size:13px; }
  "))),

  titlePanel("Cultural Competence Matrix"),
  div(class = "subtitle",
      "A visualization framework for public-health access in marginalized populations.",
      "Malayali (Sitheri Hills) is the documented dissertation case; other",
      "populations are illustrative/synthetic."),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      checkboxGroupInput(
        "pops", "Populations to display:",
        choices = all_pops, selected = all_pops
      ),
      tags$hr(),
      radioButtons(
        "weighting", "Composite weighting:",
        choices = c("Equal (all domains)" = "equal",
                    "Gate on structural access" = "gated"),
        selected = "equal"
      ),
      helpText("\"Gate\" multiplies each domain by the structural-access score",
               "(0-3, rescaled), reflecting that access is bounded by whether",
               "care is physically reachable."),
      tags$hr(),
      downloadButton("dl_scores", "Download scored table (CSV)")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        type = "tabs",
        tabPanel("Matrix heatmap", br(), plotlyOutput("heatmap", height = "440px")),
        tabPanel("Radar profiles", br(), plotlyOutput("radar", height = "520px")),
        tabPanel("Access indices",
                 br(),
                 p(class = "diag",
                   "Capacity = system provision (organizational, structural,",
                   "communication). Realized = dignified use (trust, respect,",
                   "pluralistic navigation). The diagnostic label names where",
                   "the access system is strong or weak."),
                 tableOutput("indices")),
        tabPanel("Pluralism transition", br(),
                 plotlyOutput("pluralism", height = "460px"))
      )
    )
  )
)

# ============================================================ Server
server <- function(input, output, session) {

  mat <- reactive({
    req(input$pops)
    mat_all |> filter(population %in% input$pops) |>
      mutate(population = fct_drop(population))
  })

  # ---- Heatmap (interactive) -----------------------------------------------
  output$heatmap <- renderPlotly({
    df <- mat() |> mutate(short_label = fct_rev(short_label))
    p <- ggplot(df, aes(population, short_label, fill = score,
                        text = paste0(population, "<br>", short_label,
                                      "<br>Score: ", score,
                                      "<br>", provenance))) +
      geom_tile(color = "white", linewidth = 1) +
      geom_text(aes(label = score), color = "grey15", fontface = "bold") +
      scale_fill_gradient2(low = CCM_GRADIENT_LOW, mid = CCM_GRADIENT_MID,
                           high = CCM_GRADIENT_HIGH, midpoint = 1.5,
                           limits = c(0, 3), name = "Score") +
      labs(x = NULL, y = NULL) +
      theme_ccm() +
      theme(axis.text.x = element_text(angle = 20, hjust = 1),
            panel.grid = element_blank())
    ggplotly(p, tooltip = "text") |> layout(margin = list(t = 20))
  })

  # ---- Radar (interactive, via plotly scatterpolar) ------------------------
  output$radar <- renderPlotly({
    df <- mat()
    dom_levels <- levels(meta$short_label)
    plt <- plot_ly(type = "scatterpolar", mode = "lines+markers", fill = "toself")
    pal <- CCM_CAT_COLORS
    pops <- levels(df$population)
    for (i in seq_along(pops)) {
      d <- df |> filter(population == pops[i]) |>
        arrange(match(short_label, dom_levels))
      r <- c(d$score, d$score[1])
      th <- c(as.character(d$short_label), as.character(d$short_label[1]))
      plt <- plt |> add_trace(
        r = r, theta = th, name = pops[i],
        line = list(color = pal[(i - 1) %% length(pal) + 1]),
        marker = list(color = pal[(i - 1) %% length(pal) + 1]),
        opacity = 0.65
      )
    }
    plt |> layout(
      polar = list(radialaxis = list(visible = TRUE, range = c(0, 3))),
      legend = list(orientation = "h", x = 0.1, y = -0.05),
      margin = list(t = 30)
    )
  })

  # ---- Access indices + diagnostic -----------------------------------------
  indices <- reactive({
    base <- summarise_access(mat())
    if (input$weighting == "gated") {
      # Recompute composite with a structural-access gate, then re-summarise.
      gate <- mat() |>
        filter(domain_id == "D2") |>
        transmute(population, gate = score / 3)
      gated <- mat() |>
        left_join(gate, by = "population") |>
        group_by(population) |>
        summarise(composite_index = as_index(mean(score) * mean(gate) ^ 0.5),
                  .groups = "drop")
      base <- base |>
        select(-composite_index) |>
        left_join(gated, by = "population") |>
        relocate(composite_index, .after = case_type) |>
        arrange(desc(composite_index))
    }
    base
  })

  output$indices <- renderTable({
    indices() |>
      transmute(
        Population      = population,
        Region          = region,
        Type            = case_type,
        Composite       = composite_index,
        Capacity        = capacity_index,
        Realized        = realized_index,
        `Conversion gap`= conversion_gap,
        Diagnostic      = diagnostic
      )
  }, striped = TRUE, hover = TRUE, width = "100%")

  # ---- Pluralism transition -------------------------------------------------
  output$pluralism <- renderPlotly({
    plur <- pluralism |>
      mutate(system = factor(system,
                             levels = c("Traditional medicine (Ta-ta)",
                                        "Primary Health Centre (PHC)",
                                        "Community Health Centre (CHC)")))
    p <- ggplot(plur, aes(period, reliance, group = system, color = system,
                          text = paste0(system, "<br>", period, "<br>",
                                        scales::percent(reliance, 1)))) +
      geom_line(linewidth = 1.3) +
      geom_point(size = 3) +
      scale_y_continuous(labels = scales::percent, limits = c(0, 0.8)) +
      scale_color_manual(values = c("#3d8c5f", "#1b4965", "#e07a5f"), name = NULL) +
      labs(x = NULL, y = "Share of care-seeking (illustrative)") +
      theme_ccm() +
      theme(legend.position = "bottom")
    ggplotly(p, tooltip = "text") |>
      layout(legend = list(orientation = "h", y = -0.2), margin = list(t = 20))
  })

  # ---- Download -------------------------------------------------------------
  output$dl_scores <- downloadHandler(
    filename = function() "ccm_access_indices.csv",
    content  = function(file) readr::write_csv(indices(), file)
  )
}

shinyApp(ui, server)
