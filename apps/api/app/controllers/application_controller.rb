class ApplicationController < ActionController::API
  before_action :authenticate!

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: { code: "not_found", message: "That record was not found." } }, status: :not_found
  end

  private

  def authenticate!
    RequestStoreIdentity.user_id = request.headers["X-Demo-User-Id"]
    RequestStoreIdentity.role = request.headers["X-Demo-Role"]
    token = request.authorization.to_s.delete_prefix("Bearer ").presence
    identity = SupabaseAuthenticator.new.authenticate(token)
    unless identity
      render json: { error: { code: "unauthorized", message: "Sign in to continue." } }, status: :unauthorized
      return
    end

    Current.user_id = identity.fetch(:user_id)
    Current.role = identity.fetch(:role)
  end

  def onboarding_session
    @onboarding_session ||= OnboardingSession.find_or_create_by!(user_id: Current.user_id)
  end

  def render_failure(result, status: :service_unavailable)
    render json: {
      error: {
        code: result.code,
        message: result.message,
        retryable: result.retryable
      }
    }, status:
  end
end
