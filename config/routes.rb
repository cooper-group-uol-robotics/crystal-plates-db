Rails.application.routes.draw do
  resources :stock_solutions do
    collection do
      get :search
    end
  end

  resources :points_of_interest do
    collection do
      get :by_type
      get :recent
    end
  end

  resources :chemicals do
    collection do
      post :import_from_sciformation
    end
  end
  resources :wells do
    member do
      get :images
      get :content_form
      patch :update_content
      delete "content/:content_id", to: "wells#remove_content", as: "remove_content"
    end
    resources :images, except: [ :index ] do
      resources :point_of_interests, except: [ :new, :edit ]
    end
    resources :well_contents do
      collection do
        delete :destroy_all
      end
    end
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
          resources :images, only: [ :index, :show, :create, :update, :destroy ] do
            resources :points_of_interest, only: [ :index, :show, :create, :update, :destroy ]
          end
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
        resources :images, only: [ :index, :show, :create, :update, :destroy ] do
          resources :points_of_interest, only: [ :index, :show, :create, :update, :destroy ]
        end
      end

      resources :points_of_interest do
        collection do
          get :by_type
          get :recent
          get :crystals
          get :particles
        end
      end

      # Utility endpoints
      get :health, to: "health#show"
      get :stats, to: "stats#show"
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
