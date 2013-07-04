# A user that can authenticate
class User < ActiveRecord::Base
  attr_accessor :password

  # user can have many oauth tokens used for CLI authentication
  has_many :tokens, :dependent => :destroy

  validates :username, :uniqueness => true

  # authenticate user
  #
  # currently we use only Katello to authenticate user using his credentials
  # @return [true, false] was authentication successful?
  def authenticate
    Backends::Base.authenticate(self)
  end
end
