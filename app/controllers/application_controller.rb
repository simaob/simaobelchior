class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= user_from_session || user_from_remember_cookie
  end

  def user_from_session
    User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_from_remember_cookie
    token = cookies[:remember_me]
    return unless token

    if (user = User.find_by_token_for(:remember_me, token))
      session[:user_id] = user.id
      user
    else
      cookies.delete(:remember_me)
      nil
    end
  end

  def remember(user)
    cookies[:remember_me] = {
      value: user.generate_token_for(:remember_me),
      expires: 4.weeks,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
  end

  def forget
    cookies.delete(:remember_me)
  end

  def logged_in?
    current_user.present?
  end

  def require_authentication
    unless logged_in?
      redirect_to login_path, alert: "You must be logged in to access this page"
    end
  end
end
