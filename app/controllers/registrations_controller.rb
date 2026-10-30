class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5, within: 15.minutes, only: :create

  def new
    @user = User.new
  end

  def create
    unless Rails.env.development? || Rails.env.test? || ENV["ENABLE_SIGNUP"] == "true"
      return head :forbidden
    end

    @user = User.new(params.require(:user).permit(:email_address, :password, :password_confirmation))
    User.transaction do
      @user.save!
      @user.workspaces.create!(name: "Personal Workspace")
    end
    start_new_session_for(@user)
    redirect_to root_path, notice: "Account created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end
end
