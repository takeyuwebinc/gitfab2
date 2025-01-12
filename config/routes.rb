Rails.application.routes.draw do
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  get '/up' => 'health#show'

  get 'about', to: 'static_pages#about'
  get 'terms', to: 'static_pages#terms'
  get 'privacy', to: 'static_pages#privacy'

  namespace :admin do
    root 'dashboard#index'
    resources :features do
      resources :featured_items
    end
    resources :projects, via: %i(get put delete)
    get 'background', to: 'background#index', as: :background
    put 'background', to: 'background#update'
    resources :black_lists, except: [:edit, :update]
    resources :project_comments, only: %i[index update destroy] do
      resource :approval, only: [:create, :destroy], module: :project_comments
      resource :spam, only: [:create, :destroy], module: :project_comments
    end
    namespace :project_comments do
      resource :spam_batch, only: :create
    end
    resources :card_comments, only: %i[index update destroy] do
      resource :approval, only: [:create, :destroy], module: :card_comments
      resource :spam, only: [:create, :destroy], module: :card_comments
    end
    namespace :card_comments do
      resource :spam_batch, only: :create
    end
    resources :spammers, only: %i[index destroy]
  end

  root 'projects#index'

  if Rails.env.development? || Rails.env.test?
    post 'su', to: 'development#su'
  end

  resources :sessions, only: [:index, :create]
  get '/users/auth/:provider/callback', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  get 'search', to: 'projects#search'

  resources :cards, only: [] do
    resources :card_comments, only: :create
  end
  resources :card_comments, only: :destroy

  resources :groups, except: :show do
    resources :members, only: :create
  end

  resources :notifications, only: [:index, :update] do
    get 'mark_all_as_read', on: :collection
  end

  resources :users, except: [:show, :edit, :update, :destroy] do
    resources :memberships, only: [:index, :update, :destroy]
    patch :update_password
    post :backup
    get :download_backup
  end
  resource :user, only: [:edit, :update, :destroy]
  resource :password, only: [:new, :create, :edit, :update]

  resources :collaborations, only: :destroy
  resources :projects, only: [:new, :create]
  resources :tags, only: :destroy
  resources :projects, path: '/:owner_name', except: [:index, :new, :create, :search] do
    delete 'destroy_or_render_edit', to: 'projects#destroy_or_render_edit'
    resources :collaborations, only: :create
    resource :likes, only: [:show, :create, :destroy]
    resources :note_cards
    resources :states, except: :index do
      resources :annotations, except: :index do
        get 'to_state'
      end
      get 'to_annotation'
    end
    resources :tags, only: :create
    resources :usages, only: [:new, :create, :edit, :update, :destroy]
    resources :project_comments, only: [:create, :destroy]
    post :fork
    patch :change_order
    get 'recipe_cards_list'
    get 'relation_tree'
    get :slideshow
  end

  resources :owners, only: :index
  resource :owners, path: '/:owner_name', as: :owner, only: :show
end
