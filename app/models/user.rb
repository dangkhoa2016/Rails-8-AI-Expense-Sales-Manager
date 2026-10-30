class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :workspaces, foreign_key: :owner_id, dependent: :restrict_with_exception

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
