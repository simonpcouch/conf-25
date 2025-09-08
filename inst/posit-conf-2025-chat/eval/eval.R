library(vitals)
library(ellmer)
library(tibble)

source("scripts/utilities.R")

vitals::vitals_log_dir_set("eval/logs")

read_md <- function(filepath) {
  paste(readLines(filepath), collapse = "\n")
}

system_prompt <- ellmer::interpolate_file(
  "system-prompt.md", 
  event_info = read_md("event-info.md"),
  status_ignore_workshops = FALSE
)

chat <- chat_openai(model = "gpt-4.1-mini", api_args = list(temperature = 0.2), system_prompt = system_prompt)

store_location <- file.path("data", "posit-conf-2025.ragnar.duckdb")
store <- ragnar::ragnar_store_connect(store_location, read_only = TRUE)
ragnar_register_tool_retrieve_vss(chat, store, top_k = 10)

sessions <- tribble(
  ~input, ~target,
  "What talks is Hadley giving this year?", "Hadley is giving a keynote session on Thursday, Sep 18 4:15 PM - 5:15 PM EDT in the Centennial Ballroom",
  "What workshops is Hadley doing?", "Hadley is doing a workshop on Tuesday, Sep 16 called R in Production",
  "Are there any sessions about causal inference", "Yes there will be a workshop titled Causal Inference in R led by Malcolm Barret and Lucy D'Agostino McGowan on Tuesday, Sep 16 9:00 AM - 5:00 PM EDT in Greenbriar",
  "I'm interested in learning about LLMs, what sessions should I attend?", "Multiple sessions including Programming with LLM APIs: A Beginner’s Guide in R and Python, LLMs with R and Python, and Facepalm-driven Development: Learning From AI and Human Errors",
  "When is the social event?", "Welcome Reception is at Tuesday, September 16, 5:00 PM - 7:00 PM EDT and Evening Event is at Wednesday, September 17, 7:00 PM - 9:00 PM EDT",
  "Who is doing the first keynote?", "Jonathan McPherson, Software Architect at Posit Software, PBC",
  "What sessions on ellmer?", "Programming with LLM APIs: A Beginner’s Guide in R and Python, Putting an {ellmer} AI in production with the blessing of IT"
)

tsk <- Task$new(
  dataset = sessions, 
  solver = generate(chat), 
  scorer = model_graded_qa()
)

tsk$eval()
