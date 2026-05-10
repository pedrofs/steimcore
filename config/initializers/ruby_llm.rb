RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.openai_api_key || ENV["OPENAI_API_KEY"]
  config.anthropic_api_key = Rails.application.credentials.anthropic_api_key || ENV["ANTHROPIC_API_KEY"]
end
