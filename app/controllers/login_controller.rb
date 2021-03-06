require 'pathname'
require "openid"
require "openid/consumer/discovery"
require 'openid/store/filesystem'


class LoginController < ApplicationController
  include OpenID::Server
  layout false, :only => :provider
  protect_from_forgery :except => :provider

  def index
    if is_logged_in? && cookies[:username].blank?
      cookies[:username] = current_username
      redirect_to return_url
    elsif is_logged_in? && params[:return_url]
      redirect_to return_url
    else
      set_notice
      session[:return_url] = params[:return_url] if params[:return_url].present?
    end
  end


  def login
    user = User.new(params[:username], params[:password])
    if user.authenticate
      respond_to do |format|
        format.html do
          session[:username] = user.username
          cookies[:username] = { :value   => current_username,
                                 :expires => ::Configuration.config.cookie_life.hours.from_now }
          redirect_to return_url
        end

        format.json do
          render :json => {}, :status => 200
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:error] = _('Authentication failed, try again')
          render :action => 'index'
        end

        format.json do
          render :json => {}, :status => 401
        end
      end
    end
  end

  def provider
    begin
      oidreq = server.decode_request(params)
    rescue ProtocolError => e
      # invalid openid request, so just display a page with an error message
      render :text => e.to_s, :status => 500
      return
    end

    # no openid.mode was given
    unless oidreq
      render :text => "This is an OpenID server endpoint."
      return
    end

    # cookie was set but no user is logged in, we need to identify user first so send him to index
    # if request is not GET it's not user request but RP background request which is always not
    # logged in so we skip this check in such case
    if request.get? && !is_logged_in?
      redirect_to root_path(:return_url => params[:"openid.return_to"])
      return
    end

    # casual OpenID authentication request
    if oidreq.kind_of?(CheckIDRequest)

      identity = oidreq.identity

      if is_authorized(oidreq.trust_root)
        req_identity = identity.split('/').last

        if current_username != req_identity
          # cookie says identifies another that current user, current user has precedence
          # we reset cookie and let the process begin again from RP
          cookies[:username] = current_username
          redirect_to Url.new(params[:"openid.return_to"]).add_username(current_username).to_s
          return
        else
          # we make sure cookie is set and response to OpenID auth request
          cookies[:username] = { :value   => current_username,
                                 :expires => ::Configuration.config.cookie_life.hours.from_now }
          oidresp            = oidreq.answer(true, nil, identity)
        end
      else
        flash[:error] = _('Relay Party %s not trusted, consult SSO configuration.') % oidreq.trust_root
        redirect_to root_path
        return
      end
    else
      oidresp = server.handle_request(oidreq)
    end

    render_response(oidresp)
  end

  def logout
    session[:username] = nil
    session[:return_url] = params[:return_url] if params[:return_url].present?
    redirect_to root_path(:notice => 'logout')
  end

  private

  def set_notice
    case params[:notice]
      when 'logout'
        flash.now[:success] = _('You have been logged out')
      when 'expired'
        flash.now[:warning] = _('Your session has expired, please login again')
      when nil, ''
        # ignore these cases completely
      else
        raise ArgumentError, "unsupported notice '#{params[:notice]}'"
    end
  end

  def render_response(oidresp)
    if oidresp.needs_signing
      signed_response = server.signatory.sign(oidresp)
    end
    web_response = server.encode_response(oidresp)

    case web_response.code
      when HTTP_OK
        render :text => web_response.body, :status => 200
      when HTTP_REDIRECT
        redirect_to Url.new(web_response.headers['location']).sslize.to_s
      else
        render :text => web_response.body, :status => 400
    end
  end

  def url_for_user
    url_for :controller => 'user', :action => current_username
  end

  def server
    @server ||= begin
      server_url = url_for :controller => 'login', :action => 'provider', :only_path => false
      dir        = Pathname.new(Rails.root).join('db').join('openid-store')
      store      = OpenID::Store::Filesystem.new(dir)
      Server.new(store, server_url)
    end
  end

  def return_url
    url = Url.new(params[:return_url] || session[:return_url] || root_path)
    url.sslize.add_username(current_username).to_s
  end
end
