require 'test_helper'

describe UsersController do
  let(:username) { 'whoever' }

  describe "#show" do
    context "don't accept xrds" do
      before { get :show, :username => username }
      it { response.must_be :success? }
      it { response.body.must_include "OpenID identity page for #{username}" }
    end

    context "accept xrds" do
      let(:provider_url) { url_for(:controller => 'login', :action => 'provider',
                                   :only_path => false, :host => 'test.host') }
      before do
        request.env['HTTP_ACCEPT'] = 'application/xrds+xml'
        get :show, :username => username
      end

      it { response.must_be :success? }
      it { response.body.must_include "<URI>#{provider_url}</URI>"}
    end
  end

end
