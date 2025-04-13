require "http/client"
require "json"
require "colorize"

module SevenMillion
  class OllamaClient
    @tool_manager : ToolManager

    def initialize(tool_manager : ToolManager)
      if tool_manager
        @tool_manager = tool_manager
      else
        raise ToolException.new("Could not get reference to ToolManager")
      end
    end

    def send_text(
      messages : Array(Hash(String, String)),
      model : String,
      temperature : Float64 = 0.6,
      top_p : Float64 = 0.7,
      max_tokens : Int32 = 700,
      api_url : String = "http://localhost:11434/api/chat",
      tools : Array(ToolData) = [] of ToolData,
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

          if tool_calls = @tool_manager.extract_tool_calls?(response_data)
            puts tool_calls
          else
            puts "No tool calls"
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
        # Where is the Obama server?
        return nil
      rescue ex : ToolException
        puts "#{"Error with tool data response: ".colorize(:red).mode(:bold)} #{ex.message}"
        return nil
      end
    end # method send_text
  end   # end class OllamaClient
end     # end module SevenMillion
