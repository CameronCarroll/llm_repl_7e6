# src/seven_million.cr

# 🌌👽🚀~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~🚀👽🌌
#   * *
#      ✨          LLM REPL                  👾
#   * *
#      👾   S E V E N M I L L I O N          ✨
#   * *
# 🌌👽🚀~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~🚀👽🌌

# The LLM REPL SEVEN MILLION (`SevenMillion`) application is a terminal-based chat loop / REPL for interacting with an ollama server.
# It sends text to the model, prints the response, maintains a context until manually cleared or end of session, and handles tool calls in model response.
# (In case I get distracted, we've only implemented tool calling on the ollama side, up to the point that we have extracted the function name and args out of squishy-space and JSON::Any jail and could reassemble that into a function call in deterministic-space.)

#
# Usage:
#   Run the script using `crystal llm_repl_7e6.cr`.
#
# Commands:
#   - Type your prompt and press Enter to send it to the Ollama model.
#   - `clear`: Clears the conversation history (context).
#   - `exit` or `quit`: Ends the REPL session.
#
# Configuration:
#   - `model_name`: Specifies the Ollama model to use (default: "qwq:latest").
#   - `api_url`: Sets the URL of the Ollama API (default: "http://localhost:11434/api/chat").
#   - `temperature`, `top_p`, `max_tokens`: Control the generation parameters of the model.

# 🌟💫 ~~~~~~~~~~~~~~~~CODE STARTS NOW...~~~~~~~~~~~~~~~ 💫🌟
# 🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸

require "./seven_million/*"

module SevenMillion
  struct Config
    property model_name : String = "qwq:latest"
    property temperature : Float64 = 0.6
    property top_p : Float64 = 0.7
    property max_tokens : Int32 = 700
    property api_url : String = "http://localhost:11434/api/chat"
  end
end