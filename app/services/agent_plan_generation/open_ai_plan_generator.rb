require "net/http"

module AgentPlanGeneration
  class OpenAiPlanGenerator
    SCHEMA_VERSION = "v1"
    DEFAULT_MODEL = "gpt-4o-mini"

    def self.call(input_payload:, schema_reference:)
      new(input_payload, schema_reference).call
    end

    def self.model_name
      Rails.application.credentials.open_ai&.model || DEFAULT_MODEL
    end

    def initialize(input_payload, schema_reference)
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
        You are a planning engine. Output ONLY valid JSON with no markdown or explanation.
        The JSON MUST match the exact schema and required keys. Never include additional properties.
        Use types exactly as specified. Use ISO8601 dates (YYYY-MM-DD) and time strings (HH:MM) in America/New_York time.
        Confidence must be a realistic probability derived from the input (do not use fixed placeholders).
        schema_version=#{SCHEMA_VERSION}
      PROMPT
    end

    def user_prompt
      <<~PROMPT
        Create a plan for the lead using the input payload. Follow these rules:
        - Choose service_code from allowed_services codes.
        - urgency_level must be one of: low, medium, high.
        - quote must include line_items and total_cents.
        - schedule date/window required.
        - subcontractor_id can be null.
        - customer_message required.
        - confidence required (0.0 to 1.0).
        - assumptions must be an array of strings.
        - Ensure the quote total is within pricing_rules min/max for the selected service.
        - If no subcontractor is eligible, set subcontractor_id to null.
        - Confidence must be based on data quality and constraints (avoid fixed values like 0.72).

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
        temperature: 0.3,
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
