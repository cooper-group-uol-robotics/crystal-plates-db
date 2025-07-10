Rails.application.routes.draw do
  resources :wells do
    member do
      get :images
    end
  end
  resources :plates

  resources :locations do
    collection do
      get :grid
    end
  end

  # Pages routes
  get "pages/home", to: "pages#home"

  root "plates#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  namespace :api do
    namespace :v1 do
      resources :plates, param: :id, only: [ :index, :show, :create ]
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
