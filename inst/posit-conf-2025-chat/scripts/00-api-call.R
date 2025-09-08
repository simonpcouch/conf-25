library(httr2)
library(jsonlite)
library(purrr)
library(dplyr)
library(tidyr)
library(readr)
library(janitor)
library(tibble)
library(stringr)

payload <- "tab.day=20250918,20250916,20250917&search.day=20250916&search.day=20250918&search.day=20250917&type=session&browserTimezone=America%2FNew_York&catalogDisplay=list"

req <- request("https://events.conf.posit.co/api/search") |>
  req_method("POST") |>
  req_headers(
    `Content-Type` = "application/x-www-form-urlencoded; charset=UTF-8",
    `Accept` = "*/*",
    `Sec-Fetch-Site` = "cross-site",
    `Accept-Language` = "en-US,en;q=0.9",
    `Accept-Encoding` = "gzip, deflate, br",
    `Sec-Fetch-Mode` = "cors",
    `Origin` = "https://reg.rainfocus.com",
    `User-Agent` = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    `Referer` = "https://reg.rainfocus.com/",
    `Sec-Fetch-Dest` = "empty",
    `rfApiProfileId` = "oDos2PopAAEllY2HYh6s2xxvRcmcZHGe",
    `Priority` = "u=3, i",
    `rfWidgetId` = "GSqhY5UEq3FaXEHoQJrUFnDmsz4UGFCh",
    `Cookie` = "JSESSIONID=341780CAE383F8863252C1DE0F1DF48B"
  ) |>
  req_body_raw(charToRaw(payload))

resp <- tryCatch(
  req |> req_perform(),
  error = function(e) {
    message("Request failed: ", e$message)
    return(NULL)
  }
)

if (!is.null(resp)) {
  json <- resp_body_json(resp)
  
  resp_json <- resp_body_json(resp)
  
  resp_json |> 
    jsonlite::write_json(file.path("data", "api_response.json"))
}

## Process saved JSON file
resp_json <- jsonlite::read_json(file.path("data", "api_response.json"))

extract_session_info <- function(json_input) {
  json <- if (is.character(json_input)) fromJSON(json_input, simplifyVector = FALSE) else json_input
  items <- json$sectionList[[1]]$items
  items_with_participants <- items[map_lgl(items, ~ !is.null(.x$participants))]
  
  df <- map_dfr(items_with_participants, function(item) {
    session_code <- item$code[[1]]
    session_title <- item$title[[1]]
    abstract <- item$abstract[[1]]  # <- this contains the meaningful abstract
    session_type <- item$type[[1]]
    sessionID <- item$sessionID[[1]]
    start_time <- if (!is.null(item$times) && !is.null(item$times[[1]]$startTime)) item$times[[1]]$startTime[[1]] else NA
    room <- if (!is.null(item$times) && !is.null(item$times[[1]]$room)) item$times[[1]]$room[[1]] else NA
    
    # First check if childSessions exist
    if (!is.null(item$childSessions)) {
      map_dfr(item$childSessions, function(child) {
        talk_title <- child$title[[1]]
        talk_abstract <- child$abstract[[1]]
        sessionID_child <- child$sessionID[[1]]
        
        if (!is.null(child$participants)) {
          map_dfr(child$participants, function(p) {
            tibble(
              session_code = session_code,
              session_title = session_title,
              session_type = session_type,
              talk_title = talk_title,
              abstract = talk_abstract,
              sessionID = sessionID_child,
              start_time = start_time,
              room = room,
              speaker = p$globalFullName[[1]],
              globalJobTitle = if (!is.null(p$globalJobtitle)) p$globalJobtitle[[1]] else NA,
              globalBio = if (!is.null(p$globalBio)) p$globalBio[[1]] else NA,
              job_title = if (!is.null(p$jobTitle)) p$jobTitle[[1]] else NA,
              company = if (!is.null(p$companyName)) p$companyName[[1]] else NA
            )
          })
        } else {
          tibble()
        }
      })
    } else if (!is.null(item$participants)) {
      # Fall back to session-level info if no childSessions
      session_abstract <- item$abstract[[1]]
      
      map_dfr(item$participants, function(p) {
        talk_title <- if (!is.null(p$session) && !is.null(p$session[[1]]$title)) p$session[[1]]$title[[1]] else session_title
        
        tibble(
          session_code = session_code,
          session_title = session_title,
          session_type = session_type,
          talk_title = talk_title,
          abstract = session_abstract,
          sessionID = sessionID,
          start_time = start_time,
          room = room,
          speaker = p$globalFullName[[1]],
          globalJobTitle = if (!is.null(p$globalJobtitle)) p$globalJobtitle[[1]] else NA,
          globalBio = if (!is.null(p$globalBio)) p$globalBio[[1]] else NA,
          job_title = if (!is.null(p$jobTitle)) p$jobTitle[[1]] else NA,
          company = if (!is.null(p$companyName)) p$companyName[[1]] else NA
        )
      })
    } else {
      tibble()
    }
  })
  
  return(df)
}

result <- extract_session_info(resp_json) |>
  rename_with(~ gsub("^global", "", .), starts_with("global")) |>
  janitor::clean_names()

# Reformat result to comply with required chunks df format for ragnar
result <- result |>
 mutate( 
   text = glue::glue( 
"## Title: {talk_title}
**Code:** {session_code}
**Session type:** {session_type}

**Abstract:**
{abstract}

**Speaker name:** {speaker}
**Job title:** {job_title}
**Company:** {company}
**Bio:**
{bio}")
) |> 
  select(session_title, talk_title, session_type, text)

## concatenate text column according to session_title groups
result <- result |>
  group_by(session_type, session_title) |>
  summarise(abstract_text = paste(text, collapse = "\n\n"), .groups = "drop") |>
  mutate(session_title = str_squish(session_title))

result |>
  write_csv(file.path("data", "posit-conf-2025-abstracts.csv"))
