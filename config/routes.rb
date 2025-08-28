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
    collection do
      post :bulk_add_content
    end
    resources :images, except: [ :index ] do
      resources :point_of_interests, except: [ :new, :edit ]
    end
    resources :pxrd_patterns
    resources :well_contents do
      collection do
        delete :destroy_all
      end
    end
  end

  # Standalone PXRD pattern routes for AJAX calls
  resources :pxrd_patterns, only: [] do
    member do
      get :plot
    end
  end
  resources :plates do
    collection do
      get :deleted
    end
    member do
      patch :restore
      delete :permanent_delete
      post :bulk_upload_contents
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
  get "api/docs", to: "pages#api_docs"

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
          post :unassign_location
          get :location_history
          get :points_of_interest
        end
        resources :wells, only: [ :index, :show, :create, :update, :destroy ] do
          resources :images, only: [ :index, :show, :create, :update, :destroy ] do
            resources :points_of_interest, only: [ :index, :show, :create, :update, :destroy ]
          end
        end
      end

      resources :locations do
        collection do
          get :carousel
          get :special
        end
        member do
          get :current_plates
          get :history
          post :unassign_all_plates
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
          get "/", to: "points_of_interest#index_standalone"
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
