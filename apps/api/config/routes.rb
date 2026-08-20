Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "api/health", to: "health#show"

  namespace :api do
    resource :onboarding, only: :show, controller: "onboarding" do
      post :consent
      post :chat
      post :document
      patch :details
      post :complete
      delete :destroy
    end
    resources :appointment_slots, only: :index
    resource :booking, only: %i[show create destroy]
    get "admin/analytics", to: "admin/analytics#show"
  end
end
