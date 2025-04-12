require "http/client"
require "json"
require "option_parser"
require "colorize" # Using the standard Crystal colorize shard

# Module for interacting with an ollama server.
module LlamaClient
  # Sends a text prompt to the ollama API and returns the generated text.
  require "http/client"
require "json"
require "option_parser"
require "colorize" # Using the standard Crystal colorize shard

# Module for interacting with an ollama server.
module LlamaClient
  # Sends a prompt (with conversation history) to the Ollama chat API
  # and returns the generated text response.
  #
  # This method constructs a JSON payload, sends it via HTTP POST to the
  # specified Ollama API endpoint, parses the response, and extracts the
  # generated message content.
  #
  # It includes basic error handling for network issues, JSON parsing,
  # and non-successful HTTP responses, printing error details to STDOUT
  # and returning `nil` in case of failure.
  #
  # ### Parameters
  #
  # * `messages` (`Array(Hash(String,String))`): The conversation history.
  #     Each hash should represent a message with `"role"` (e.g., "user",
  #     "assistant") and `"content"` keys.
  # * `model` (`String`): The name of the Ollama model to use for generation
  #     (e.g., "llama3:latest", "mistral:latest").
  # * `temperature` (`Float64`, optional): Controls the randomness of the output.
  #     Higher values (e.g., 1.0) make output more random, lower values (e.g., 0.2)
  #     make it more deterministic. Defaults to `0.6`.
  # * `top_p` (`Float64`, optional): Nucleus sampling parameter. The model considers
  #     only the tokens whose cumulative probability mass exceeds `top_p`.
  #     Defaults to `0.7`.
  # * `max_tokens` (`Int32`, optional): *Note: This parameter is defined but currently
  #     commented out in the request body (`num_predict`).* It's intended to limit
  #     the maximum number of tokens in the generated response. Defaults to `700`.
  # * `api_url` (`String`, optional): The full URL of the Ollama chat API endpoint.
  #     Defaults to `"http://localhost:11434/api/chat"`.
  #
  # ### Returns
  #
  # * `String`: The content of the generated message from the Ollama model on success.
  # * `Nil`: If any error occurs during the API request, response processing,
  #     or if the expected content structure is not found in the response.
  #     An error message will be printed to STDOUT in these cases.
  #
  # ### Example Usage
  #
  # ```crystal
  # history = [
  #   {"role" => "user", "content" => "Hello there!"}
  # ]
  # response_content = LlamaClient.send_text(
  #   messages: history,
  #   model: "mistral:latest"
  # )
  #
  # if response_content
  #   puts "Ollama replied: #{response_content}"
  # else
  #   puts "Failed to get response."
  # end
  # ```
  def self.send_text(messages : Array(Hash(String,String)), model : String, temperature : Float64 = 0.6, top_p : Float64 = 0.7, max_tokens : Int32 = 700, api_url : String = "http://localhost:11434/api/chat")
    headers = HTTP::Headers{
      "Content-Type" => "application/json",
    }

    body = {
      model:  model,
      messages: messages,
      stream: false,
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

# --- Command Line Argument Parsing ---
OptionParser.parse do |parser|
  parser.banner = "Usage: crystal run your_script_name.cr [options]"
  parser.on("-m MODEL", "--model=MODEL", "Ollama model name (default: #{model_name})") { |m| model_name = m }
  parser.on("-u URL", "--url=URL", "Ollama API URL (default: #{api_url})") { |u| api_url = u }
  parser.on("-t TEMP", "--temperature=TEMP", "Generation temperature (default: #{temperature})") { |t| temperature = t.to_f64 }
  parser.on("-p TOP_P", "--top_p=TOP_P", "Nucleus sampling top_p (default: #{top_p})") { |p| top_p = p.to_f64 }
  # parser.on("--max-tokens=N", "Max tokens (may map to num_predict) (default: #{max_tokens})") { |n| max_tokens = n.to_i32 }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

# --- REPL Implementation ---
puts "\n#{ " Starting Crystal Ollama REPL ".colorize(:black).on(:cyan).mode(:bold) }"
puts "#{"Using model: ".colorize(:white)} #{model_name.colorize(:yellow)}"
puts "#{"API URL: ".colorize(:white)} #{api_url.colorize(:cyan)}"
puts "Type your prompt and press Enter."
puts "#{"Commands: ".colorize(:white)} #{"'clear'".colorize(:magenta)} #{"(reset context),".colorize(:white)} #{"'exit'".colorize(:magenta)} #{"or".colorize(:white)} #{"'quit'".colorize(:magenta)} #{"(end session)".colorize(:white)}"
puts "─" * 40 # divider

messages = [] of Hash(String,String)

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
    api_url: api_url
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