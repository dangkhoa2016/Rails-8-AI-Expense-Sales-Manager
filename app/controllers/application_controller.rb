class ApplicationController < ActionController::Base
  include Authentication
  around_action :switch_locale
  helper_method :current_user, :current_workspace

  private
  def switch_locale(&action)
    chosen = params[:locale].to_s
    if %w[en vi].include?(chosen)
      cookies.permanent.signed[:finance_locale] = {
        value: chosen, httponly: true, same_site: :lax
      }
    end
    saved = cookies.signed[:finance_locale].to_s
    target = %w[en vi].include?(chosen) ? chosen : saved
    I18n.with_locale(%w[en vi].include?(target) ? target.to_sym : I18n.default_locale, &action)
  end

  def current_user
    Current.user
  end

  def current_workspace
    Current.user&.workspaces&.order(:id)&.first
  end

  public
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
