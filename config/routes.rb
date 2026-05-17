Rails.application.routes.draw do
  resource :prototype, only: :show
  resource :session, only: [ :new, :create, :destroy ]
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]
  resources :invitations, only: [ :new, :create, :destroy ] do
    resource :delivery, only: :create, module: :invitations
  end
  resources :invitation_acceptances, param: :token, only: [ :edit, :update ]
  resource :organization, only: [ :show, :edit, :update ]
  resources :students, only: [ :index, :new, :create, :show, :edit, :update ] do
    resources :periodizations, only: [ :new, :show ], module: :students do
      resources :versions, only: [], module: :periodizations do
        resource :print_confirmation, only: :create, module: :versions
      end
    end
    resource :periodization, only: [], module: :students do
      resource :printable, only: :show, module: :periodizations
    end
    resource :agent_chat, only: :show, module: :students do
      resources :messages, only: :create, module: :agent_chats
    end
    resource :restoration, only: :create, module: :students
  end

  resources :periodization_versions, only: [ :show, :destroy ] do
    resource :promotion, only: :create, module: :periodization_versions
    resources :workouts, only: :update, module: :periodization_versions
  end

  resources :periodizations, only: [] do
    resource :inline_edit, only: :create, module: :periodizations
  end

  resources :training_sessions, only: [ :index, :create ] do
    resources :block_completions, only: [ :create, :destroy ], module: :training_sessions
    resource  :completion,        only: [ :create, :destroy ], module: :training_sessions
    resource  :workout_swap,      only: :create,               module: :training_sessions
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end
  root "home#index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
