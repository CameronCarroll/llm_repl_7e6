# src/seven_million/tool_manager.cr
module SevenMillion
  alias ToolData = Hash(String, JSON::Any)
  # Tool call type: {'function_name', 'parameters'} => {(function name), (hash of parameter KV strings)}
  alias ToolCall = Hash(String, (String | Hash(String, String)))

  class ToolException < Exception; end

  class ToolManager
    @tools : Array(ToolData)
    @tool_calls : Array(ToolCall)

    def initialize
      @tools = [] of ToolData
      @tool_calls = [] of ToolCall
    end

    getter tool_calls

    # ░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓

    # Return the extracted calls, or nil if none found or error
    def extract_tool_calls?(response_data : JSON::Any) : (Array(ToolCall) | Nil)
      # Expecting an array of some nested hash
      # Array(Hash(String,JSON::Any))
      maybe_tool_calls = response_data["message"]?.try(&.["tool_calls"]?)
      if maybe_tool_calls && maybe_tool_calls.as_a?
        tool_calls_array = maybe_tool_calls.as_a
      end

      return nil unless tool_calls_array

      extracted_tool_calls = [] of ToolCall

      tool_calls_array.each do |tool|
        function_name_any = tool.dig("function", "name")
        function_name = function_name_any.as_s?

        unless function_name
          raise ToolException.new("Tool call missing function name")
        end

        puts "Processing function: #{function_name}"

        

        parameters_hash = Hash(String,String).new

        args_any = tool.dig("function", "arguments")
        if args_any && args_any.as_h?
          if args_hash = args_any.as_h?
            args_hash.each do |key, value|
              parameters_hash[key.to_s] = value.to_s
            end
          else
            raise ToolException.new("Couldn't parse arguments")
          end
        else
          raise ToolException.new("Couldn't parse arguments")
        end

        tool_call = {
          "function_name" => function_name,
          "parameters"    => parameters_hash,
        }
        extracted_tool_calls << tool_call
      end # tool call loop

      @tool_calls.concat(extracted_tool_calls)
      return extracted_tool_calls.empty? ? nil : extracted_tool_calls
    end # def handle_tool_calls?
    
  end   # class ToolManager
end     # module SevenMillion
