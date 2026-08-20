class HealthController < ActionController::API
  def show
    checks = {
      app: { status: "ok" },
      database: database_check,
      ocr: ocr_check,
      llm: llm_check
    }
    status = checks.values.all? { |check| check[:status] == "ok" } ? :ok : :service_unavailable
    render json: { status: status == :ok ? "ok" : "degraded", checks:, timestamp: Time.current.iso8601 }, status:
  end

  private

  def database_check
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "ok" }
  rescue StandardError
    { status: "error", error_type: "database_unavailable" }
  end

  def ocr_check
    version = OcrService.new.engine_version
    version == "unavailable" ? { status: "error", error_type: "ocr_unavailable" } : { status: "ok", version: }
  end

  def llm_check
    result = AiClient.new.health
    result.success? ? { status: "ok", model: ENV.fetch("OPENAI_MODEL", "gpt-5.6-luna") } : { status: "error", error_type: result.code }
  end
end
