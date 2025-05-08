#!/usr/bin/env Rscript

# ---------------------- Setup & Dependencies ----------------------
options(repos = c(CRAN = "https://cloud.r-project.org"))

required_pkgs <- c(
  "optparse", "dplyr", "readr", "forcats", "stringr", "ggplot2", "tibble", "lubridate", "tidyr", "purrr",
  "tidytext", "textreadr", "ggwordcloud", "wordcloud2", "htmlwidgets", "pdftools", "png", "udpipe", "RColorBrewer"
)
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    suppressWarnings(
      suppressPackageStartupMessages(install.packages(pkg, dependencies = TRUE))
    )
  }
  suppressWarnings(
    suppressPackageStartupMessages(library(pkg, character.only = TRUE))
  )
}

# ---------------------- Argument Parsing ----------------------
option_list <- list(
  make_option(c("-d","--dir"),     type="character", help="Input directory containing text files"),
  make_option(c("-f","--files"),   type="character", help="Comma-separated list of text files (e.g., file1.txt,file2.txt)"),
  make_option(c("-o","--output"),  type="character", default="wordcloud.pdf", 
              help="Output file name with extension .pdf, .png, or .html"),
  make_option(c("--min_freq"),     type="integer",   default=5,   
              help="Minimum frequency for words to be included (default: 5)"),
  make_option(c("--max_words"),    type="integer",   default=100, 
              help="Maximum number of words in the cloud (default: 100)"),
  make_option(c("--stop_words_file"),type="character", default=NULL,
              help="Path to a file with additional stop words (one per line)"),
  make_option(c("--shape"),        type="character", default="circle", 
              help="Shape of the word cloud (e.g., circle, cardioid, diamond)"),
  make_option(c("--colors"),       type="character", default="Set1",    
              help="Color palette (e.g., Set1, Blues) or comma-separated colors (e.g., red,blue,green) or single color (e.g., black)"),
  make_option(c("--rotation"),     type="logical",   default=TRUE,     
              help="Rotate words randomly (TRUE/FALSE)"),
  make_option(c("--min_rotation"), type="integer",   default=-45,      
              help="Minimum rotation angle in degrees (e.g., -45)"),
  make_option(c("--max_rotation"), type="integer",   default=45,       
              help="Maximum rotation angle in degrees (e.g., 45)"),
  make_option(c("--bg_color"),     type="character", default="white",  
              help="Background color of the plot (e.g., white, black, #RRGGBB)"),
  make_option(c("--font_family"),  type="character", default="sans",   
              help="Font family for words (e.g., sans, serif, mono)"),
  make_option(c("--unwanted_words"),type="character", default=NULL,     
              help="Comma-separated list of words to exclude (e.g., word1,word2)"),
  make_option(c("--pos_tags"),     type="character", default="NOUN,ADJ", 
              help="Comma-separated list of POS tags to include (e.g., NOUN,VERB,ADJ)")
)

parser <- OptionParser(option_list = option_list)
opt    <- parse_args(parser)

# ---------------------- Read & Preprocess Text ----------------------
files <- c(
  if (!is.null(opt$dir))  list.files(opt$dir, full.names=TRUE),
  if (!is.null(opt$files)) str_split(opt$files, ",")[[1]] %>% str_trim()
)
if (length(files)==0) stop("No input files specified.")

raw_text <- files %>%
  map_chr(~ textreadr::read_document(.x) %>% str_c(collapse = " ")) %>%
  str_c(collapse = " ")

# Load UDPipe model for POS tagging
if (!file.exists("english-ewt-ud-2.5-191206.udpipe")) {
  udpipe_download_model(language = "english-ewt")
}
model <- udpipe_load_model("english-ewt-ud-2.5-191206.udpipe")

# Tokenize, POS tag, and filter by POS
tokens <- udpipe_annotate(model, x = raw_text) %>%
  as.data.frame() %>%
  select(token, upos) %>%
  rename(word = token) %>%
  filter(str_detect(word, "^[A-Za-z]{2,}$")) %>%
  filter(upos %in% str_split(opt$pos_tags, ",")[[1]])

# Build stop-word table
stop_tbl <- get_stopwords()
if (!is.null(opt$stop_words_file)) {
  extra <- suppressWarnings(read_lines(opt$stop_words_file)) %>% tibble(word = .)
  stop_tbl <- bind_rows(stop_tbl, extra)
}
if (!is.null(opt$unwanted_words)) {
  uw <- str_split(opt$unwanted_words, ",")[[1]] %>% str_trim() %>% tibble(word = .)
  stop_tbl <- bind_rows(stop_tbl, uw)
}

tokens <- tokens %>% anti_join(stop_tbl, by = "word")

# Word frequencies
word_freq <- tokens %>% count(word, sort = TRUE)
wf <- word_freq %>%
  filter(n >= opt$min_freq) %>%
  slice_max(n, n = opt$max_words)

# Add angle column for rotation
if (opt$rotation) {
  wf$angle <- runif(nrow(wf), opt$min_rotation, opt$max_rotation)
} else {
  wf$angle <- 0
}

# Determine color handling
if (str_detect(opt$colors, ",")) {
  # Multiple colors provided (e.g., "red,blue,green")
  colors_list <- str_split(opt$colors, ",")[[1]] %>% str_trim()
  num_colors <- length(colors_list)
  wf$color_group <- cut(wf$n, 
                       breaks = quantile(wf$n, probs = seq(0, 1, length.out = num_colors + 1)), 
                       include.lowest = TRUE, 
                       labels = FALSE)
  color_mapping <- scale_color_manual(values = colors_list)
  use_color_aes <- TRUE
} else if (opt$colors %in% rownames(brewer.pal.info)) {
  # Color palette provided (e.g., "Set1")
  wf$color_group <- wf$n
  color_mapping <- scale_color_distiller(palette = opt$colors)
  use_color_aes <- TRUE
} else {
  # Single color provided (e.g., "black")
  single_color <- opt$colors
  color_mapping <- NULL
  use_color_aes <- FALSE
}

# ---------------------- WORD CLOUD ----------------------
if (str_detect(opt$output, "\\.html$")) {
  # HTML output using wordcloud2 (unchanged)
  cloud <- wordcloud2(wf, size = 1, shape = opt$shape)
  suppressWarnings(
    htmlwidgets::saveWidget(cloud, file = opt$output, selfcontained = FALSE)
  )
} else {
  # PNG/PDF output using ggplot2 and ggwordcloud
  p_cloud <- ggplot(wf, aes(label = word, size = n, angle = angle)) +
    (if (use_color_aes) {
      geom_text_wordcloud_area(family = opt$font_family, aes(color = color_group))
    } else {
      geom_text_wordcloud_area(family = opt$font_family, color = single_color)
    }) +
    scale_size_area(max_size = 15) +
    (if (!is.null(color_mapping)) color_mapping else NULL) +
    theme_minimal() +
    theme(
      panel.background = element_rect(fill = opt$bg_color, color = NA),
      plot.background  = element_rect(fill = opt$bg_color, color = NA)
    )

  suppressWarnings(
    suppressMessages(
      ggsave(
        filename = opt$output,
        plot     = p_cloud,
        width    = 5,
        height   = 4,
        dpi      = 300
      )
    )
  )
}

# ---------------------- RADIAL BAR PLOT ----------------------
top_n <- min(30, nrow(word_freq))
radial_data <- word_freq %>%
  slice_max(n, n = top_n) %>%
  mutate(word = reorder(word, n))

p_radial <- ggplot(radial_data, aes(x = word, y = n)) +
  geom_col(fill = "steelblue") +
  coord_polar(start = 0) +
  geom_text(
    aes(label = paste0(round(n / sum(n) * 100, 1), "%")),
    position = position_stack(vjust = 1.02),
    size     = 3
  ) +
  theme_minimal() +
  theme(
    axis.text.x      = element_text(angle = 90, hjust = 1),
    panel.grid       = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background  = element_rect(fill = "white", color = NA)
  ) +
  labs(title = "Top 30 words by frequency", y = "Count", x = NULL)

radial_file <- sub("\\.[^.]+$", "_radial.pdf", opt$output)
suppressWarnings(
  pdf(file = radial_file, width = 8, height = 8, bg = "white")
)
print(p_radial)
suppressWarnings(dev.off())

message("Word cloud → ", opt$output)
message("Radial plot → ", radial_file)

