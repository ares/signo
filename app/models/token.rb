class Token < ActiveRecord::Base
  attr_accessible :oauth_secret, :user_id, :expiration

  scope :valid, where("expiration >= ?", DateTime.now)
end
