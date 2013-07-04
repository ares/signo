require 'oauth/request_proxy/rack_request'

class TokensController < ApplicationController
  before_filter :authenticate, :find_user
  respond_to :json

  def list
    respond_with @user.tokens.valid.map(&:oauth_secret)
  end

  protected

  def authenticate
    rack_request = Rack::Request.new(request.env)
    consumer_key = OAuth::RequestProxy.proxy(rack_request).oauth_consumer_key
    render :status => :unauthorized, :json => {} and return false if consumer_key.blank?

    consumer_secret = ::Configuration.config.consumers[consumer_key].secret
    signature = OAuth::Signature.build(rack_request) do
      [nil, consumer_secret]
    end

    logger.debug "OAuth request signature verification: #{result = signature.verify}"
    result ? true : render(:status => :unauthorized, :json => {})
  end

  def find_user
    @user = User.find_by_username(params[:username])

    if @user.nil?
      logger.info "User not found by username #{params[:username]}"
      render :status => :not_found, :json => {}
      return false
    end
  end
end
