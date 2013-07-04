require 'test_helper'
require 'oauth'
include OAuthHelper

describe TokensController do
  let(:username) { 'admin' }
  let(:password) { 'admin' }

  before { User.find_by_username(username) || UserFactory.create!(username, password) }

  describe "#list" do
    context "authentication fails" do
      before { get :list, :username => 'admin', :format => 'json' }
      it { response.code.must_equal '401' }
    end

    context "authenticated request" do
      let(:tokens) { JSON.parse(response.body) }

      context "existing user without tokens" do
        before do
          Token.delete_all
          request.env['HTTP_AUTHORIZATION'] = auth_header('admin')
          get :list, :username => 'admin', :format => 'json'
        end

        it { response.must_be :success? }
        it { tokens.must_equal [] }
      end


      context "existing user with tokens" do
        before do
          Token.delete_all
          TokenFactory.create!(8.hours.from_now, 'secret1', 'admin')
          TokenFactory.create!(8.hours.ago, 'secret2', 'admin')
          request.env['HTTP_AUTHORIZATION'] = auth_header('admin')
          get :list, :username => 'admin', :format => 'json'
        end

        it { response.must_be :success? }
        it { tokens.must_include 'secret1' }
        it { tokens.wont_include 'secret2' }
      end

      context "unknown user" do
        before do
          request.env['HTTP_AUTHORIZATION'] = auth_header('whatever')
          get :list, :username => 'whatever', :format => 'json'
        end

        it { response.must_be :not_found? }
      end

    end
  end
end
