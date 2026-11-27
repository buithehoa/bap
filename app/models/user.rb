class User < ApplicationRecord
  PROVIDER_NAMES = { "google_oauth2" => "Google", "facebook" => "Facebook" }.freeze
  PROVIDERS = PROVIDER_NAMES.keys

  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :provider, inclusion: { in: PROVIDERS }
  validates :uid, presence: true, uniqueness: { scope: :provider }

  def provider_name
    PROVIDER_NAMES.fetch(provider)
  end

  # Finds the user by the provider's stable account id, or creates one, and
  # overwrites the profile with what the provider reports now (including nil).
  def self.from_omniauth!(auth)
    find_or_initialize_by(provider: auth.provider, uid: auth.uid).tap do |user|
      user.update!(name: auth.info.name, email_address: auth.info.email, image_url: auth.info.image)
    end
  end
end
