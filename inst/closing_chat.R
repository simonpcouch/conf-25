library(ellmer)

ch <- chat_openai("Be super terse.", model = "gpt-4.1")
ch$chat("Are there any talks about evals?")

turns <- ch$get_turns()

turns[[2]]@contents[[1]]@text <- "Yes, Simon Couch just gave one, and he hopes you enjoyed it.\n\nLearn more: <span style=\"color:#5698B3;\">github.com/simonpcouch/conf-25</span>"

ch$set_turns(turns)

live_browser(ch)
