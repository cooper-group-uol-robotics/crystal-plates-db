Rails.application.routes.draw do
  # Settings
  get "/settings", to: "settings#index"
  patch "/settings", to: "settings#update"
  post "/settings/test_connection", to: "settings#test_connection"

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
      get :spatial_correlations
      patch :update_content
      delete "content/:content_id", to: "wells#remove_content", as: "remove_content"
    end
    collection do
      post :bulk_add_content
    end
    resources :images, except: [ :index ] do
      resources :point_of_interests, except: [ :new, :edit ] do
        collection do
          post :auto_segment
          get :auto_segment_status
        end
      end
    end
    resources :pxrd_patterns
    resources :scxrd_datasets do
      member do
        get :download
        get :download_peak_table
        get :download_first_image
        get :image_data
        get :peak_table_data
      end
      resources :diffraction_images, only: [:index, :show] do
        member do
          get :image_data
          get :parsed_image_data
          get :download
        end
      end
    end
    resources :well_contents do
      collection do
        delete :destroy_all
      end
    end
  end

  # Standalone PXRD pattern routes for AJAX calls and global index
  resources :pxrd_patterns, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    member do
      get :plot
    end
  end

  # Standalone SCXRD dataset routes for global index
  resources :scxrd_datasets, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    member do
      get :download
      get :download_peak_table
      get :download_first_image
      get :image_data
      get :peak_table_data
    end
    resources :diffraction_images, only: [:index, :show] do
      member do
        get :image_data
        get :parsed_image_data
        get :download
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
          resources :pxrd_patterns, only: [ :index, :create ]
          resources :scxrd_datasets, only: [ :index, :show, :create, :update, :destroy ] do
            member do
              get :image_data
              get :peak_table_data
            end
            collection do
              get :spatial_correlations
              get :search
            end
            resources :diffraction_images, only: [:index, :show] do
              member do
                get :image_data
                get :parsed_image_data
                get :download
              end
            end
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
        resources :pxrd_patterns, only: [ :index, :create ]
        resources :scxrd_datasets, only: [ :index, :show, :create, :update, :destroy ] do
          member do
            get :image_data
            get :peak_table_data
          end
          collection do
            get :spatial_correlations
            get :search
          end
          resources :diffraction_images, only: [:index, :show] do
            member do
              get :image_data
              get :parsed_image_data
              get :download
            end
          end
        end
      end

      # Standalone PXRD pattern routes
      resources :pxrd_patterns, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          get :data
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
