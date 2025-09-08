# Drops the original source of the bot client into inst/ and then 
# wraps the initialization code into a function that returns the client itself
conf_client <- function(client = 
  ellmer::chat_openai(model = "gpt-4.1-mini", api_args = list(temperature = 0.2))
) {
  system_prompt <- ellmer::interpolate_file(
    system.file("posit-conf-2025-chat/system-prompt.md", package = "conf-25"), 
    event_info = read_md(system.file("posit-conf-2025-chat/event-info.md", package = "conf-25")),
    status_ignore_workshops = FALSE
  )

  client$set_system_prompt(system_prompt)
  
  store_location <- system.file(file.path("posit-conf-2025-chat", "data", "posit-conf-2025.ragnar.duckdb"), package = "conf-25")
  store <- ragnar::ragnar_store_connect(store_location, read_only = TRUE)
  client <- ragnar_register_tool_retrieve_vss(client, store, top_k = 10)

  client
}

read_md <- function(filepath) {
  paste(readLines(filepath), collapse = "\n")
}

## Use alternative to default ragnar retrieval tool
ragnar_register_tool_retrieve_vss <-
  function(chat, store, store_description = "the knowledge store", ...) {
    rlang::check_installed("ellmer")
    store
    list(...)
    
    chat$register_tool(
      ellmer::tool(
        .name = glue::glue("rag_retrieve_from_{store@name}"),
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
        text = ellmer::type_string(
          "The text to find the most relevent matches for."
        ),
        status_ignore_workshops = ellmer::type_boolean(
          "Whether to ignore workshops in the results."
        )
      )
    )
    invisible(chat)
  }
