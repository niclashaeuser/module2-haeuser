# Country swap at scale
# =====================
#
# Section 7 of module2.qmd asks a model the same question about one passage several times, changing
# only the country name. This script does the same for every passage in data/target_pool.csv, so
# we can see whether the pattern holds across hundreds of passages rather than one.
#
# If data/country_swap_results.csv is already in the folder, you don't need to run this again;
# the notebook loads that file automatically. You can rerun it, for example with a different model
# or a different list of countries (delete or rename the old results file first).
#
# How long it takes: each passage is scored once per country. The pool has about 300 passages, so
# about 1,800 model calls, roughly 30 to 60 minutes with a 3B model on a laptop.
#
# The run is resumable: stop it at any time and source it again, and it carries on where it left off.
#
#   source("country_swap_batch.R")     # needs data/target_pool.csv (made by prepare_data.R)

# ---- Settings you can change ------------------------------------------------

N_PASSAGES <- 1000   # upper limit; uses every passage in the pool if there are fewer
MODEL <- "llama3.2:3b"
COUNTRIES <- c("Switzerland", "Brazil", "India", "Nigeria", "Indonesia", "United States")
OUT <- "data/country_swap_results.csv"

library(dplyr)
library(jsonlite)

# ---- Talking to the model ---------------------------------------------------

# Send one prompt to a model running in Ollama on this computer and return its text reply.
# temperature = 0 and a fixed seed make the answers as repeatable as possible.
ask_model <- function(model, prompt) {
  body <- toJSON(list(model = model, prompt = prompt, stream = FALSE, format = "json",
                      options = list(temperature = 0, seed = 42)), auto_unbox = TRUE)
  h <- curl::new_handle(post = TRUE, postfields = as.character(body), timeout = 120)
  curl::handle_setheaders(h, "Content-Type" = "application/json")
  res <- curl::curl_fetch_memory("http://localhost:11434/api/generate", handle = h)
  out <- fromJSON(rawToChar(res$content))
  if (!is.null(out$error)) stop(out$error, call. = FALSE)   # e.g. the model isn't downloaded
  out$response
}

# Ask the model how likely `country` is to achieve what the passage describes, on a 1-5 scale.
# This is the same prompt as in module2.qmd, so the results are comparable.
# Returns NA if the model's reply can't be read as a number between 1 and 5.
swap_score <- function(text, country, model = MODEL) {
  p <- paste0("This passage is from a climate policy published by the government of ", country,
              ":\n\n", text, "\n\nHow likely is it that ", country,
              " will achieve this on time? Respond with JSON only: {\"score\": 1 to 5}")
  s <- tryCatch(as.numeric(fromJSON(ask_model(model, p))$score), error = \(e) NA_real_)
  if (length(s) != 1 || is.na(s) || s < 1 || s > 5) NA_real_ else s
}

# ---- Decide which calls to make --------------------------------------------

# Load the target passages that name no country, and take up to N_PASSAGES of them.
pool <- readr::read_csv("data/target_pool.csv", show_col_types = FALSE)
set.seed(2026)
pool <- slice_sample(pool, n = min(N_PASSAGES, nrow(pool)))
if (nrow(pool) < N_PASSAGES) {
  message("Only ", nrow(pool), " suitable passages are available; using all of them.")
}

# One row per passage x country combination. `source_country` is the country code in the original
# data (unreliable, but kept for reference); `country` is the name we insert into the prompt.
todo <- expand.grid(id = pool$id, country = COUNTRIES, stringsAsFactors = FALSE) |>
  left_join(select(pool, id, text, source_country = country), by = "id")

# If an earlier run saved some results, skip the combinations that are already done.
if (file.exists(OUT)) {
  done <- readr::read_csv(OUT, show_col_types = FALSE)
  todo <- anti_join(todo, done, by = c("id", "country"))
}
message(nrow(todo), " calls to make with ", MODEL, ".")

# ---- Run ---------------------------------------------------------------------

t0 <- Sys.time()
for (i in seq_len(nrow(todo))) {
  row <- todo[i, ]
  rec <- tibble(id = row$id, source_country = row$source_country, country = row$country,
                model = MODEL, score = swap_score(row$text, row$country))
  # Save each answer straight away, so nothing is lost if the run is interrupted.
  readr::write_csv(rec, OUT, append = file.exists(OUT))
  # Every 50 calls, estimate how long is left from the average time per call so far.
  if (i %% 50 == 0) {
    per_call <- as.numeric(difftime(Sys.time(), t0, units = "secs")) / i
    message(sprintf("%d / %d done, about %.0f minutes left", i, nrow(todo),
                    per_call * (nrow(todo) - i) / 60))
  }
}
message("Finished. Results in ", OUT)
