Rails.application.routes.draw do
  constraints(host: /(\A|\.)simaobelchior\.net\z/) do
    get "(*path)", to: redirect { |_params, request| "https://simaobelchior.com#{request.fullpath}" }
  end

  # Authentication routes
  get "login" => "sessions#new", as: :login
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy", as: :logout

  # Blog routes
  get "blog" => "articles#index", as: :blog
  get "blog/feed" => "articles#feed", as: :blog_feed, defaults: { format: :rss }
  get "blog/:slug" => "articles#show", as: :article

  # Admin namespace (to be used for blog management)
  namespace :admin do
    root to: "dashboard#index"
    get "visits" => "visits#site", as: :site_visits
    get "visits/games" => "visits#games", as: :game_visits
    resources :articles do
      post :toggle_publish, on: :member
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "about" => "home#about"
  get "games" => "home#games"
  # The games' static pages call this to count a visit, see GameVisitsController
  post "games/opened" => "game_visits#create", as: :game_visits

  # Defines the root path route ("/")
  root "home#index"
end
