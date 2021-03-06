class ApplicationController < ActionController::Base
  include Pundit
  include ReturnToHelper
  include MarkdownHelper

  helper ValueHelper
  add_template_helper ClientHelper

  protect_from_forgery with: :exception
  helper_method :current_user, :signed_in?, :return_to

  before_action :disable_peek_by_default

  protected

  # We are overriding this method to account for ExceptionPolicies
  def authorize(record, query = nil, user = nil)
    user ||= @current_user
    policy = ::PolicyFinder.policy_for(user, record)

    # use the action as a default permission
    query ||= ("can_" + params[:action].to_s + "!").to_sym
    unless policy.public_send(query)
      # the method might raise its own exception, or it might return a
      # boolean. Both systems are accommodated
      # will need to replace this when a new version of pundit arrives
      msg = "not allowed to #{query} this #{record}"
      ex = NotAuthorizedError.new(query: query, record: record, policy: policy, message: msg)
      fail ex
    end
  end

  # Override Pundit to account for proposal gymnastics
  def policy(record)
    obj = ::PolicyFinder.authorizing_object(record)
    super(obj)
  end

  def admin?
    signed_in? && current_user.admin?
  end

  def peek_enabled?
    Rails.env.development? || self.admin?
  end

  private

  def current_user
    @current_user ||= find_current_user
  end

  def find_current_user
    if ENV['FORCE_USER_ID'] && !Rails.env.production?
      User.find ENV['FORCE_USER_ID']
    elsif session[:user] && session[:user]['email']
      User.find_or_create_by(email_address: session[:user]['email'])
    end
  end

  def sign_in(user)
    session[:user] ||= {}
    session[:user]['email'] = user.email_address
    @current_user = user
  end

  def sign_out
    reset_session
    @current_user = nil
  end

  def signed_in?
    current_user ? true : false
  end

  def authenticate_user!
    unless signed_in?
      flash[:error] = 'You need to sign in for access to this page.'
      redirect_to root_url(return_to: self.make_return_to("Previous", request.fullpath))
    end
  end

  def disable_peek_by_default
    if cookies[:peek].nil?
      cookies[:peek] = false
    end
  end
end
