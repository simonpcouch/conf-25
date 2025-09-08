library(ragnar)
library(ellmer)
library(tibble)
library(duckdb)
library(readr)
library(dplyr)

sessions_df <- readr::read_csv(
  file.path("data", "posit-conf-2025-sessions.csv")
)

abstracts_df <- readr::read_csv(
  file.path("data", "posit-conf-2025-abstracts.csv")
)

# join sessions and abstracts and concatenate text and abstract_text
chunks_df <- sessions_df |>
  dplyr::left_join(abstracts_df, by = join_by("title" == "session_title")) |>
  dplyr::mutate(
    text = paste(text, abstract_text, sep = "\n\n---\n\n")
  ) |>
  dplyr::select(title, text) |>
  dplyr::distinct() |>
  tibble::as_tibble()

store_location <- file.path("data", "posit-conf-2025.ragnar.duckdb")

store <- ragnar::ragnar_store_create(
  location = store_location,
  embed = \(x) ragnar::embed_openai(x, model = "text-embedding-3-small"),
  overwrite = TRUE
)

ragnar::ragnar_store_insert(store, chunks_df)

# Example retrieval
store <- ragnar_store_connect(store_location, read_only = TRUE)
text <- "Sessions on causal inference"

embedding_near_chunks <- ragnar_retrieve_vss(store, text, top_k = 3)
embedding_near_chunks$text[1] |> cat(sep = "\n~~~~~~~~\n")

# embedding_near_chunks <- ragnar_retrieve(store, text)
# embedding_near_chunks$text[1] |> cat(sep = "\n~~~~~~~~\n")
