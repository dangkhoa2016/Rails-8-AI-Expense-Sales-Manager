# Add inside Rails.application.routes.draw do ... end; do not replace existing routes.
namespace :finance do
  resources :transactions, only: %i[index new create show edit update] do
    member { post :confirm }
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
