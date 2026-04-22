Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
  get "login", to: "sessions#new"

  resources :products, only: %i[index show] do
    resources :reviews, only: :create
  end

  resource :cart, only: :show
  post "cart/items", to: "carts#create", as: :cart_items
  patch "cart/items/:product_id", to: "carts#update", as: :cart_item
  delete "cart/items/:product_id", to: "carts#destroy"
  post "cart/coupon", to: "carts#apply_coupon", as: :cart_coupon

  resources :orders, only: %i[new create show]
  get "track-order", to: "orders#tracking_form", as: :track_order
  post "track-order", to: "orders#track"

  resources :articles, only: %i[index show]
  resources :newsletter_signups, only: :create

  get "about", to: "pages#about"
  get "contact", to: "pages#contact"
  get "faqs", to: "pages#faqs"
  get "delivery", to: "pages#delivery"
  get "service-areas/:area", to: "pages#location", as: :location_page
  get "privacy-policy", to: "pages#privacy", as: :privacy_policy
  get "terms-and-conditions", to: "pages#terms", as: :terms_and_conditions

  # Unified Authentication
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  
  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"

  namespace :admin do
    # Remove separate admin login
    match "logout", to: "/sessions#destroy", via: %i[get delete]
    root "dashboard#index"
    resources :managers, only: %i[index new create]
    resources :categories, except: :show
    resources :products, except: :show
    resources :orders, only: %i[index show update]
  end

  namespace :manager do
    # Remove separate manager login
    match "logout", to: "/sessions#destroy", via: %i[get delete]
    get "register/:token", to: "registrations#edit", as: :register
    patch "register/:token", to: "registrations#update"
    root "inventory#index"
    resources :products, only: %i[index new create]
    resources :categories, only: :index
    resources :inventory, only: %i[index edit update], controller: "inventory"
    resources :orders, only: %i[index show update]
  end

  namespace :buyer do
    # Remove separate buyer login
    match "logout", to: "/sessions#destroy", via: %i[get delete]
    root "dashboard#index"
  end

  mount Avo::Engine => "/avo"
end
