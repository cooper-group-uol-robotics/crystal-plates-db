Rails.application.routes.draw do
  resources :stock_solutions
  resources :chemicals do
    collection do
      post :import_from_sciformation
    end
  end
  resources :wells do
    member do
      get :images
    end
    resources :images, except: [ :index ]
  end
  resources :plates do
    collection do
      get :deleted
    end
    member do
      patch :restore
      delete :permanent_delete
    end
  end

  resources :locations do
    collection do
      get :grid
      post :initialise_carousel
    end
  end

  # Pages routes
  get "pages/home", to: "pages#home"

  root "plates#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.

  # API Routes
  namespace :api do
    namespace :v1 do
      resources :stock_solutions
      resources :chemicals, only: [] do
        collection do
          get :search
        end
      end
      resources :plates, param: :barcode do
        member do
          post :move_to_location
          get :location_history
        end
        resources :wells, only: [ :index, :show, :create, :update, :destroy ] do
          resources :images, only: [ :index, :show, :create, :update, :destroy ]
        end
      end

      resources :locations do
        collection do
          get :grid
          get :carousel
          get :special
        end
        member do
          get :current_plates
          get :history
        end
      end

      resources :wells, only: [ :index, :show, :create, :update, :destroy ] do
        resources :images, only: [ :index, :show, :create, :update, :destroy ]
      end

      # Utility endpoints
      get :health, to: "health#show"
      get :stats, to: "stats#show"
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
