module Api
  class OnboardingController < ApplicationController
    def show
      render json: { onboarding: onboarding_session.public_payload }
    end

    def consent
      granted = ActiveModel::Type::Boolean.new.cast(params.require(:granted))
      event_type = granted ? "granted" : "revoked"
      onboarding_session.consent_events.create!(event_type:)
      onboarding_session.document_detail&.destroy! unless granted
      AnalyticsTracker.record(session: onboarding_session, event_name: "consent_#{event_type}", step: "details")
      render json: { consent: event_type }
    end

    def chat
      result = ChatOrchestrator.new.call(
        message: params.require(:message).to_s.first(2_000),
        field: params[:field].to_s.presence,
        session: onboarding_session,
        calm_mode_opt_in: ActiveModel::Type::Boolean.new.cast(params[:calm_mode_opt_in])
      )
      return render_failure(result) unless result.success?

      value = result.value
      AnalyticsTracker.record(
        session: onboarding_session,
        event_name: "chat_turn",
        step: "chat",
        properties: { "intent" => value["intent"] || "express_distress", "outcome" => value[:level] || value["level"] }
      )
      render json: { turn: value }
    end

    def document
      unless consent_active?
        return render json: { error: { code: "consent_required", message: "Agree to document processing before uploading a photo." } }, status: :unprocessable_content
      end

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = OcrService.new.extract(params[:document])
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      unless result.success?
        AnalyticsTracker.record(session: onboarding_session, event_name: "ocr_completed", step: "details", duration_ms:, properties: { "outcome" => "failed" })
        return render_failure(result, status: :unprocessable_content)
      end

      fields = result.value
      sources = fields.transform_values { |value| value.present? ? "ocr" : "missing" }
      detail = onboarding_session.document_detail || onboarding_session.build_document_detail
      detail.assign_attributes(
        full_name: fields["full_name"],
        date_of_birth: fields["date_of_birth"],
        address: fields["address"],
        field_sources: sources,
        confirmed_at: nil
      )
      detail.save!
      AnalyticsTracker.record(session: onboarding_session, event_name: "ocr_completed", step: "details", duration_ms:, properties: { "outcome" => "success" })
      render json: { fields:, field_sources: sources, raw_document_retained: false, duration_ms: }
    end

    def details
      detail = onboarding_session.document_detail || onboarding_session.build_document_detail
      detail.assign_attributes(detail_params.merge(confirmed_at: Time.current))
      detail.field_sources = params[:field_sources].to_unsafe_h.slice("full_name", "date_of_birth", "address") if params[:field_sources].respond_to?(:to_unsafe_h)
      if detail.save
        onboarding_session.update!(step: "booking")
        AnalyticsTracker.record(session: onboarding_session, event_name: "step_completed", step: "details")
        render json: { details: detail.public_payload, source_photo_deleted: true }
      else
        render json: { error: { code: "invalid_details", message: "Complete all three fields before continuing.", fields: detail.errors.to_hash } }, status: :unprocessable_content
      end
    end

    def complete
      return render json: { error: { code: "booking_required", message: "Book a visit before finishing." } }, status: :unprocessable_content unless onboarding_session.booking

      onboarding_session.update!(step: "done", status: "completed")
      AnalyticsTracker.record(session: onboarding_session, event_name: "onboarding_completed", step: "done")
      render json: { onboarding: onboarding_session.public_payload }
    end

    def destroy
      auth_result = SupabaseAdminClient.new.delete_user(Current.user_id)
      return render_failure(auth_result) unless auth_result.success?

      digest = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, Current.user_id)
      OnboardingSession.transaction do
        AnalyticsEvent.where(anonymous_session_id: Current.user_id).delete_all
        onboarding_session.destroy!
        DeletionAudit.create!(subject_digest: digest)
      end
      render json: { deleted: true, scope: "all_onboarding_data", audit_retains_pii: false }
    end

    private

    def consent_active?
      onboarding_session.consent_events.order(created_at: :desc).first&.event_type == "granted"
    end

    def detail_params
      params.require(:details).permit(:full_name, :date_of_birth, :address)
    end
  end
end
