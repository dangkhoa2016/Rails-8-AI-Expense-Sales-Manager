class ApplicationController < ActionController::Base
  include Authentication
  helper_method :current_user, :current_workspace

  private
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
