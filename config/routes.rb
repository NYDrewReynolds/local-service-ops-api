Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      post "auth/logout", to: "auth#logout"

      post "demo/populate", to: "demo#populate"
      post "demo/reset", to: "demo#reset"

      resources :leads, only: %i[index create show update] do
        resources :agent_runs, only: %i[create]
        resources :quotes, only: %i[index]
        get "action_logs", to: "action_logs#index"
        get "timeline", to: "action_logs#timeline"
      end

      resources :agent_runs, only: %i[show]
      resources :quotes, only: %i[index show]
      resources :jobs, only: %i[index show update]
      resources :assignments, only: %i[index show update]
      resources :notifications, only: %i[index show]
      resources :subcontractors, only: %i[index show]
      resources :pricing_rules, only: %i[index]
    end
  end
end
