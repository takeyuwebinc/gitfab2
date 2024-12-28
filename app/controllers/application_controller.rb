class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  unless Rails.env.development?
    rescue_from Exception, with: :render_500
    rescue_from ActiveRecord::RecordNotFound, with: -> { render_404 }
    rescue_from ActionController::RoutingError, with: -> { render_404 }
    rescue_from ActionView::MissingTemplate, with: -> { render_404 }
  end
  rescue_from CanCan::AccessDenied, with: -> { render_401 }

  after_action :store_location
  before_action :set_sentry_context

  def current_user
    @current_user ||= begin
      return unless session[:su]
      User.readonly.active.find_by(id: session[:su])
    end
  end
  helper_method :current_user

  def current_user=(user)
    session[:su] = user&.id
    @current_user = user
  end

  def render_401(layout: false)
    render file: Rails.root.join('public/401.html'), status: :unauthorized, layout: layout
  end

  def render_403(layout: false)
    render file: Rails.root.join('public/403.html'), status: :forbidden, layout: layout
  end

  def render_404(layout: false)
    render file: Rails.root.join('public/404.html'), status: :not_found, layout: layout
  end

  private

    def store_location
      return if !request.get? || !request.format.html? || request.xhr?
      return if request.path.start_with?('/password')
      return if request.path.start_with?('/users/auth')
      return if ['/users/new', '/users/sign_out', '/sessions'].include?(request.path)
      session[:previous_url] = request.fullpath
    end

    def render_500(exception = nil)
      if exception
        Rails.logger.error(exception)
        exception.backtrace.each do |f|
          Rails.logger.error("  #{f}")
        end
        Sentry.capture_exception(exception) # TODO: Rails 7.0 になったら消す ActiveSupport::ErrorReporter でサブスクライブされているため
      end
      render file: Rails.root.join('public/500.html'), status: 500, layout: false, content_type: 'text/html'
    end

    def set_sentry_context
      Sentry.set_user(
        id: current_user&.id,
        ip_address: request.remote_ip,
      )
      Sentry.set_extras(
        params: params.to_unsafe_h,
      )
    end

    def authenticate_user!
      unless current_user.present?
        redirect_to sessions_path
      end
    end
end
