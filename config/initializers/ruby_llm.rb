RubyLLM.configure do |config|
  # Provider keys. In test we fall back to placeholders so that AR models
  # which resolve a provider on save (Agent::Chat) work without real keys.
  config.openai_api_key = Rails.application.credentials.openai_api_key ||
                          ENV["OPENAI_API_KEY"] ||
                          (Rails.env.test? ? "test-openai-key" : nil)
  config.anthropic_api_key = Rails.application.credentials.anthropic_api_key ||
                             ENV["ANTHROPIC_API_KEY"] ||
                             (Rails.env.test? ? "test-anthropic-key" : nil)

  # Opt into the new acts_as_* API (configurable association names, model
  # registry as a real model). Required for the Agent::* namespace under
  # app/models/agent — without it, the gem falls back to its legacy
  # signature with `acts_as_chat(message_class:, tool_call_class:)` only.
  config.use_new_acts_as = true

  # Our Agent::Model is the model registry for the new acts_as_* API.
  config.model_registry_class = "Agent::Model"
end
