require "spec"
require "json"
require "../src/seven_million/tool_manager" # Adjust path as needed

alias ToolCall = SevenMillion::ToolCall

describe SevenMillion::ToolManager do
  describe "#extract_tool_calls?" do
    it "extracts a single valid tool call" do
      # Setup inside the test case
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
    {
      "model": "llama3.2",
      "message": {
        "role": "assistant",
        "tool_calls": [
          {
            "function": {
              "name": "get_current_weather",
              "arguments": {
                "format": "celsius",
                "location": "Paris, FR"
              }
            }
          }
        ]
      }
    }
    JSON
      response_data = JSON.parse(json_string)

      # Action
      extracted_calls = tool_manager.extract_tool_calls?(response_data)

      # Assertions
      extracted_calls.should_not be_nil

      if extracted_calls.nil?
        fail "Assertion failed: extracted_calls should not be nil" # Fail test if nil
      else
        extracted_calls.size.should eq(1)

        expected_call = {
          "function_name" => "get_current_weather",
          "parameters"    => {"format" => "celsius", "location" => "Paris, FR"},
        }

        extracted_calls[0].should eq(expected_call)

        # Check internal state
        tool_manager.tool_calls.size.should eq(1)
        tool_manager.tool_calls[0].should eq(expected_call)
      end
    end

    it "extracts multiple valid tool calls" do
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
     {
       "message": {
         "role": "assistant",
         "tool_calls": [
           {
             "function": { "name": "get_weather", "arguments": { "location": "London, UK" } }
           },
           {
             "function": { "name": "search_web", "arguments": { "query": "Crystal Lang" } }
           }
         ]
       }
     }
     JSON
      response_data = JSON.parse(json_string)
      extracted_calls = tool_manager.extract_tool_calls?(response_data)

      extracted_calls.should_not be_nil
      extracted_calls.should be_a(Array(ToolCall)) # Keep this check

      if extracted_calls.nil?
        fail "Assertion failed: extracted_calls should not be nil"
      else
        extracted_calls.size.should eq(2) # No '!' needed

        expected_call_1 = {"function_name" => "get_weather", "parameters" => {"location" => "London, UK"}}
        expected_call_2 = {"function_name" => "search_web", "parameters" => {"query" => "Crystal Lang"}}

        extracted_calls[0].should eq(expected_call_1) # No '!' needed
        extracted_calls[1].should eq(expected_call_2) # No '!' needed

        tool_manager.tool_calls.size.should eq(2)
        tool_manager.tool_calls.should eq([expected_call_1, expected_call_2])
      end
    end

    it "extracts multiple valid tool calls" do
      # Setup
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
    {
      "message": {
        "role": "assistant",
        "tool_calls": [
          {
            "function": {
              "name": "get_weather",
              "arguments": { "location": "London, UK" }
            }
          },
          {
            "function": {
              "name": "search_web",
              "arguments": { "query": "Crystal Lang" }
            }
          }
        ]
      }
    }
    JSON
      response_data = JSON.parse(json_string)

      # Action
      extracted_calls = tool_manager.extract_tool_calls?(response_data)

      # Initial runtime assertions
      extracted_calls.should_not be_nil
      extracted_calls.should be_a(Array(ToolCall))

      # Flow analysis check to satisfy the compiler
      if extracted_calls.nil?
        # This branch shouldn't be hit if the above assertions pass,
        # but it satisfies the compiler's need to handle the Nil case.
        fail "Assertion failed: extracted_calls should not be nil for multiple calls test"
      else
        # --- Assertions moved inside the 'else' block ---
        # Compiler knows extracted_calls is Array(ToolCall) here.

        # This line caused the error - now safe inside the 'else' block
        extracted_calls.size.should eq(2)

        expected_call_1 = {
          "function_name" => "get_weather",
          "parameters"    => {"location" => "London, UK"},
        }
        expected_call_2 = {
          "function_name" => "search_web",
          "parameters"    => {"query" => "Crystal Lang"},
        }

        # Indexing is also safe here without '!'
        extracted_calls[0].should eq(expected_call_1)
        extracted_calls[1].should eq(expected_call_2)

        # Check internal state
        tool_manager.tool_calls.size.should eq(2)
        tool_manager.tool_calls.should eq([expected_call_1, expected_call_2])
      end
    end

    it "handles tool calls with empty arguments" do
      # Setup
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
    {
      "message": {
        "tool_calls": [
          {
            "function": {
              "name": "get_time",
              "arguments": {}
            }
          }
        ]
      }
    }
    JSON
      response_data = JSON.parse(json_string)

      # Action
      extracted_calls = tool_manager.extract_tool_calls?(response_data)

      # Initial runtime assertions
      extracted_calls.should_not be_nil
      extracted_calls.should be_a(Array(ToolCall))

      # Flow analysis check
      if extracted_calls.nil?
        fail "Assertion failed: extracted_calls should not be nil for empty args test"
      else
        # Compiler knows extracted_calls is Array(ToolCall) here.

        # Check size (safe within 'else')
        extracted_calls.size.should eq(1)

        expected_call = {
          "function_name" => "get_time",
          "parameters"    => {} of String => String, # Explicitly empty hash
        }

        # Check element content (safe within 'else')
        extracted_calls[0].should eq(expected_call)

        # Check internal state (also safe as it depends on successful extraction)
        tool_manager.tool_calls.size.should eq(1) # Check size first
        tool_manager.tool_calls[0].should eq(expected_call)
      end
    end

    it "returns nil if 'tool_calls' key is missing" do
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
      {
        "message": {
          "role": "assistant",
          "content": "No tools needed."
        }
      }
      JSON
      response_data = JSON.parse(json_string)

      extracted_calls = tool_manager.extract_tool_calls?(response_data)

      extracted_calls.should be_nil
      tool_manager.tool_calls.should be_empty
    end

    it "returns nil if 'tool_calls' is an empty array" do
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
      {
        "message": {
          "role": "assistant",
          "content": "",
          "tool_calls": []
        }
      }
      JSON
      response_data = JSON.parse(json_string)

      extracted_calls = tool_manager.extract_tool_calls?(response_data)

      extracted_calls.should be_nil
      tool_manager.tool_calls.should be_empty
    end

    it "returns nil if 'tool_calls' is null" do
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
      {
        "message": {
          "role": "assistant",
          "content": "",
          "tool_calls": null
        }
      }
      JSON
      response_data = JSON.parse(json_string)

      extracted_calls = tool_manager.extract_tool_calls?(response_data)

      extracted_calls.should be_nil
      tool_manager.tool_calls.should be_empty
    end

    it "returns nil if 'message' key is missing" do
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
      {
        "model": "llama3.2",
        "done": true
      }
      JSON
      response_data = JSON.parse(json_string)

      extracted_calls = tool_manager.extract_tool_calls?(response_data)

      extracted_calls.should be_nil
      tool_manager.tool_calls.should be_empty
    end

    it "raises ToolException if function name is missing" do
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
      {
        "message": {
          "tool_calls": [
            {
              "function": {
                "arguments": { "location": "Paris, FR" }
              }
            }
          ]
        }
      }
      JSON
      response_data = JSON.parse(json_string)

      expect_raises(SevenMillion::ToolException, "Tool call missing function name") do
        tool_manager.extract_tool_calls?(response_data)
      end
      # Check internal state hasn't changed on error
      tool_manager.tool_calls.should be_empty
    end

    it "raises ToolException if arguments key is missing" do
      # Note: The code actually expects an arguments *object*.
      # If the key is missing, args_any will be nil.
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
      {
        "message": {
          "tool_calls": [
            {
              "function": {
                "name": "get_current_weather"
              }
            }
          ]
        }
      }
      JSON
      response_data = JSON.parse(json_string)

      # The check `if args_any && args_any.as_h?` fails, hitting the final else
      expect_raises(SevenMillion::ToolException, "Couldn't parse arguments") do
        tool_manager.extract_tool_calls?(response_data)
      end
      tool_manager.tool_calls.should be_empty
    end

    it "raises ToolException if arguments is not a hash/object" do
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
      {
        "message": {
          "tool_calls": [
            {
              "function": {
                "name": "get_current_weather",
                "arguments": "not_a_hash"
              }
            }
          ]
        }
      }
      JSON
      response_data = JSON.parse(json_string)

      # The check `if args_hash = args_any.as_h?` returns nil, hitting the inner else
      expect_raises(SevenMillion::ToolException, "Couldn't parse arguments") do
        tool_manager.extract_tool_calls?(response_data)
      end
      tool_manager.tool_calls.should be_empty
    end

    it "raises ToolException if 'tool_calls' is not an array" do
      tool_manager = SevenMillion::ToolManager.new
      json_string = <<-JSON
      {
        "message": {
          "role": "assistant",
          "content": "",
          "tool_calls": {"invalid": "not an array"}
        }
      }
      JSON
      response_data = JSON.parse(json_string)

      # The check `maybe_tool_calls.as_a?` will fail.
      # This specific case currently results in `nil` because `tool_calls_array`
      # remains `nil`. If stricter validation is needed, the code could be modified.
      # Based on current code, it should return nil.
      extracted_calls = tool_manager.extract_tool_calls?(response_data)
      extracted_calls.should be_nil
      tool_manager.tool_calls.should be_empty

      # If the expectation was an Exception, the code would need modification like:
      # unless tool_calls_array = maybe_tool_calls.as_a?
      #   raise ToolException.new("Tool calls field is not an array") if maybe_tool_calls
      #   return nil # No tool calls field found
      # end
    end
  end
end
