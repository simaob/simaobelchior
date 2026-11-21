class User < ApplicationRecord
  has_secure_password

  # Signed, self-expiring token for the "remember me" cookie. Embedding part of
  # the password salt means changing the password invalidates every token.
  generates_token_for :remember_me, expires_in: 4.weeks do
    password_salt.last(10)
  end

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email, with: ->(email) { email.strip.downcase }
end
