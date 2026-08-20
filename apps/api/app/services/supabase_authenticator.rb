require "net/http"

class SupabaseAuthenticator
  CACHE_TTL = 10.minutes

  def initialize(url: ENV["SUPABASE_URL"], audience: ENV.fetch("SUPABASE_JWT_AUDIENCE", "authenticated"))
    @url = url&.delete_suffix("/")
    @audience = audience
  end

  def authenticate(token)
    return development_identity if development_mode?
    return nil if token.blank? || @url.blank?

    header = JWT.decode(token, nil, false).last
    key = jwks.find { |jwk| jwk["kid"] == header["kid"] }
    return nil unless key

    payload, = JWT.decode(
      token,
      JWT::JWK.import(key).public_key,
      true,
      algorithms: [ header.fetch("alg") ],
      aud: @audience,
      verify_aud: true,
      iss: "#{@url}/auth/v1",
      verify_iss: true
    )
    { user_id: payload.fetch("sub"), role: payload.dig("app_metadata", "role") || "user" }
  rescue JWT::DecodeError, KeyError, JSON::ParserError, SocketError
    nil
  end

  private

  def development_mode?
    !Rails.env.production? && ENV["AUTH_MODE"] == "development"
  end

  def development_identity
    user_id = RequestStoreIdentity.user_id
    return nil if user_id.blank?

    { user_id:, role: RequestStoreIdentity.role || "user" }
  end

  def jwks
    cached = Rails.cache.read("supabase_jwks")
    return cached if cached

    response = Net::HTTP.get_response(URI("#{@url}/auth/v1/.well-known/jwks.json"))
    return [] unless response.is_a?(Net::HTTPSuccess)

    keys = JSON.parse(response.body).fetch("keys")
    Rails.cache.write("supabase_jwks", keys, expires_in: CACHE_TTL)
    keys
  end
end
