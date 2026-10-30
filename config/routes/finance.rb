# Add inside Rails.application.routes.draw do ... end; do not replace existing routes.
namespace :finance do
  # Public-facing tag URL, backed by the existing localized Category model.
  resources :tags, controller: :categories, only: %i[index create edit update destroy]
  # Backward-compatible legacy paths for bookmarks and integrations.
  resources :categories, only: %i[index create edit update destroy]
  resources :transactions, only: %i[index new create show edit update] do
    collection { post :from_receipt }
    member do
      post :confirm
      get :review
    end
    resource :correction, only: :create, controller: :corrections do
      post :cancel, on: :member
    end
    resources :line_items, only: %i[index new edit create update destroy] do
      collection do
        post :import
        get :proposals
      end
    end
    resources :document_versions, only: %i[create show] do
      member { get :image }
    end
    resources :field_suggestions, only: [] do
      member do
        post :accept
        post :reject
      end
    end
  end
  get 'reports', to: 'reports#show', as: :reports
  get 'reports/export', to: 'reports#export', as: :reports_export
end
