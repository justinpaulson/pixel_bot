Rails.application.routes.draw do
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
