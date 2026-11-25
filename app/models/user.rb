class User < ApplicationRecord
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :google_uid, presence: true, uniqueness: true
  validates :email_address, presence: true

  # Finds the user by Google's stable account id, or creates one, and
  # refreshes the email Google reports for it.
  def self.from_google!(uid:, email:)
    find_or_initialize_by(google_uid: uid).tap do |user|
      user.update!(email_address: email)
    end
  end
end
