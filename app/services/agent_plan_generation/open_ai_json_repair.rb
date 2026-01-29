require "net/http"

module AgentPlanGeneration
  class OpenAiJsonRepair
    DEFAULT_MODEL = OpenAiPlanGenerator::DEFAULT_MODEL

    def self.call(invalid_json:, validation_errors:, input_payload:, schema_reference:)
      new(invalid_json, validation_errors, input_payload, schema_reference).call
    end

    def self.model_name
      Rails.application.credentials.open_ai&.model || DEFAULT_MODEL
    end

    def initialize(invalid_json, validation_errors, input_payload, schema_reference)
      @invalid_json = invalid_json
      @validation_errors = validation_errors
      @input_payload = input_payload
      @schema_reference = schema_reference
    end

    def call
      return { error: "OpenAI API key missing." } if api_key.to_s.strip.empty?

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = post_chat_completion(build_messages)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      content = response.dig("choices", 0, "message", "content").to_s
      plan = JSON.parse(content)

      {
        plan: plan,
        raw_json: content,
        model: model_name,
        duration_ms: duration_ms
      }
    rescue JSON::ParserError => e
      {
        error: "OpenAI returned invalid JSON: #{e.message}",
        raw_json: defined?(content) ? content : nil,
        model: model_name
      }
    rescue StandardError => e
      { error: e.message, model: model_name }
    end

    private

    def api_key
      Rails.application.credentials.open_ai&.api_key
    end

    def model_name
      self.class.model_name
    end

    def build_messages
      [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]
    end

    def system_prompt
      <<~PROMPT
        You are a JSON repair engine. Output ONLY valid JSON with no markdown or explanation.
        The JSON MUST match the exact schema and required keys. Never include additional properties.
        Use types exactly as specified. Use ISO8601 dates (YYYY-MM-DD) and time strings (HH:MM) in America/New_York time.
      PROMPT
    end

    def user_prompt
      <<~PROMPT
        Fix the JSON to satisfy the schema. Use the validation errors to correct issues.
        Return ONLY corrected JSON.

        Validation errors:
        #{Array(@validation_errors).join("\n")}

        Invalid JSON:
        #{@invalid_json}

        Input payload:
        #{JSON.pretty_generate(@input_payload)}

        Schema reference:
        #{JSON.pretty_generate(@schema_reference)}
      PROMPT
    end

    def post_chat_completion(messages)
      uri = URI("https://api.openai.com/v1/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 20

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        model: model_name,
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: messages
      )

      response = http.request(request)
      body = response.body.to_s
      parsed = JSON.parse(body)

      unless response.is_a?(Net::HTTPSuccess)
        raise "OpenAI request failed with status #{response.code}: #{parsed["error"]&.fetch("message", nil) || body}"
      end

      parsed
    end
  end
end
