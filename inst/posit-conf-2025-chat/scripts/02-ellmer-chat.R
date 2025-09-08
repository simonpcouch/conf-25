library(ellmer)
library(ragnar)

store_location <- file.path("data", "posit-conf-2025.ragnar.duckdb")
store <- ragnar::ragnar_store_connect(store_location, read_only = TRUE)

read_prompt <- function(filepath) {
  paste(readLines(filepath), collapse = "\n")
}

system_prompt <- read_prompt("system-prompt.md")

chat <- ellmer::chat_openai(
  system_prompt,
  model = "gpt-4o-mini",
  api_args = list(temperature = .5)
)

ragnar_register_tool_retrieve_vss <-
  function(chat, store, store_description = "the knowledge store", ...) {
    rlang::check_installed("ellmer")
    store
    list(...)
    
    chat$register_tool(
      ellmer::tool(
        name = glue::glue("rag_retrieve_from_{store@name}"),
        function(text, status_ignore_workshops = status_ignore_workshops) {
          results <- ragnar::ragnar_retrieve_vss(store, text, ...)$text
          # Filter out entries containing 'workshop' if the toggle is on
          if (status_ignore_workshops) {
            results <- results[!grepl("workshop", results, ignore.case = TRUE)]
          }
          stringi::stri_flatten(results, "\n\n---\n\n")
        },
        glue::glue(
          "Given a string, retrieve the most relevent excerpts from {store_description}."
        ),
        arguments = list(text = ellmer::type_string(
          "The text to find the most relevent matches for."
        ),
        status_ignore_workshops = ellmer::type_boolean(
          "Whether to ignore workshops in the results."
        ))
      )
    )
    invisible(chat)
  }

ragnar_register_tool_retrieve_vss(chat, store, top_k = 10)

chat$chat("What sessions from Hadley? Ignore workshops.")
