

require "./seven_million/*"

# Type alias for a hash representing tool data.
# Keys are strings, and values can be any JSON value.
alias ToolData = Hash(String, JSON::Any)
# Type alias for an array of ToolData, representing a list of tools.
alias ToolListType = Array(ToolData)

# Exception raised when an error occurs during tool invocation or processing.
class ToolException < Exception
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
puts "\n#{" Starting Crystal Ollama REPL ".colorize(:black).on(:cyan).mode(:bold)}"
puts "#{"Using model: ".colorize(:white)} #{model_name.colorize(:yellow)}"
puts "#{"API URL: ".colorize(:white)} #{api_url.colorize(:cyan)}"
puts "Type your prompt and press Enter."
puts "#{"Commands: ".colorize(:white)} #{"'clear'".colorize(:magenta)} #{"(reset context),".colorize(:white)} #{"'exit'".colorize(:magenta)} #{"or".colorize(:white)} #{"'quit'".colorize(:magenta)} #{"(end session)".colorize(:white)}"
puts "🌸" * 40 # divider

# Initialize messages
message_mgr = SevenMillion::ContextManager.new

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
    message_mgr.clear
    puts " Context cleared. ".colorize(:yellow).mode(:italic)
    puts "─" * 40 # Divider
    next
  when ""
    next
  end

  message_mgr.add_user_message(prompt)

  print "#{" ".colorize(:magenta).mode(:italic)}Thinking.."

  response = SevenMillion.send_text(
    messages: message_mgr.get_messages,
    model: model_name,
    temperature: temperature,
    top_p: top_p,
    api_url: api_url,
    tools: tool_list
  )

  print "\r\e[K" # Clear the "Thinking..." line

  if response
    puts "\n#{"🤖 #{model_name}:".colorize(:blue).mode(:bold)}"
    puts response
    message_mgr.add_assistant_message(response)
  else
    puts "\n#{"Error: Failed to get response from Ollama.".colorize(:red)}"
  end
  puts "\n" + "─" * 40 # Separator
end

puts "\n#{" Exiting REPL. Goodbye! ".colorize(:black).on(:cyan).mode(:bold)}"

# Was that a... dragon?
