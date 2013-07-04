require 'test_helper'

describe Token do
  before do
    @past_token   = TokenFactory.create!(1.hour.ago)
    @future_token = TokenFactory.create!(1.hour.from_now)
  end

  describe ".valid" do
    it "find only not expired tokens" do
      Token.valid.must_include @future_token
      Token.valid.wont_include @past_token
    end
  end

end
