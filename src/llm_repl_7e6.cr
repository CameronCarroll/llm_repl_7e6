require "http/client"
require "json"
require "option_parser"
require "colorize" # Using the standard Crystal colorize shard

alias ToolData = Hash(String, JSON::Any)
alias ToolListType = Array(ToolData)

class ToolException < Exception
end

# Module for interacting with an ollama server.
module LlamaClient

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

    begin
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
puts "─" * 40 # divider

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