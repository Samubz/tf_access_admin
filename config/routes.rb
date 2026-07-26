require "sidekiq/web"

Rails.application.routes.draw do
  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  authenticate :user, lambda { |u| u.super_admin? } do
    mount Sidekiq::Web => "/sidekiq"
    mount Flipper::UI.app(Flipper) => "/flipper"
  end
  # Público / sin tenant (dominio base o sin subdominio de organización)
  get "home", to: "home#index", as: :home

  # Solo rutas Devise necesarias: login (Inertia), recuperación de contraseña, confirmación por email.
  # No exponer registrations (sign up), unlocks ni otros módulos hasta implementarlos.
  devise_for :users,
             only: %i[sessions passwords confirmations],
             controllers: {
               sessions: "users/sessions",
               passwords: "users/passwords",
               confirmations: "users/confirmations"
             }

  namespace :api do
    namespace :v1 do
      namespace :auth do
        post :login, to: "sessions#create"
        delete :logout, to: "sessions#destroy"
      end

      # namespace :public do
      #   resources :organizations, only: [:index]
      # end

      namespace :private do
        # Resident private API — unit-scoped, authenticated, separate from admin/Inertia flows.
        # POST /api/v1/private/units/:unit_id/visits creates an authorized visit.
        # A pending-visit flow requires a separate contract.
        resources :units, only: [] do
          resources :visits, only: [ :create ], module: :units
        end

        # Singular resource: a User has at most one registered device token.
        resource :device_token, only: %i[create destroy]
      end
    end
  end

  get "admin/home/index"
  # Onboarding invitation acceptance by single-use token (holder-facing).
  get "onboarding/accept/:token", to: "onboarding_acceptances#show", as: :onboarding_acceptance
  post "onboarding/accept/:token", to: "onboarding_acceptances#create"

  namespace :admin do
    resources :users, only: [ :index, :new, :create, :edit, :update, :destroy ]
    resources :people, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
      member do
        post :invite
      end
    end
    resources :onboarding_requests, only: [] do
      member do
        post :revoke
        post :resolve_conflict
      end
    end
    namespace :people do
      resources :bulk_imports, only: %i[create update] do
        member do
          post :validate
          post :confirm
          get :rows
          get :status
          get :report
          post :trigger_invitations
        end
      end
    end
    resources :profile, only: [ :edit, :update ]
    resources :organizations, only: [ :index, :show, :edit, :update, :new, :create, :destroy ]
    resources :residential_properties, only: [ :index, :new, :create, :show ] do
      member do
        post :archive
      end
    resources :units, only: [ :index, :show, :update ], module: :residential_properties do
        member do
          post :restore
        end
        resources :ownerships, only: [ :create, :update, :destroy ], controller: "unit_ownerships"
        resources :occupancies, only: [ :create, :update, :destroy ], controller: "unit_occupancies" do
          collection do
            get :active_elsewhere
          end
        end
      end
      resources :bulk_imports, only: %i[create update], module: :residential_properties do
        member do
          post :validate
          post :confirm
          get :rows
          get :status
          get :report
        end
      end
    end
    namespace :property_setup do
      get  "wizard/new",                to: "wizard#new",            as: :new_wizard
      post "wizard",                    to: "wizard#create",         as: :create_wizard
      get  "wizard/:id",                to: "wizard#show",           as: :wizard
      post "wizard/:id/advance",        to: "wizard#advance",        as: :advance_wizard
      post "wizard/:id/back",           to: "wizard#back",           as: :back_wizard
      post "wizard/:id/cancel",         to: "wizard#cancel",         as: :cancel_wizard
      post "wizard/:id/confirm",        to: "wizard#confirm",        as: :confirm_wizard
      post "wizard/:id/complete",       to: "wizard#complete",       as: :complete_wizard
      post "wizard/:id/create_section", to: "wizard#create_section", as: :create_section_wizard
      post   "wizard/:id/sections",             to: "wizard#create_sections",  as: :create_sections_wizard
      patch  "wizard/:id/sections/:section_id", to: "wizard#update_section",    as: :update_section_wizard
      patch  "wizard/:id/sections/:section_id/move", to: "wizard#move_section", as: :move_section_wizard
      delete "wizard/:id/sections/:section_id", to: "wizard#destroy_section",   as: :destroy_section_wizard
      post "wizard/:id/create_unit",    to: "wizard#create_unit",    as: :create_unit_wizard
      post   "wizard/:id/units",           to: "wizard#create_units",  as: :create_units_wizard
      patch  "wizard/:id/units/:unit_id",   to: "wizard#update_unit",   as: :update_unit_wizard
      delete "wizard/:id/units/:unit_id",   to: "wizard#destroy_unit",  as: :destroy_unit_wizard
      get  "wizard/:id/structure_preview", to: "wizard#structure_preview", as: :structure_preview_wizard
      get  "wizard/:id/units_preview",  to: "wizard#units_preview",  as: :units_preview_wizard
    end
    resources :property_sections, only: [ :index, :edit ]
    resources :units, only: [ :index ]
    namespace :operational_roles do
      resources :assignments, only: [ :index, :create, :destroy ]
    end
    resources :operational_roles, only: [ :index, :show ], param: :role

    resources :visits, only: %i[index show new create edit update] do
      collection do
        get :form_properties
        get :form_units
        get :initial_status_preview
      end
      member do
        post :authorize_visit, as: :authorize
        delete :cancel
        post :resend_notification
      end
      resources :check_ins, only: %i[create], module: :visits
      resources :check_outs, only: %i[create], module: :visits
    end

    match "*path", to: "errors#not_found", via: :all
  end

  namespace :concierge do
    resources :visits, only: %i[index show] do
      member do
        post :check_in
        post :check_out
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  match "*path", to: "errors#not_found", via: :all,
  constraints: lambda { |req|
    !req.path.start_with?("/rails/active_storage")
  }
  # Defines the root path route ("/")
  root "admin/home#index"
end
