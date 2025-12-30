# ============================================================================
# Football Player Statistics Radar Plot - Interactive Shiny App
# Using European Football Database (184k player attribute records)
# ============================================================================

# Install required packages (run once)
# install.packages(c("shiny", "fmsb", "dplyr", "shinythemes", "DT", "RSQLite", "DBI"))

# Load required libraries
library(shiny)
library(fmsb)
library(dplyr)
library(shinythemes)
library(DT)
library(RSQLite)
library(DBI)

# ============================================================================
# DATABASE CONNECTION & DATA LOADING
# ============================================================================

# Database path
db_path <- "database.sqlite"

cat("Connecting to database...\n")

# Connect to database
con <- dbConnect(RSQLite::SQLite(), db_path)

# Load Player table
players <- dbGetQuery(con, "SELECT player_api_id, player_name, birthday, height, weight FROM Player")
cat("Loaded", nrow(players), "players\n")

# Load Player_Attributes table
player_attributes <- dbGetQuery(con, "SELECT * FROM Player_Attributes")
cat("Loaded", nrow(player_attributes), "player attribute records\n")
cat("Total columns in Player_Attributes:", ncol(player_attributes), "\n")

# Show ALL column names
cat("\nAll Player_Attributes columns:\n")
print(colnames(player_attributes))

# Disconnect from database
dbDisconnect(con)

cat("\nDatabase loaded successfully!\n")

# ============================================================================
# DATA PREPROCESSING
# ============================================================================

cat("\nProcessing player data...\n")

# Get the most recent attributes for each player
latest_attributes <- player_attributes %>%
  arrange(player_api_id, desc(date)) %>%
  group_by(player_api_id) %>%
  slice(1) %>%
  ungroup()

cat("Filtered to", nrow(latest_attributes), "unique players with latest stats\n")

# Merge with player names
player_data <- latest_attributes %>%
  inner_join(players, by = "player_api_id")

cat("Merged player names - Total:", nrow(player_data), "players\n")

# Automatically discover ALL numeric columns (these are the metrics)
numeric_cols <- sapply(player_data, is.numeric)
all_numeric_col_names <- names(player_data)[numeric_cols]

# Remove ID columns and keep only FIFA attributes (exclude height, weight from metrics)
excluded_cols <- c("id", "player_fifa_api_id", "player_api_id", "date", "height", "weight")
available_metrics <- setdiff(all_numeric_col_names, excluded_cols)

cat("\nDiscovered", length(available_metrics), "FIFA attribute metrics:\n")
print(available_metrics)

# Prepare final dataset
player_stats <- player_data %>%
  select(player_name, 
         any_of(c("preferred_foot", "attacking_work_rate", "defensive_work_rate")),
         any_of(c("height", "weight", "birthday")),
         all_of(available_metrics)) %>%
  rename(Player = player_name) %>%
  rename_with(~"Preferred_Foot", any_of("preferred_foot")) %>%
  rename_with(~"Attacking_Work_Rate", any_of("attacking_work_rate")) %>%
  rename_with(~"Defensive_Work_Rate", any_of("defensive_work_rate")) %>%
  rename_with(~"Height", any_of("height")) %>%
  rename_with(~"Weight", any_of("weight")) %>%
  rename_with(~"Birthday", any_of("birthday")) %>%
  filter(!is.na(Player) & Player != "") %>%
  filter(!is.na(overall_rating)) %>%
  # Remove players with too many missing values
  filter(rowSums(is.na(select(., all_of(available_metrics)))) < length(available_metrics) * 0.5)

# Create position categories based on attributes that exist
if (all(c("finishing", "positioning") %in% available_metrics)) {
  player_stats <- player_stats %>%
    mutate(
      Position = case_when(
        finishing > 70 & positioning > 70 ~ "Forward",
        short_passing > 70 & dribbling > 65 ~ "Midfielder",
        marking > 65 & standing_tackle > 65 ~ "Defender",
        TRUE ~ "Player"
      )
    )
} else {
  player_stats$Position <- "Player"
}

# Calculate age if birthday exists
if ("Birthday" %in% colnames(player_stats)) {
  player_stats <- player_stats %>%
    mutate(
      Age = as.numeric(difftime(Sys.Date(), as.Date(Birthday), units = "days")) / 365.25,
      Age = round(Age, 1)
    )
} else {
  player_stats$Age <- NA
}

cat("\nFinal dataset:", nrow(player_stats), "players ready for analysis\n")
cat("Metrics available for radar plot:", length(available_metrics), "\n")

# ============================================================================
# UI (USER INTERFACE)
# ============================================================================

ui <- fluidPage(
  theme = shinytheme("cosmo"),
  title = "Football Player Analyzer",
  
  titlePanel(
    div(
      style = "text-align: center; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border-radius: 10px; margin-bottom: 20px;",
      h1("⚽ Football Player Performance Analyzer", 
         style = "font-weight: bold; margin: 10px;"),
      h4(paste("European Football Database -", nrow(player_stats), "Players -", length(available_metrics), "FIFA Attributes"), 
         style = "margin: 5px;")
    )
  ),
  
  sidebarLayout(
    sidebarPanel(
      width = 3,
      style = "background-color: #f8f9fa; padding: 20px; border-radius: 10px;",
      
      h3("🎯 Player Selection", style = "color: #2C3E50;"),
      hr(),
      
      # Database stats box
      div(
        style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                 color: white; padding: 15px; border-radius: 8px; margin-bottom: 20px;",
        h5("📊 Database Statistics", style = "margin: 0 0 10px 0;"),
        p(paste("✓ Players:", nrow(player_stats)), style = "margin: 3px 0; font-size: 14px;"),
        p(paste("✓ Metrics:", length(available_metrics)), style = "margin: 3px 0; font-size: 14px;"),
        p("✓ Real FIFA Ratings", style = "margin: 3px 0; font-size: 14px;")
      ),
      
      # Player search
      textInput(
        "search_player",
        "🔍 Search Players:",
        value = "",
        placeholder = "e.g., Messi, Ronaldo, Neymar..."
      ),
      
      # Player selection with checkboxes
      div(
        style = "max-height: 300px; overflow-y: auto; border: 1px solid #ddd; 
                 padding: 10px; border-radius: 5px; background-color: white;",
        uiOutput("player_checkboxes")
      ),
      
      # Position filter
      checkboxGroupInput(
        "position_filter",
        "Filter by Position:",
        choices = c("Forward", "Midfielder", "Defender", "Player"),
        selected = c("Forward", "Midfielder", "Defender", "Player")
      ),
      
      # Minimum overall rating filter
      sliderInput(
        "min_rating",
        "Minimum Overall Rating:",
        min = 40,
        max = 100,
        value = 65,
        step = 5
      ),
      
      hr(),
      
      # Metric selection for radar
      h4("Select 6 Metrics for Radar:", style = "color: #34495E;"),
      p(paste("(", length(available_metrics), "available)"), style = "font-size: 12px; color: #7f8c8d;"),
      div(
        style = "max-height: 350px; overflow-y: auto; border: 1px solid #ddd; 
                 padding: 10px; border-radius: 5px; background-color: white;",
        uiOutput("metric_checkboxes")
      ),
      
      hr(),
      
      h4("🎨 Customize", style = "color: #34495E;"),
      
      sliderInput(
        "line_width",
        "Line Width:",
        min = 1,
        max = 5,
        value = 3,
        step = 0.5
      ),
      
      sliderInput(
        "transparency",
        "Fill Transparency:",
        min = 0,
        max = 1,
        value = 0.3,
        step = 0.05
      ),
      
      hr(),
      
      downloadButton("download_plot", "📥 Download Plot", 
                     class = "btn-success btn-block",
                     style = "margin-bottom: 10px;"),
      
      downloadButton("download_data", "📊 Download CSV", 
                     class = "btn-info btn-block")
    ),
    
    mainPanel(
      width = 9,
      
      tabsetPanel(
        type = "tabs",
        
        # Tab 1: Radar Plot
        tabPanel(
          "📈 Radar Plot",
          icon = icon("chart-area"),
          br(),
          
          # Player info cards
          uiOutput("player_cards"),
          
          br(),
          
          div(
            style = "background-color: white; padding: 25px; 
                     border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);",
            plotOutput("radar_plot", height = "650px")
          ),
          br(),
          div(
            style = "background-color: #d1ecf1; padding: 20px; 
                     border-radius: 8px; border-left: 5px solid #0c5460;",
            h4("📖 How to Interpret", style = "color: #0c5460; margin-top: 0;"),
            tags$ul(
              tags$li("Each axis = FIFA player attribute (0-100 scale)"),
              tags$li("Larger polygon = Better overall performance"),
              tags$li("Compare shapes to identify strengths/weaknesses"),
              tags$li("All ratings from official FIFA database")
            )
          )
        ),
        
        # Tab 2: Player Comparison Table
        tabPanel(
          "📊 Player Data",
          icon = icon("table"),
          br(),
          div(
            style = "background-color: white; padding: 25px; 
                     border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);",
            h3("All Player Statistics", style = "color: #2C3E50;"),
            uiOutput("table_description"),
            hr(),
            DTOutput("data_table")
          )
        ),
        
        # Tab 3: Statistical Analysis
        tabPanel(
          "🔬 Analysis",
          icon = icon("calculator"),
          br(),
          fluidRow(
            column(
              width = 6,
              div(
                style = "background-color: white; padding: 20px; 
                         border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);",
                h4("Summary Statistics", style = "color: #2C3E50;"),
                verbatimTextOutput("summary_stats")
              )
            ),
            column(
              width = 6,
              div(
                style = "background-color: white; padding: 20px; 
                         border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);",
                h4("Metric Averages", style = "color: #2C3E50;"),
                verbatimTextOutput("metric_averages")
              )
            )
          ),
          br(),
          div(
            style = "background-color: white; padding: 25px; 
                     border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);",
            h4("🏆 Top 25 Players by Overall Rating", style = "color: #2C3E50;"),
            DTOutput("rankings_table")
          )
        ),
        
        # Tab 4: Metrics Explorer
        tabPanel(
          "🔍 Metrics Guide",
          icon = icon("info-circle"),
          br(),
          div(
            style = "background-color: white; padding: 30px; 
                     border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);",
            h3("FIFA Player Attributes Explained", style = "color: #2C3E50;"),
            p("All metrics are official FIFA ratings on a 0-100 scale"),
            hr(),
            
            fluidRow(
              column(
                width = 6,
                h4("⚽ Offensive", style = "color: #e74c3c;"),
                tags$ul(
                  tags$li(tags$b("Overall Rating:"), " Combined ability score"),
                  tags$li(tags$b("Potential:"), " Maximum achievable rating"),
                  tags$li(tags$b("Finishing:"), " Goal-scoring ability"),
                  tags$li(tags$b("Shot Power:"), " Shot strength"),
                  tags$li(tags$b("Long Shots:"), " Distance shooting"),
                  tags$li(tags$b("Volleys:"), " Volley accuracy"),
                  tags$li(tags$b("Penalties:"), " Penalty success rate"),
                  tags$li(tags$b("Positioning:"), " Attacking movement")
                ),
                
                hr(),
                
                h4("🎯 Technical", style = "color: #3498db;"),
                tags$ul(
                  tags$li(tags$b("Dribbling:"), " Close ball control"),
                  tags$li(tags$b("Ball Control:"), " First touch quality"),
                  tags$li(tags$b("Crossing:"), " Cross accuracy"),
                  tags$li(tags$b("Short Passing:"), " Short pass accuracy"),
                  tags$li(tags$b("Long Passing:"), " Long pass accuracy"),
                  tags$li(tags$b("Curve:"), " Ball curve ability"),
                  tags$li(tags$b("Free Kick Accuracy:"), " Free kick skill"),
                  tags$li(tags$b("Heading Accuracy:"), " Header precision")
                )
              ),
              
              column(
                width = 6,
                h4("🏃 Physical", style = "color: #27ae60;"),
                tags$ul(
                  tags$li(tags$b("Acceleration:"), " Speed buildup"),
                  tags$li(tags$b("Sprint Speed:"), " Top speed"),
                  tags$li(tags$b("Stamina:"), " Endurance"),
                  tags$li(tags$b("Strength:"), " Physical power"),
                  tags$li(tags$b("Agility:"), " Maneuverability"),
                  tags$li(tags$b("Balance:"), " Body control"),
                  tags$li(tags$b("Jumping:"), " Aerial ability"),
                  tags$li(tags$b("Reactions:"), " Response speed")
                ),
                
                hr(),
                
                h4("🛡️ Defensive", style = "color: #95a5a6;"),
                tags$ul(
                  tags$li(tags$b("Marking:"), " Opponent tracking"),
                  tags$li(tags$b("Standing Tackle:"), " Tackle success"),
                  tags$li(tags$b("Sliding Tackle:"), " Slide tackle skill"),
                  tags$li(tags$b("Interceptions:"), " Pass reading"),
                  tags$li(tags$b("Aggression:"), " Defensive intensity")
                ),
                
                hr(),
                
                h4("🧠 Mental", style = "color: #9b59b6;"),
                tags$ul(
                  tags$li(tags$b("Vision:"), " Passing awareness"),
                  tags$li(tags$b("Reactions:"), " Decision speed")
                )
              )
            )
          )
        ),
        
        # Tab 5: Database Info
        tabPanel(
          "💾 Database",
          icon = icon("database"),
          br(),
          div(
            style = "background-color: white; padding: 30px; 
                     border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);",
            h3("European Football Database", style = "color: #2C3E50;"),
            verbatimTextOutput("db_info"),
            hr(),
            h4("Available Metrics", style = "color: #2C3E50;"),
            verbatimTextOutput("metrics_list")
          )
        )
      )
    )
  ),
  
  hr(),
  div(
    style = "text-align: center; color: #7F8C8D; padding: 20px;",
    p("Built with R Shiny | European Football Database | FIFA Ratings 2008-2016")
  )
)

# ============================================================================
# SERVER (BACKEND LOGIC)
# ============================================================================

server <- function(input, output, session) {
  
  # Reactive values to store selections
  selected_players <- reactiveVal(head(player_stats %>% 
                                         arrange(desc(overall_rating)) %>% 
                                         pull(Player), 2))
  
  selected_metrics <- reactiveVal(head(available_metrics, 6))
  
  
  # Reactive: Filter players by position and rating
  filtered_players <- reactive({
    player_stats %>%
      filter(Position %in% input$position_filter) %>%
      filter(overall_rating >= input$min_rating)
  })
  
  # Reactive: Search players
  searched_players <- reactive({
    data <- filtered_players()
    
    if (input$search_player != "") {
      data <- data %>%
        filter(grepl(input$search_player, Player, ignore.case = TRUE))
    }
    
    return(data)
  })
  
  # Output: Player checkboxes
  output$player_checkboxes <- renderUI({
    players_list <- searched_players() %>%
      arrange(desc(overall_rating)) %>%
      head(50) %>%  # Show top 50 to avoid too many checkboxes
      pull(Player)
    
    if (length(players_list) == 0) {
      return(p("No players found", style = "color: #999;"))
    }
    
    checkboxes <- lapply(players_list, function(player) {
      div(
        style = "margin: 5px 0;",
        checkboxInput(
          inputId = paste0("player_", gsub("[^A-Za-z0-9]", "_", player)),
          label = player,
          value = player %in% selected_players()
        )
      )
    })
    
    do.call(tagList, checkboxes)
  })
  
  # Observe player checkbox changes
  observe({
    players_list <- searched_players() %>%
      arrange(desc(overall_rating)) %>%
      head(50) %>%
      pull(Player)
    
    selected <- c()
    for (player in players_list) {
      input_id <- paste0("player_", gsub("[^A-Za-z0-9]", "_", player))
      if (!is.null(input[[input_id]]) && input[[input_id]]) {
        selected <- c(selected, player)
      }
    }
    
    # Limit to 4 players
    if (length(selected) > 4) {
      showNotification("Maximum 4 players allowed", type = "warning", duration = 2)
      selected <- head(selected, 4)
    }
    
    selected_players(selected)
  })
  
  # Output: Metric checkboxes
  output$metric_checkboxes <- renderUI({
    checkboxes <- lapply(available_metrics, function(metric) {
      label <- gsub("_", " ", metric)
      label <- tools::toTitleCase(label)
      
      div(
        style = "margin: 5px 0;",
        checkboxInput(
          inputId = paste0("metric_", metric),
          label = label,
          value = metric %in% selected_metrics()
        )
      )
    })
    
    do.call(tagList, checkboxes)
  })
  
  observeEvent(available_metrics, {
    default_metrics <- head(available_metrics, 6)
    
    for (metric in available_metrics) {
      updateCheckboxInput(
        session,
        inputId = paste0("metric_", metric),
        value = metric %in% default_metrics
      )
    }
    
    selected_metrics(default_metrics)
  }, once = TRUE)
  
  
  # Observe metric checkbox changes
  observe({
    selected <- c()
    for (metric in available_metrics) {
      input_id <- paste0("metric_", metric)
      if (!is.null(input[[input_id]]) && input[[input_id]]) {
        selected <- c(selected, metric)
      }
    }
    
    # Limit to 6 metrics
    if (length(selected) > 6) {
      showNotification("Maximum 6 metrics allowed", type = "warning", duration = 2)
      selected <- head(selected, 6)
    }
    
    selected_metrics(selected)
  })
  
  # Reactive: Selected players data
  selected_data <- reactive({
    req(selected_players())
    req(selected_metrics())
    
    players <- selected_players()
    metrics <- selected_metrics()
    
    if (length(players) == 0) {
      return(NULL)
    }
    
    if (length(metrics) != 6) {
      return(NULL)
    }
    
    player_stats %>%
      filter(Player %in% players) %>%
      select(Player, Position, Age, Height, Weight, Preferred_Foot, 
             overall_rating, potential, all_of(metrics))
  })
  
  # Output: Player info cards
  output$player_cards <- renderUI({
    req(selected_data())
    data <- selected_data()
    
    cards <- lapply(1:nrow(data), function(i) {
      player <- data[i, ]
      
      color <- c("#e74c3c", "#3498db", "#27ae60", "#f39c12")[i]
      
      div(
        style = paste0("display: inline-block; width: 23%; margin: 5px; 
                        padding: 15px; background-color: ", color, "; 
                        color: white; border-radius: 8px; vertical-align: top;"),
        h4(player$Player, style = "margin: 0 0 10px 0; font-weight: bold;"),
        p(paste("Position:", player$Position), style = "margin: 3px 0; font-size: 13px;"),
        p(paste("Age:", round(player$Age, 0)), style = "margin: 3px 0; font-size: 13px;"),
        p(paste("Overall:", player$overall_rating), style = "margin: 3px 0; font-size: 13px;"),
        p(paste("Potential:", player$potential), style = "margin: 3px 0; font-size: 13px;")
      )
    })
    
    do.call(tagList, cards)
  })
  
  # Prepare radar data
  prepare_radar_data <- function(data, metrics) {
    numeric_data <- data %>%
      select(all_of(metrics))
    
    radar_data <- rbind(
      rep(100, ncol(numeric_data)),
      rep(0, ncol(numeric_data)),
      numeric_data
    )
    
    colnames(radar_data) <- gsub("_", "\n", colnames(radar_data))
    colnames(radar_data) <- tools::toTitleCase(colnames(radar_data))
    
    return(as.data.frame(radar_data))
  }
  
  # Output: Radar Plot
  output$radar_plot <- renderPlot({
    req(selected_data())
    req(selected_metrics())
    
    metrics <- selected_metrics()
    
    if (length(metrics) != 6) {
      plot.new()
      text(0.5, 0.5, "Please select exactly 6 metrics", cex = 2, col = "red")
      return()
    }
    
    data <- selected_data()
    
    if (is.null(data) || nrow(data) == 0) {
      plot.new()
      text(0.5, 0.5, "No players selected", cex = 2)
      return()
    }
    
    radar_data <- prepare_radar_data(data, metrics)
    
    colors <- c("#e74c3c", "#3498db", "#27ae60", "#f39c12")
    
    radarchart(
      radar_data,
      axistype = 1,
      pcol = colors[1:nrow(data)],
      pfcol = scales::alpha(colors[1:nrow(data)], input$transparency),
      plwd = input$line_width,
      plty = 1,
      cglcol = "grey",
      cglty = 1,
      cglwd = 0.8,
      caxislabels = seq(0, 100, 25),
      axislabcol = "grey30",
      vlcex = 1.3,
      calcex = 1.1,
      title = ""
    )
    
    mtext("Player Performance Comparison - FIFA Ratings", 
          side = 3, line = 2, cex = 2, font = 2, col = "#2C3E50")
    
    legend(
      x = "topright",
      legend = data$Player,
      col = colors[1:nrow(data)],
      lty = 1,
      lwd = input$line_width + 1,
      bty = "n",
      cex = 1.2,
      title = "Players",
      title.font = 2
    )
  })
  
  # Output: Table description
  output$table_description <- renderUI({
    p(paste("Showing", nrow(searched_players()), "players with overall rating ≥", input$min_rating))
  })
  
  # Output: Data Table
  output$data_table <- renderDT({
    data <- searched_players()
    
    display_cols <- c(
      "Player", "Position", "Age", "Height", "Weight", 
      "Preferred_Foot", "overall_rating", "potential",
      head(available_metrics, 8)
    )
    
    existing_cols <- intersect(display_cols, colnames(data))
    
    # 🔑 FIX: only metrics that are actually shown
    existing_metrics <- intersect(available_metrics, existing_cols)
    
    datatable(
      data %>% select(all_of(existing_cols)),
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        order = list(list(which(existing_cols == "overall_rating"), "desc"))
      ),
      class = "cell-border stripe hover",
      rownames = FALSE,
      filter = "top"
    ) %>%
      formatRound(columns = existing_metrics, digits = 0) %>%
      formatRound(
        columns = intersect(c("Age", "Height", "Weight"), existing_cols),
        digits = 1
      ) %>%
      formatStyle(
        "overall_rating",
        background = styleColorBar(
          range(player_stats$overall_rating, na.rm = TRUE),
          "#3498db"
        ),
        backgroundSize = "100% 90%",
        backgroundRepeat = "no-repeat",
        backgroundPosition = "center"
      )
  })
  
  # Output: Summary Statistics
  output$summary_stats <- renderPrint({
    req(selected_data())
    
    data <- selected_data() %>%
      select(all_of(selected_metrics()))
    
    cat("=== SELECTED PLAYERS - RADAR METRICS ===\n\n")
    print(summary(data))
  })
  
  # Output: Metric Averages
  output$metric_averages <- renderPrint({
    req(selected_data())
    
    data <- selected_data()
    
    cat("=== PLAYER AVERAGES ===\n\n")
    
    for (i in 1:nrow(data)) {
      cat(data$Player[i], "\n")
      cat("Overall Rating:", data$overall_rating[i], "\n")
      cat("Potential:", data$potential[i], "\n")
      
      metrics_avg <- mean(as.numeric(data[i, selected_metrics()]), na.rm = TRUE)
      cat("Radar Metrics Avg:", round(metrics_avg, 1), "\n\n")
    }
  })
  
  # Output: Rankings
  output$rankings_table <- renderDT({
    # Only select columns that exist
    rank_cols <- c("Player", "Position", "Age", "overall_rating", "potential")
    extra_metrics <- intersect(c("finishing", "dribbling", "short_passing", "crossing"), 
                               available_metrics)
    rank_cols <- c(rank_cols, extra_metrics)
    
    rankings <- player_stats %>%
      select(all_of(intersect(rank_cols, colnames(player_stats)))) %>%
      arrange(desc(overall_rating)) %>%
      head(25)
    
    datatable(
      rankings,
      options = list(
        pageLength = 25,
        dom = 't'
      ),
      rownames = TRUE
    ) %>%
      formatRound(columns = intersect(c("Age"), colnames(rankings)), digits = 0) %>%
      formatStyle(
        'overall_rating',
        background = styleColorBar(rankings$overall_rating, '#27ae60'),
        backgroundSize = '100% 90%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  # Output: Database Info
  output$db_info <- renderPrint({
    cat("=== EUROPEAN Football DATABASE ===\n\n")
    cat("Database Path:\n", db_path, "\n\n")
    
    cat("TABLES:\n")
    cat("• Country: 11 countries\n")
    cat("• League: 11 leagues\n")
    cat("• Match: 25,979 matches (115 columns)\n")
    cat("• Player: 11,060 players (7 columns)\n")
    cat("• Player_Attributes: 184,000 records (42 columns)\n")
    cat("• Team: 299 teams (5 columns)\n")
    cat("• Team_Attributes: 1,458 records (25 columns)\n\n")
    
    cat("PROCESSED DATA:\n")
    cat("Players loaded:", nrow(player_stats), "\n")
    cat("Date range: Multiple seasons\n")
    cat("Attributes per player:", length(available_metrics), "\n")
  })
  
  # Output: Metrics list
  output$metrics_list <- renderPrint({
    cat("All", length(available_metrics), "FIFA attributes:\n\n")
    cat(paste(1:length(available_metrics), ". ", available_metrics, sep = "", collapse = "\n"))
  })
  
  # Download: Plot
  output$download_plot <- downloadHandler(
    filename = function() {
      paste("player_radar_", Sys.Date(), ".png", sep = "")
    },
    content = function(file) {
      png(file, width = 1400, height = 900, res = 120)
      
      req(selected_data())
      data <- selected_data()
      radar_data <- prepare_radar_data(data, selected_metrics())
      colors <- c("#e74c3c", "#3498db", "#27ae60", "#f39c12")
      
      radarchart(
        radar_data,
        axistype = 1,
        pcol = colors[1:nrow(data)],
        pfcol = scales::alpha(colors[1:nrow(data)], input$transparency),
        plwd = input$line_width,
        plty = 1,
        cglcol = "grey",
        cglty = 1,
        cglwd = 0.8,
        caxislabels = seq(0, 100, 25),
        axislabcol = "grey30",
        vlcex = 1.3,
        title = "Player Performance Comparison - FIFA Ratings"
      )
      
      legend(
        x = "topright",
        legend = data$Player,
        col = colors[1:nrow(data)],
        lty = 1,
        lwd = input$line_width,
        bty = "n",
        cex = 1.2
      )
      
      dev.off()
    }
  )
  
  # Download: Data
  output$download_data <- downloadHandler(
    filename = function() {
      paste("player_data_", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      write.csv(searched_players(), file, row.names = FALSE)
    }
  )
}

# ============================================================================
# RUN THE APPLICATION
# ============================================================================

shinyApp(ui = ui, server = server)