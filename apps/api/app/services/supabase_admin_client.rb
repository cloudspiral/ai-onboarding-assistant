require "net/http"

class SupabaseAdminClient
  def initialize(url: ENV["SUPABASE_URL"], service_key: ENV["SUPABASE_SERVICE_ROLE_KEY"])
    @url = url&.delete_suffix("/")
    @service_key = service_key
  end

  def delete_user(user_id)
    return Result::Success.new(value: true, metadata: { skipped: true }) if !Rails.env.production? && @service_key.blank?
    return Result::Failure.new(code: "auth_not_configured", message: "Account deletion is temporarily unavailable.", retryable: true, metadata: {}) if @url.blank? || @service_key.blank?

    uri = URI("#{@url}/auth/v1/admin/users/#{CGI.escapeURIComponent(user_id)}")
    request = Net::HTTP::Delete.new(uri)
    request["Authorization"] = "Bearer #{@service_key}"
    request["apikey"] = @service_key
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 4) { |http| http.request(request) }
    return Result::Success.new(value: true, metadata: {}) if response.is_a?(Net::HTTPSuccess)

    Result::Failure.new(code: "auth_delete_failed", message: "Account deletion is temporarily unavailable.", retryable: true, metadata: {})
  rescue StandardError
    Result::Failure.new(code: "auth_delete_failed", message: "Account deletion is temporarily unavailable.", retryable: true, metadata: {})
  end
end
