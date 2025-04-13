require "http/client"
require "json"
require "colorize"

module SevenMillion


  # send_text(...) ░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓
  #
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
    messages : Array(Hash(String, String)),
    model : String,
    temperature : Float64 = 0.6,
    top_p : Float64 = 0.7,
    max_tokens : Int32 = 700,
    api_url : String = "http://localhost:11434/api/chat",
    tools : ToolListType = [] of ToolData,
  )
    headers = HTTP::Headers{
      "Content-Type" => "application/json",
    }

    body = {
      model:    model,
      messages: messages,
      stream:   false,
      tools:    tools,
      options:  {
        temperature: temperature,
        top_p:       top_p,
        # num_predict: max_tokens # Use num_predict if needed for your Ollama version
      },
    }.to_json

    puts "#{"Sending request to".colorize(:white)} #{api_url.colorize(:cyan)} #{"with model".colorize(:white)} #{model.colorize(:yellow)}#{"...".colorize(:white)}" if ENV["DEBUG"]?
    puts "#{"Body:".colorize(:white)} #{body}" if ENV["DEBUG"]?

    begin # ░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓
      response = HTTP::Client.post(api_url, headers: headers, body: body)

      puts "#{"Response Status:".colorize(:white)} #{response.status_code}" if ENV["DEBUG"]?

      if response.status.success?
        response_data = JSON.parse(response.body)

        tool_calls_array = [] of JSON::Any
        maybe_tool_calls = response_data["message"]?.try(&.["tool_calls"]?)
        #maybe_tool_calls = response_data.dig("message", "tool_calls")
        if maybe_tool_calls
          if maybe_tool_calls.as_a?
            tool_calls_array = maybe_tool_calls.as_a
          elsif maybe_tool_calls.as_h?
            tool_calls_array << maybe_tool_calls
          end
        end
        if tool_calls_array
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
        end # End tool calls handling

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
      # Where is the Obama server?
      return nil
    rescue ex : ToolException
      puts "#{"Error with tool data response: ".colorize(:red).mode(:bold)} #{ex.message}"
      return nil
    end
  end
end # end module SevenMillion
