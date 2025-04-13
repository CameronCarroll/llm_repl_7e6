# spec/seven_million/context_manager_spec.cr
require "./spec_helper"

describe SevenMillion::ContextManager do
  describe "#initialize" do
    it "initializes with an empty messages array" do
      # Setup
      context_manager = SevenMillion::ContextManager.new

      # Assertions
      context_manager.get_messages.should be_empty
      # Check internal state
      context_manager.@messages.should be_empty
    end
  end

  describe "#add_message" do
    it "adds a message with the specified role and content" do
      # Setup
      context_manager = SevenMillion::ContextManager.new
      role = "system"
      content = "You are a helpful assistant."
      expected_message = {"role" => role, "content" => content}

      # Action
      context_manager.add_message(role, content)

      # Assertions
      messages = context_manager.get_messages
      messages.size.should eq(1)
      messages[0].should eq(expected_message)

      # Check internal state
      context_manager.@messages.size.should eq(1)
      context_manager.@messages[0].should eq(expected_message)
    end
  end

  describe "#add_user_message" do
    it "adds a message with the role 'user'" do
      # Setup
      context_manager = SevenMillion::ContextManager.new
      content = "Hello, assistant!"
      expected_message = {"role" => "user", "content" => content}

      # Action
      context_manager.add_user_message(content)

      # Assertions
      messages = context_manager.get_messages
      messages.size.should eq(1)
      messages[0].should eq(expected_message)

      # Check internal state
      context_manager.@messages.size.should eq(1)
      context_manager.@messages[0].should eq(expected_message)
    end
  end

  describe "#add_assistant_message" do
    it "adds a message with the role 'assistant'" do
      # Setup
      context_manager = SevenMillion::ContextManager.new
      content = "Hello! How can I help you today?"
      expected_message = {"role" => "assistant", "content" => content}

      # Action
      context_manager.add_assistant_message(content)

      # Assertions
      messages = context_manager.get_messages
      messages.size.should eq(1)
      messages[0].should eq(expected_message)

      # Check internal state
      context_manager.@messages.size.should eq(1)
      context_manager.@messages[0].should eq(expected_message)
    end
  end

  describe "adding multiple messages" do
    it "maintains the order of added messages" do
      # Setup
      context_manager = SevenMillion::ContextManager.new
      user_content = "What is the weather like?"
      assistant_content = "The weather is sunny."
      expected_user_message = {"role" => "user", "content" => user_content}
      expected_assistant_message = {"role" => "assistant", "content" => assistant_content}

      # Action
      context_manager.add_user_message(user_content)
      context_manager.add_assistant_message(assistant_content)

      # Assertions
      messages = context_manager.get_messages
      messages.size.should eq(2)
      messages[0].should eq(expected_user_message)
      messages[1].should eq(expected_assistant_message)

      # Check internal state
      context_manager.@messages.size.should eq(2)
      context_manager.@messages.should eq([expected_user_message, expected_assistant_message])
    end
  end

  describe "#get_messages" do
    it "returns a copy of the messages array" do
      # Setup
      context_manager = SevenMillion::ContextManager.new
      content = "Initial message"
      expected_message = {"role" => "user", "content" => content}
      context_manager.add_user_message(content)

      # Action
      retrieved_messages = context_manager.get_messages
      # Modify the retrieved copy
      retrieved_messages << {"role" => "assistant", "content" => "Modified message"}

      # Assertions
      # The original internal array should be unchanged
      internal_messages = context_manager.@messages
      internal_messages.size.should eq(1)
      internal_messages[0].should eq(expected_message)

      # Calling get_messages again should return the original, unmodified array (as a copy)
      fresh_retrieved_messages = context_manager.get_messages
      fresh_retrieved_messages.size.should eq(1)
      fresh_retrieved_messages[0].should eq(expected_message)
    end
  end

  describe "#clear" do
    it "removes all messages from the context" do
      # Setup
      context_manager = SevenMillion::ContextManager.new
      context_manager.add_user_message("Message 1")
      context_manager.add_assistant_message("Message 2")

      # Pre-check (optional but good practice)
      context_manager.get_messages.size.should eq(2)
      context_manager.@messages.size.should eq(2)

      # Action
      # Note: We aren't testing the `puts` output here, just the state change.
      context_manager.clear

      # Assertions
      context_manager.get_messages.should be_empty

      # Check internal state
      context_manager.@messages.should be_empty
    end
  end
end