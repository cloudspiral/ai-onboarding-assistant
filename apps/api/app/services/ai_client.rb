require "net/http"

class AiClient
  ENDPOINT = URI("https://api.openai.com/v1/responses")
  RETRYABLE_CODES = [ 408, 409, 429, 500, 502, 503, 504 ].freeze

  def initialize(
    api_key: ENV["OPENAI_API_KEY"],
    model: ENV.fetch("OPENAI_MODEL", "gpt-5.6-luna"),
    timeout_ms: ENV.fetch("OPENAI_TIMEOUT_MS", "2800").to_i,
    max_retries: ENV.fetch("OPENAI_MAX_RETRIES", "1").to_i,
    logger: Rails.logger
  )
    @api_key = api_key
    @model = model
    @timeout_ms = timeout_ms
    @max_retries = [ max_retries, 1 ].min
    @logger = logger
  end

  def structured(operation:, instructions:, input:, schema:)
    return failure(operation, "not_configured", false, 0, 0, false) if @api_key.blank?

    body = {
      model: @model,
      store: false,
      max_output_tokens: ENV.fetch("OPENAI_MAX_OUTPUT_TOKENS", "180").to_i,
      reasoning: { effort: ENV.fetch("OPENAI_REASONING_EFFORT", "none") },
      instructions: instructions,
      input: input,
      text: {
        verbosity: "low",
        format: {
          type: "json_schema",
          name: operation.to_s,
          strict: true,
          schema: schema
        }
      }
    }
    execute(operation, body) do |response|
      text = response.fetch("output").flat_map { |item| item.fetch("content", []) }
        .find { |item| item["type"] == "output_text" }&.fetch("text")
      raise ProviderPayloadError, "missing structured output" if text.blank?

      JSON.parse(text)
    end
  end

  def health
    structured(
      operation: "health_probe",
      instructions: "Return only the requested JSON. Do not include any user data.",
      input: "Dependency health probe.",
      schema: {
        type: "object",
        properties: { ok: { type: "boolean" } },
        required: [ "ok" ],
        additionalProperties: false
      }
    )
  end

  private

  class ProviderPayloadError < StandardError; end
  class ProviderHttpError < StandardError
    attr_reader :status
    def initialize(status)
      @status = status
      super("provider HTTP error")
    end
  end

  def execute(operation, body)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    attempts = 0
    timeout = false

    begin
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      remaining_ms = @timeout_ms - elapsed_ms
      raise Timeout::Error, "deadline exceeded" if remaining_ms <= 0

      response = request(body, remaining_ms)
      unless response.is_a?(Net::HTTPSuccess)
        raise ProviderHttpError, response.code.to_i
      end

      value = yield(JSON.parse(response.body))
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      metadata = metadata_for(operation, duration_ms, true, attempts, false, nil)
      emit(metadata)
      Result::Success.new(value:, metadata:)
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout => error
      timeout = true
      retry if retryable?(error, attempts, started) && (attempts += 1)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      failure(operation, "timeout", true, attempts, duration_ms, timeout)
    rescue ProviderHttpError => error
      retry if RETRYABLE_CODES.include?(error.status) && retryable?(error, attempts, started) && (attempts += 1)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      failure(operation, "provider_http_error", RETRYABLE_CODES.include?(error.status), attempts, duration_ms, timeout)
    rescue JSON::ParserError, KeyError, ProviderPayloadError
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      failure(operation, "invalid_provider_payload", false, attempts, duration_ms, timeout)
    rescue StandardError
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      failure(operation, "provider_unavailable", true, attempts, duration_ms, timeout)
    end
  end

  def request(body, remaining_ms)
    request = Net::HTTP::Post.new(ENDPOINT)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(body)
    seconds = [ remaining_ms / 1000.0, 0.05 ].max
    Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: seconds, read_timeout: seconds) do |http|
      http.request(request)
    end
  end

  def retryable?(_error, attempts, started)
    attempts < @max_retries && ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000) < @timeout_ms
  end

  def failure(operation, error_type, retryable, retry_count, duration_ms, timeout)
    metadata = metadata_for(operation, duration_ms, false, retry_count, timeout, error_type)
    emit(metadata)
    Result::Failure.new(code: error_type, message: "The assistant is temporarily unavailable.", retryable:, metadata:)
  end

  def metadata_for(operation, duration_ms, success, retry_count, timeout, error_type)
    {
      event: "ai_call",
      operation: operation.to_s,
      model: @model,
      duration_ms: duration_ms,
      success: success,
      retry_count: retry_count,
      timeout: timeout,
      error_type: error_type
    }.compact
  end

  def emit(metadata)
    @logger.info(JSON.generate(metadata))
  end
end
