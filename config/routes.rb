Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "config", to: "config#show"
      resource :session, only: %i[create destroy]
      resources :games, only: %i[create] do
        member do
          get :state
          post :join
          post :start
          post :advance
        end
      end
      resources :rounds, only: [] do
        member do
          post :answer
          post :skip
          post :retry_drawing
          get :drawing
        end
      end
    end
  end
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  get "up" => "rails/health#show", as: :rails_health_check
  root "games#index"
  resources :games, only: %i[create show] do
    member do
      post :join
      post :start
      post :advance
      get :state
    end
  end
  resources :rounds, only: [] do
    member do
      post :answer
      post :skip
      post :retry_drawing
      get :drawing
    end
  end
end
