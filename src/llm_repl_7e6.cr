require "http/client"
require "json"
require "option_parser"
require "colorize"

# 🌌👽🚀~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~🚀👽🌌
#   * *
#      ✨          LLM REPL                  👾
#   * *
#      👾   S E V E N M I L L I O N          ✨
#   * *
# 🌌👽🚀~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~🚀👽🌌

# The LLM REPL SEVEN MILLION (`SevenMillion`) application is a terminal-based chat loop / REPL for interacting with an ollama server.
# It sends text to the model, prints the response, maintains a context until manually cleared or end of session, and handles tool calls in model response.
# (In case I get distracted, we've only implemented tool calling on the ollama side, up to the point that we have the function name and args out of squishy-space and could reassemble that into a function call in deterministic-space.)

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


# Type alias for a hash representing tool data.
# Keys are strings, and values can be any JSON value.
alias ToolData = Hash(String, JSON::Any)
# Type alias for an array of ToolData, representing a list of tools.
alias ToolListType = Array(ToolData)

# Exception raised when an error occurs during tool invocation or processing.
class ToolException < Exception
end

module SevenMillion

  # Sends text messages to an Ollama server for generating a response.
  #
  # Args:
  #   messages (Array(Hash(String, String))): An array of message objects, where each object has "role" (either "user" or "assistant") and "content" keys.
  #   model (String): The name of the Ollama model to use.
  #   temperature (Float64, optional): Controls the randomness of the output. Higher values (e.g., 1.0) make the output more random, while lower values (e.g., 0.2) make it more focused and deterministic. Defaults to 0.6.
  #   top_p (Float64, optional): Controls the nucleus sampling. It considers the smallest set of tokens whose probability sum is at least `top_p`. Defaults to 0.7.
  #   max_tokens (Int32, optional): The maximum number of tokens to generate in the response. Defaults to 700.
  #   api_url (String, optional): The URL of the Ollama API endpoint for chat. Defaults to "http://localhost:11434/api/chat".
  #   tools (ToolListType, optional): An array of tool definitions to make available to the model. Defaults to an empty array.
  #
  # Returns:
  #   String | Nil: The generated text response from the Ollama model, or `nil` if an error occurred.
  #
  # Raises:
  #   ToolException: If the tool call response is missing a function name or arguments cannot be parsed.
  #
  # Examples:
  #   messages = [{"role" => "user", "content" => "Hello, how are you?"}]
  #   response = LlamaClient.send_text(messages, "llama2")
  #   puts response # Output: I'm doing well, thank you for asking!
  #
  #   messages = [{"role" => "user", "content" => "What's the weather in San Francisco?"}]
  #   tools = [{"type" => "function", "function" => {"name" => "get_current_weather", "description" => "...", "parameters" => {...}}}]
  #   response = LlamaClient.send_text(messages, "llama2", tools: tools)
  #   # If the model calls the tool, it will be processed and the response will be the tool's result.
  def self.send_text(
    messages : Array(Hash(String,String)),
     model : String,
     temperature : Float64 = 0.6,
     top_p : Float64 = 0.7,
     max_tokens : Int32 = 700,
     api_url : String = "http://localhost:11434/api/chat",
     tools : ToolListType = [] of ToolData
     )

    headers = HTTP::Headers{
      "Content-Type" => "application/json",
    }

    body = {
      model:  model,
      messages: messages,
      stream: false,
      tools: tools,
      options: {
        temperature: temperature,
        top_p:       top_p,
        # num_predict: max_tokens # Use num_predict if needed for your Ollama version
      }
    }.to_json

    puts "#{"Sending request to".colorize(:white)} #{api_url.colorize(:cyan)} #{"with model".colorize(:white)} #{model.colorize(:yellow)}#{"...".colorize(:white)}" if ENV["DEBUG"]?
    puts "#{"Body:".colorize(:white)} #{body}" if ENV["DEBUG"]?

    
    begin # ░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓
      response = HTTP::Client.post(api_url, headers: headers, body: body)

      puts "#{"Response Status:".colorize(:white)} #{response.status_code}" if ENV["DEBUG"]?

      if response.status.success?
        response_data = JSON.parse(response.body)

        tool_calls_array = [] of JSON::Any
        maybe_tool_calls = response_data.dig("message", "tool_calls")
        if maybe_tool_calls
          if maybe_tool_calls.as_a?
            tool_calls_array = maybe_tool_calls.as_a
          elsif maybe_tool_calls.as_h?
            tool_calls_array << maybe_tool_calls
          end
        end

        tool_calls_array.each do |tool|
          function_name_any = tool.dig("function", "name")
          function_name = function_name_any.as_s?

          unless function_name
            raise ToolException.new("Tool call missing function name")
          end

          puts "Processing function: #{function_name}"

          args_any = tool.dig("function", "arguments")
          if args_any && args_any.as_h?
            if args_hash = args_any.as_h?
              args_hash.each do |key, value|
                value_str = value.to_s
                puts key
                puts value_str
              end
            else
              raise ToolException.new("Couldn't parse arguments")
            end
          else
            raise ToolException.new("Couldn't parse arguments")
          end
        end

        if message_data = response_data["message"]?.try(&.as_h?)
          if content = message_data["content"]?.try(&.as_s?)
            return content
          else
            puts "#{"Error: ".colorize(:red).mode(:bold)} Response JSON received, but 'message.content' is missing or not a string."
            puts response_data.to_json # Print structure for debugging
            return nil
          end
        else
          puts "#{"Error: ".colorize(:red).mode(:bold)} Unexpected JSON structure in response. 'message' key missing or not a hash."
          puts response_data.to_json # Print structure for debugging
          return nil
        end
      else
        puts "#{"Error #{response.status_code}: ".colorize(:red).mode(:bold)} #{response.body}"
        return nil
      end
    rescue ex : JSON::ParseException
      puts "#{"Error parsing JSON response: ".colorize(:red).mode(:bold)} #{ex.message}"
      puts "Raw response body:".colorize(:yellow)
      return nil
    rescue ex : IO::Error # Catches network errors
      puts "#{"Network error: ".colorize(:red).mode(:bold)} #{ex.message}"
      puts "#{"Is the Ollama server running at ".colorize(:yellow)} #{api_url.colorize(:cyan)} #{"?".colorize(:yellow)}"
      return nil
    rescue ex : ToolException
      puts "#{"Error with tool data response: ".colorize(:red).mode(:bold)} #{ex.message}"
      return nil
    rescue ex : Exception # Generic catch-all
      puts "#{"An unexpected error occurred: ".colorize(:red).mode(:bold)} #{ex.message}"
      return nil
    end
  end
end

# `•.,¸,.•*´¨`*•.¸,.•*´¨`*•.¸,.•*´¨`*•. `•.,¸,.•*´¨`*•.¸,.•*´¨`*•.¸,.•*´¨`*•.

# Art by Shanaka Dias
# https://www.asciiart.eu/mythology/dragons
#               __
#           _.-'.-'-.__
#        .-'.       '-.'-._ __.--._
# -..'\,-,/..-  _         .'   \   '----._
#  ). /_ _\' ( ' '.         '-  '/'-----._'-.__
#  '..'     '-r   _      .-.       '-._ \
#  '.\. Y .).'       ( .'  .      .\          '\'.
#  .-')'|'/'-.        \)    )      '',_      _.c_.\
#    .<, ,>.          |   _/\        . ',   :   : \\
#   .' \_/ '.        /  .'   |          '.     .'  \)
#                   / .-'    '-.        : \   _;   ||
#                  / /    _     \_      '.'\ ' /   ||
#                 /.'   .'        \_      .|   \   \|
#                / /   /      __.---'      '._  ;  ||
#               /.'  _:-.____< ,_           '.\ \  ||
#              // .-'     '-.__  '-'-\_      '.\/_ \|
#             ( };====.===-==='        '.    .  \\: \
#              \\ '._        /          :   ,'   )\_ \
#               \\   '------/            \ .    /   )/
#                \|        _|             )Y    |   /
#                 \\      \             .','   /  ,/
#                  \\    _/            /     _/
#                   \\   \           .'    .'
#                    '| '1          /    .'
#                      '. \        |:    /
#                        \ |       /', .'
#                         \(      ( ;z'
#                          \:      \ '(_
#                           \_,     '._ '-.___
#                 snd                   '-' -.\


# --- REPL Configuration ---
model_name = "qwq:latest"
api_url = "http://localhost:11434/api/chat"
temperature = 0.6
top_p = 0.7
max_tokens = 700

# --- REPL Implementation ---
puts "\n#{ " Starting Crystal Ollama REPL ".colorize(:black).on(:cyan).mode(:bold) }"
puts "#{"Using model: ".colorize(:white)} #{model_name.colorize(:yellow)}"
puts "#{"API URL: ".colorize(:white)} #{api_url.colorize(:cyan)}"
puts "Type your prompt and press Enter."
puts "#{"Commands: ".colorize(:white)} #{"'clear'".colorize(:magenta)} #{"(reset context),".colorize(:white)} #{"'exit'".colorize(:magenta)} #{"or".colorize(:white)} #{"'quit'".colorize(:magenta)} #{"(end session)".colorize(:white)}"
puts "🌸" * 40 # divider

# Initialize messages
messages = [] of Hash(String,String)

tool_json_string = <<-JSON
{
  "type": "function",
  "function": {
    "name": "get_current_weather",
    "description": "Get the current weather for a location",
    "parameters": {
      "type": "object",
      "properties": {
        "location": {
          "type": "string",
          "description": "The location, e.g. San Francisco, CA"
        },
        "format": {
          "type": "string",
          "description": "Use 'celsius' or 'fahrenheit'",
          "enum": ["celsius", "fahrenheit"]
        }
      },
      "required": ["location", "format"]
    }
  }
}
JSON

weather_tool_def = JSON.parse(tool_json_string).as_h

tool_list : ToolListType = [weather_tool_def]

# 🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸🌼🌸

# Main REPL Loop
loop do
  print "> ".colorize(:green).mode(:bold)
  input = STDIN.gets
  break if input.nil?
  prompt = input.chomp.strip

  case prompt.downcase
  when "exit", "quit"
    break
  when "clear"
    messages.clear
    puts " Context cleared. ".colorize(:yellow).mode(:italic)
    puts "─" * 40 # Divider
    next
  when ""
    next
  end

  msg = { "role" => "user", "content" => prompt }
  messages << msg


  print "#{" ".colorize(:magenta).mode(:italic)}Thinking.."

  response = LlamaClient.send_text(
    messages: messages,
    model: model_name,
    temperature: temperature,
    top_p: top_p,
    api_url: api_url,
    tools: tool_list
  )

  print "\r\e[K" # Clear the "Thinking..." line

  if response
    puts "\n#{ "🤖 #{model_name}:".colorize(:blue).mode(:bold) }"
    puts response
    botmsg = { "role" => "assistant", "content" => response }
    messages << botmsg
  else
    puts "\n#{ "Error: Failed to get response from Ollama.".colorize(:red) }"
  end
  puts "\n" + "─" * 40 # Separator
end

puts "\n#{ " Exiting REPL. Goodbye! ".colorize(:black).on(:cyan).mode(:bold) }"

# Was that a... dragon?