# spec/ollama_client_spec.cr
require "./spec_helper"

# Simple mocks for testing
class MockResponse
  getter status : HTTP::Status
  getter body : String

  def initialize(@status : HTTP::Status, @body : String)
  end
end

class MockToolManager < SevenMillion::ToolManager
  property calls = 0
  property last_args : JSON::Any? = nil
  property return_value : JSON::Any? = nil
  property should_raise = false

  def extract_tool_calls?(resp_json : JSON::Any) : JSON::Any?
    @calls += 1
    @last_args = resp_json
    if should_raise
      raise SevenMillion::ToolException.new("Failed to process tools")
    end
    return_value
  end
end

# Test version of OllamaClient that we can customize for tests
class TestOllamaClient < SevenMillion::OllamaClient
  class_property requests = [] of Tuple(String, HTTP::Headers, String)
  class_property response : MockResponse? = nil
  class_property should_raise = false

  def self.reset
    @@requests = [] of Tuple(String, HTTP::Headers, String)
    @@response = nil
    @@should_raise = false
  end

  def self.last_request
    @@requests.last?
  end
  
  def self.request_count
    @@requests.size
  end

  # Override the HTTP post method for testing
  def send_text(
    messages : Array(Hash(String, String)),
    model : String,
    temperature : Float64 = 0.6,
    top_p : Float64 = 0.7,
    max_tokens : Int32 = 700,
    api_url : String = "http://localhost:11434/api/chat",
    tools : Array(SevenMillion::ToolData) = [] of SevenMillion::ToolData,
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
      },
    }.to_json

    begin
      # Record the request
      TestOllamaClient.requests << {api_url, headers, body}

      # Simulate error if requested
      if TestOllamaClient.should_raise
        raise IO::Error.new("Connection refused")
      end

      # Get the response
      response = TestOllamaClient.response.not_nil!

      if response.status.success?
        begin
          response_data = JSON.parse(response.body)

          # Process tool calls
          if tool_calls = @tool_manager.extract_tool_calls?(response_data)
            # Tool calls found
          end

          if message_data = response_data["message"]?.try(&.as_h?)
            if content = message_data["content"]?.try(&.as_s?)
              return content
            else
              return nil
            end
          else
            return nil
          end
        rescue ex : JSON::ParseException
          return nil
        end
      else
        return nil
      end
    rescue ex : IO::Error
      return nil
    rescue ex : SevenMillion::ToolException
      return nil
    end
  end
end

describe SevenMillion::OllamaClient do
  # --- Tests for #initialize ---
  describe "#initialize" do
    it "initializes with a ToolManager" do
      # Setup
      tool_manager = MockToolManager.new
      
      # Action
      client = SevenMillion::OllamaClient.new(tool_manager)

      # Assertions
      client.should be_a(SevenMillion::OllamaClient)
    end
  end

  # --- Tests for #send_text ---
  describe "#send_text" do
    it "sends a request and returns content on successful response" do
      # Setup
      api_url = "http://mockhost:11434/api/chat"
      model = "test-model"
      messages = [{"role" => "user", "content" => "Hello"}]
      sample_tools_data = [] of SevenMillion::ToolData
      
      tool_manager = MockToolManager.new
      client = TestOllamaClient.new(tool_manager)
      
      expected_content = "This is the AI response."
      response_body = {
        message: {
          role:    "assistant",
          content: expected_content,
        },
        # Other fields Ollama might return
        model:             model,
        created_at:        "2023-10-26T18:30:00Z",
        done:              true,
        total_duration:    123456,
        load_duration:     123,
        prompt_eval_count: 10,
        eval_count:        50,
        eval_duration:     45678,
      }.to_json
      
      # Set up test client
      TestOllamaClient.reset
      TestOllamaClient.response = MockResponse.new(HTTP::Status::OK, response_body)
      
      # Action
      result = client.send_text(messages, model, api_url: api_url, tools: sample_tools_data)
      
      # Assertions
      result.should eq(expected_content)
      # Verify mocks were called
      TestOllamaClient.request_count.should eq(1)
      tool_manager.calls.should eq(1)
    end

    it "handles responses with tool calls correctly" do
      # Setup
      api_url = "http://mockhost:11434/api/chat"
      model = "test-model"
      messages = [{"role" => "user", "content" => "Hello"}]
      sample_tools_data = [] of SevenMillion::ToolData
      
      tool_manager = MockToolManager.new
      client = TestOllamaClient.new(tool_manager)
      
      expected_content = "Okay, I can do that." # Content might be simpler when tools are called
      # Simulate a response that includes tool calls
      tool_call_data = [{"id" => "call_123", "type" => "function", "function" => {"name" => "get_weather", "arguments" => "{\"location\": \"London\"}"}}]
      response_body = {
        message: {
          role:       "assistant",
          content:    expected_content, # Ollama might still provide content
          tool_calls: tool_call_data,   # Assuming this structure based on typical LLM APIs
        },
        model:      model,
        created_at: "2023-10-26T18:31:00Z",
        done:       true,
        # ... other fields
      }.to_json
      
      # Set up test client
      TestOllamaClient.reset
      TestOllamaClient.response = MockResponse.new(HTTP::Status::OK, response_body)
      
      # Set up tool manager to return tool calls
      parsed_response = JSON.parse(response_body)
      extracted_calls_result = parsed_response["message"].as_h["tool_calls"]
      tool_manager.return_value = extracted_calls_result
      
      # Action
      result = client.send_text(messages, model, api_url: api_url, tools: sample_tools_data)
      
      # Assertions
      result.should eq(expected_content) # Still expect content back
      TestOllamaClient.request_count.should eq(1)
      tool_manager.calls.should eq(1)
    end

    it "returns nil when http request fails" do
      # Setup
      api_url = "http://mockhost:11434/api/chat"
      model = "test-model"
      messages = [{"role" => "user", "content" => "Hello"}]
      
      tool_manager = MockToolManager.new
      client = TestOllamaClient.new(tool_manager)
      
      error_body = "Internal Server Error"
      TestOllamaClient.reset
      TestOllamaClient.response = MockResponse.new(HTTP::Status::INTERNAL_SERVER_ERROR, error_body)
      
      # Action
      result = client.send_text(messages, model, api_url: api_url)
      
      # Assertions
      result.should be_nil
      TestOllamaClient.request_count.should eq(1)
      tool_manager.calls.should eq(0) # Should not be called with error response
    end

    it "returns nil when JSON parsing fails" do
      # Setup
      api_url = "http://mockhost:11434/api/chat"
      model = "test-model"
      messages = [{"role" => "user", "content" => "Hello"}]
      
      tool_manager = MockToolManager.new
      client = TestOllamaClient.new(tool_manager)
      
      invalid_json_body = "This is not JSON {"
      TestOllamaClient.reset
      TestOllamaClient.response = MockResponse.new(HTTP::Status::OK, invalid_json_body)
      
      # Action
      result = client.send_text(messages, model, api_url: api_url)
      
      # Assertions
      result.should be_nil
      TestOllamaClient.request_count.should eq(1)
      tool_manager.calls.should eq(0) # Should not be called with invalid JSON
    end

    it "returns nil when network error occurs" do
      # Setup
      api_url = "http://mockhost:11434/api/chat"
      model = "test-model"
      messages = [{"role" => "user", "content" => "Hello"}]
      
      tool_manager = MockToolManager.new
      client = TestOllamaClient.new(tool_manager)
      
      # Set up test client to raise an exception
      TestOllamaClient.reset
      TestOllamaClient.should_raise = true
      
      # Action
      result = client.send_text(messages, model, api_url: api_url)
      
      # Assertions
      result.should be_nil
      TestOllamaClient.request_count.should eq(1) # Request still counted even though it raised
      tool_manager.calls.should eq(0) # Should not be called with network error
    end

    it "returns nil when 'message' key is missing in response" do
      # Setup
      api_url = "http://mockhost:11434/api/chat"
      model = "test-model"
      messages = [{"role" => "user", "content" => "Hello"}]
      
      tool_manager = MockToolManager.new
      client = TestOllamaClient.new(tool_manager)
      
      response_body = {
        # Missing 'message' key
        model:      model,
        created_at: "2023-10-26T18:32:00Z",
        done:       true,
      }.to_json
      
      TestOllamaClient.reset
      TestOllamaClient.response = MockResponse.new(HTTP::Status::OK, response_body)
      
      # Action
      result = client.send_text(messages, model, api_url: api_url)
      
      # Assertions
      result.should be_nil
      TestOllamaClient.request_count.should eq(1)
      tool_manager.calls.should eq(1) # Will be called but extraction will return nil
    end

    it "returns nil when 'content' key is missing in message" do
      # Setup
      api_url = "http://mockhost:11434/api/chat"
      model = "test-model"
      messages = [{"role" => "user", "content" => "Hello"}]
      
      tool_manager = MockToolManager.new
      client = TestOllamaClient.new(tool_manager)
      
      response_body = {
        message: {
          role: "assistant",
          # Missing 'content' key
        },
        model:      model,
        created_at: "2023-10-26T18:33:00Z",
        done:       true,
      }.to_json
      
      TestOllamaClient.reset
      TestOllamaClient.response = MockResponse.new(HTTP::Status::OK, response_body)
      
      # Action
      result = client.send_text(messages, model, api_url: api_url)
      
      # Assertions
      result.should be_nil
      TestOllamaClient.request_count.should eq(1)
      tool_manager.calls.should eq(1) # Will be called but no content found
    end

    it "returns nil when ToolManager raises ToolException during extraction" do
      # Setup
      api_url = "http://mockhost:11434/api/chat"
      model = "test-model"
      messages = [{"role" => "user", "content" => "Hello"}]
      
      tool_manager = MockToolManager.new
      tool_manager.should_raise = true # Set to raise exception
      client = TestOllamaClient.new(tool_manager)
      
      expected_content = "Some content" # Content exists but tool extraction fails
      response_body = {
        message: {role: "assistant", content: expected_content},
        model: model, done: true,
      }.to_json
      
      TestOllamaClient.reset
      TestOllamaClient.response = MockResponse.new(HTTP::Status::OK, response_body)
      
      # Action
      result = client.send_text(messages, model, api_url: api_url)
      
      # Assertions
      result.should be_nil # Exception should be caught, return nil
      TestOllamaClient.request_count.should eq(1)
      tool_manager.calls.should eq(1) # Will be called but will raise
    end

    it "sends request with custom options" do
      # Setup
      api_url = "http://mockhost:11434/api/chat"
      model = "test-model"
      messages = [{"role" => "user", "content" => "Hello"}]
      sample_tools_data = [] of SevenMillion::ToolData
      
      tool_manager = MockToolManager.new
      client = TestOllamaClient.new(tool_manager)
      
      custom_temp = 0.9
      custom_top_p = 0.5
      expected_content = "Response with custom options."
      response_body = {message: {content: expected_content}}.to_json
      
      TestOllamaClient.reset
      TestOllamaClient.response = MockResponse.new(HTTP::Status::OK, response_body)
      
      # Action
      result = client.send_text(messages, model, temperature: custom_temp, top_p: custom_top_p, api_url: api_url, tools: sample_tools_data)
      
      # Assertions
      result.should eq(expected_content)
      TestOllamaClient.request_count.should eq(1)
      
      # Check if the request body contained the custom options
      if request = TestOllamaClient.last_request
        body = request[2] # Request body is the third element
        body_json = JSON.parse(body)
        body_json["options"]["temperature"].as_f.should eq(custom_temp)
        body_json["options"]["top_p"].as_f.should eq(custom_top_p)
      else
        fail "No request recorded"
      end
    end
  end
end
