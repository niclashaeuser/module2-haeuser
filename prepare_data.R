# Prepare the data for the lab
# ============================
#
# This script builds the three data files the lab uses. They are already in the data/ folder,
# so you don't need to run it again. You can though - for example to draw a bigger or different
# sample or to see exactly how the passages were chosen. Rerunning with a different N_EACH or SEED
# gives you a different set of passages (and the notebook will rerun the models to match).
#
# What it creates:
#   data/sample.csv         passages with and without a target, plus the experts' labels (sections 1-6)
#   data/more_passages.csv  100 additional passages, labels removed (section 8, "ask your own question")
#   data/target_pool.csv    target passages that don't name a country (section 7, country swap)
#
# Source: Climate Policy Radar, national-climate-targets (CC-BY 4.0)
# https://huggingface.co/datasets/ClimatePolicyRadar/national-climate-targets
#
# To run it:
#   install.packages(c("nanoparquet", "dplyr", "readr", "curl", "countrycode"))
#   source("prepare_data.R")

# ---- Settings you can change ------------------------------------------------

LOCAL_FILE <- NULL   # path to the dataset if you downloaded it yourself, e.g. "~/Downloads/0000.parquet"
N_EACH <- 50         # how many passages WITH a target, and how many WITHOUT, go into the sample
SEED <- 2026         # fixes the random draw, so the same settings always give the same passages

library(dplyr)

# ---- 1. Get the dataset -----------------------------------------------------

# Hugging Face stores the dataset as a single parquet file (a compact table format).
url <- paste0("https://huggingface.co/datasets/ClimatePolicyRadar/national-climate-targets/",
              "resolve/refs%2Fconvert%2Fparquet/default/train/0000.parquet")

# Download to a temporary file unless you've pointed LOCAL_FILE at a copy you already have.
path <- LOCAL_FILE
if (is.null(path)) {
  path <- tempfile(fileext = ".parquet")
  curl::curl_download(url, path)
}

# Read it into R. One row per passage; the columns include the text, the country code, the region,
# whether it was machine-translated, and three 0/1 expert labels (net zero, reduction, other).
raw <- if (grepl("\\.csv$", path)) {
  readr::read_csv(path, show_col_types = FALSE)
} else {
  nanoparquet::read_parquet(path)
}

# ---- 2. The main sample (sections 1 to 6) ----------------------------------

set.seed(SEED)
sample <- raw |>
  # Collapse the three expert labels into one yes/no: does the passage contain ANY kind of target?
  # Keep a readable version of which kind it was, for the disagreements section.
  mutate(expert_target = as.integer(annotation_NZT + annotation_Reduction + annotation_Other > 0),
         expert_type = case_when(
           annotation_NZT == 1 ~ "net zero",
           annotation_Reduction == 1 ~ "emissions reduction",
           annotation_Other == 1 ~ "other",
           TRUE ~ "none")) |>
  # Drop very short fragments and very long passages, so everything is readable in class.
  filter(nchar(text) >= 100, nchar(text) <= 1200) |>
  # Draw N_EACH passages with a target and N_EACH without. A 50/50 split makes the comparison with
  # the experts informative, but it is NOT the real share of targets in policy documents.
  group_by(expert_target) |>
  slice_sample(n = N_EACH) |>
  ungroup() |>
  # Shuffle, so targets and non-targets are mixed when students code them.
  slice_sample(prop = 1) |>
  # Number the passages 1, 2, 3, ... and keep only the columns the notebook uses.
  mutate(id = row_number()) |>
  select(id, text, country = geography, region, translated, expert_target, expert_type)

readr::write_csv(sample, "data/sample.csv")
message("Wrote data/sample.csv: ", nrow(sample), " passages (", sum(sample$expert_target), " with a target).")

# ---- 3. Extra passages for section 8 ("ask your own question") -------------

# 100 random passages that are not in the main sample. The expert labels are left out on purpose:
# students write their own question and their own definition, so their hand-coding is the benchmark.
more <- raw |>
  filter(nchar(text) >= 100, nchar(text) <= 1200, !text %in% sample$text) |>
  slice_sample(n = 100) |>
  mutate(id = row_number()) |>
  select(id, text, country = geography, region, translated)
readr::write_csv(more, "data/more_passages.csv")
message("Wrote data/more_passages.csv: ", nrow(more), " passages for students' own questions.")

# ---- 4. Passages for the country swap (section 7 and country_swap_batch.R) --

# The country swap tells the model "this passage is from the government of X" and varies X.
# That only reads naturally if the passage doesn't already name a country, so we drop any passage
# that mentions one. We start from a short list and, if the countrycode package is installed,
# add every country name it knows.
country_names <- c("Switzerland", "Brazil", "India", "Nigeria", "Indonesia", "United States",
                   "European Union", "EU", "UK", "China", "Russia")
if (requireNamespace("countrycode", quietly = TRUE)) {
  country_names <- unique(c(country_names, na.omit(countrycode::codelist$country.name.en)))
} else {
  message("Tip: install.packages('countrycode') for a more complete country-name filter.")
}

# Build one search pattern that matches any of those names as a whole word
# (\\b marks a word boundary, so "India" matches "India" but not "Indian" or "Indiana").
pattern <- paste0("\\b(", paste(gsub("([.()])", "\\\\\\1", country_names), collapse = "|"), ")\\b")

pool <- raw |>
  # Keep passages the experts marked as containing any kind of target...
  filter(annotation_NZT + annotation_Reduction + annotation_Other > 0,
         nchar(text) >= 100, nchar(text) <= 1200,
         # ...and drop any that name a country.
         !grepl(pattern, text, ignore.case = TRUE)) |>
  mutate(id = row_number()) |>
  select(id, text, country = geography, region)
readr::write_csv(pool, "data/target_pool.csv")
message("Wrote data/target_pool.csv: ", nrow(pool), " target passages for the country swap.")
