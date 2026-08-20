require "rails_helper"

RSpec.describe AiClient do
  let(:endpoint) { "https://api.openai.com/v1/responses" }
  let(:schema) { { type: "object", properties: { ok: { type: "boolean" } }, required: [ "ok" ], additionalProperties: false } }

  it "returns a typed success and logs metadata without sensitive input or output" do
    io = StringIO.new
    logger = Logger.new(io)
    sensitive_input = "Avery Sample, DOB 1988-04-03, 12 Cedar Street"
    sensitive_output = "private provider response"
    stub_request(:post, endpoint).to_return(
      status: 200,
      body: JSON.generate(output: [ { content: [ { type: "output_text", text: JSON.generate(ok: true, note: sensitive_output) } ] } ]),
      headers: { "Content-Type" => "application/json" }
    )

    result = described_class.new(api_key: "test-key", logger:).structured(operation: "test_operation", instructions: "private instructions", input: sensitive_input, schema:)

    expect(result).to be_success
    expect(result.value).to include("ok" => true)
    expect(io.string).to include("ai_call", "test_operation", "duration_ms", "retry_count")
    expect(io.string).not_to include(sensitive_input, sensitive_output, "private instructions", "Avery", "Cedar")
  end

  it "returns a typed retryable failure after one timeout retry" do
    io = StringIO.new
    stub_request(:post, endpoint).to_timeout
    result = described_class.new(api_key: "test-key", timeout_ms: 2_800, max_retries: 1, logger: Logger.new(io)).structured(operation: "assessment_turn", instructions: "safe", input: "synthetic", schema:)

    expect(result).not_to be_success
    expect(result.code).to eq("timeout")
    expect(result.retryable).to be(true)
    expect(result.metadata).to include(retry_count: 1, timeout: true, error_type: "timeout")
    expect(a_request(:post, endpoint)).to have_been_made.twice
  end

  it "degrades gracefully when no API key is configured" do
    result = described_class.new(api_key: nil, logger: Logger.new(StringIO.new)).structured(operation: "assessment_turn", instructions: "safe", input: "synthetic", schema:)
    expect(result).not_to be_success
    expect(result.code).to eq("not_configured")
    expect(result.message).to match(/temporarily unavailable/i)
  end

  it "sanitizes provider HTTP failures and retries only retryable statuses" do
    io = StringIO.new
    stub_request(:post, endpoint).to_return(status: 503, body: "upstream secret detail")
    result = described_class.new(api_key: "test-key", logger: Logger.new(io)).structured(operation: "assessment_turn", instructions: "safe", input: "synthetic", schema:)
    expect(result).not_to be_success
    expect(result.code).to eq("provider_http_error")
    expect(result.metadata[:retry_count]).to eq(1)
    expect(io.string).not_to include("upstream secret detail")
  end

  it "rejects malformed provider payloads without logging their contents" do
    io = StringIO.new
    stub_request(:post, endpoint).to_return(status: 200, body: JSON.generate(output: []))
    result = described_class.new(api_key: "test-key", logger: Logger.new(io)).structured(operation: "assessment_turn", instructions: "safe", input: "synthetic", schema:)
    expect(result).not_to be_success
    expect(result.code).to eq("invalid_provider_payload")
    expect(io.string).to include("invalid_provider_payload")
  end
end
