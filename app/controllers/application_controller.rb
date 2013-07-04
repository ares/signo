class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :set_gettext_locale

  private

  def is_logged_in?
    current_username.present?
  end

  def current_username
    session[:username]
  end

end
