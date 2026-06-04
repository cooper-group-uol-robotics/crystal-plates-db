class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  # Associations
  has_many :api_keys, dependent: :destroy

  # Role-based authorization
  enum :role, { readable: "readable", writable: "writable", admin: "admin" }, validate: true

  # Validations
  validates :role, presence: true
  validates :email, presence: true, uniqueness: true
  validates :ldap_uid, uniqueness: true, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :admins, -> { where(role: "admin") }
  scope :ldap_users, -> { where.not(ldap_uid: nil) }
  scope :local_users, -> { where(ldap_uid: nil) }

  # Instance methods
  def admin?
    role == "admin"
  end

  def writable?
    role == "writable" || admin?
  end

  def readable?
    role == "readable" || writable? || admin?
  end

  def ldap_user?
    ldap_uid.present?
  end

  def local_user?
    !ldap_user?
  end

  def display_name
    email.split("@").first.titleize
  end
end
