Rails.application.routes.draw do
  resource :prototype, only: :show
  resource :session, only: [ :new, :create, :destroy ]
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]
  resource :organization, only: [ :show, :edit, :update ]
  resource :inbox, only: :show
  resources :students, only: [ :index, :new, :create, :show, :edit, :update ] do
    resources :voice_recordings, only: [ :new, :create, :show ], module: :students do
      resource :transcription, only: :create, module: :voice_recordings
      resource :anamnesis_commit, only: :create, module: :voice_recordings
      resource :retry, only: :create, module: :voice_recordings
      resource :dismissal, only: :create, module: :voice_recordings
    end
    resources :periodizations, only: [ :new, :show ], module: :students
    resource :periodization, only: [], module: :students do
      resource :printable, only: :show, module: :periodizations
    end
    resource :restoration, only: :create, module: :students
  end

  resources :periodization_versions, only: [ :show, :destroy ] do
    resource :promotion, only: :create, module: :periodization_versions
    resource :edit, only: :create, module: :periodization_versions
    resources :workouts, only: :update, module: :periodization_versions do
      resource :edit, only: :create, module: :workouts
    end
  end

  resources :periodizations, only: [] do
    resource :edit, only: :create, module: :periodizations
    resource :inline_edit, only: :create, module: :periodizations
  end

  resources :training_sessions, only: [ :index, :create ] do
    resources :block_completions, only: [ :create, :destroy ], module: :training_sessions
    resource  :completion,        only: [ :create, :destroy ], module: :training_sessions
    resource  :workout_swap,      only: :create,               module: :training_sessions
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
