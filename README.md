# llm_repl_7e6

The LLM REPL SEVEN MILLION (`SevenMillion`) application is a terminal-based chat loop / REPL for interacting with an ollama server.

It sends text to the model, prints the response, maintains a context until manually cleared or end of session, and handles tool calls in model response.

(In case I get distracted, we've only implemented tool calling on the ollama side, up to the point that we have extracted the function name and args out of squishy-space and JSON::Any jail and could reassemble that into a function call in deterministic-space.)

## Installation

* Needs Crystal Lang installed. Built with v1.15.1

## Usage

Usage:
   Run the script using `crystal llm_repl_7e6.cr`.

## Commands:
  - Type your prompt and press Enter to send it to the Ollama model.
  - `clear`: Clears the conversation history (context).
  - `exit` or `quit`: Ends the REPL session.

## Contributing

1. Fork it (<https://github.com/CameronCarroll/llm_repl_7e6/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [ieve](https://github.com/CameronCarroll) - creator and maintainer


module LlmRepl7e6
  VERSION = "0.1.0"