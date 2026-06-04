class ApiKey < ApplicationRecord
  belongs_to :user

  # Virtual attribute to hold the raw token (only available at creation)
  attr_accessor :raw_token

  # Validations
  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :user, presence: true
  validate :expires_at_must_be_in_future, if: :expires_at_changed?

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :valid_keys, -> { active.where("expires_at IS NULL OR expires_at > ?", Time.current) }

  # Callbacks
  before_create :generate_token

  # Class methods
  def self.authenticate(token)
    return nil if token.blank?

    # Find by hashed token
    api_key = find_by(token_digest: hash_token(token))
    return nil unless api_key

    # Check if key is active and not expired
    return nil unless api_key.active?
    return nil if api_key.expired?

    # Update last used timestamp
    api_key.touch(:last_used_at)

    api_key
  end

  def self.hash_token(token)
    Digest::SHA256.hexdigest(token)
  end

  # Instance methods
  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def valid_key?
    active? && !expired?
  end

  def revoke!
    update!(active: false)
  end

  def expires_in_days
    return nil unless expires_at
    ((expires_at - Time.current) / 1.day).round
  end

  private

  def generate_token
    # Generate a secure random token (32 bytes = 64 hex characters)
    self.raw_token = SecureRandom.hex(32)
    # Store the hashed version
    self.token_digest = self.class.hash_token(raw_token)
  end

  def expires_at_must_be_in_future
    if expires_at.present? && expires_at <= Time.current
      errors.add(:expires_at, "must be in the future")
    end
  end
end
