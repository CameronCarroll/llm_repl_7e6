# src/seven_million/context_manager.cr
module SevenMillion
    class ContextManager
      @messages : Array(Hash(String, String))
  
      def initialize
        @messages = [] of Hash(String, String)
      end
  
      def add_message(role : String, content : String)
        @messages << {"role" => role, "content" => content}
      end
  
      def add_user_message(content : String)
        add_message("user", content)
      end
  
      def add_assistant_message(content : String)
        add_message("assistant", content)
      end
  
      def get_messages
        @messages.dup # Return a copy to prevent external modification
      end
  
      def clear
        @messages.clear
        puts " Context cleared. ".colorize(:yellow).mode(:italic)
      end
    end
  end