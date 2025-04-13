# src/seven_million.cr
require "./seven_million/*"

module SevenMillion
  struct Config
    property model_name : String = "qwq:latest"
    property temperature : Float64 = 0.6
    property top_p : Float64 = 0.7
    property max_tokens : Int32 = 700
    property api_url : String = "http://localhost:11434/api/chat"
  end
end