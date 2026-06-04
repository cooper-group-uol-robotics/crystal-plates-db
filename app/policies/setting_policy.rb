# frozen_string_literal: true

class SettingPolicy < ApplicationPolicy
  def index?
    # All authenticated users can view settings
    user.present?
  end

  def show?
    # All authenticated users can view settings
    user.present?
  end

  def create?
    # Only admins can create settings
    user.present? && user.admin?
  end

  def update?
    # Only admins can update settings
    user.present? && user.admin?
  end

  def destroy?
    # Only admins can destroy settings
    user.present? && user.admin?
  end

  def test_connection?
    # All authenticated users can test connections
    user.present?
  end

  def test_conventional_cell_api?
    # All authenticated users can test APIs
    user.present?
  end

  def test_sciformation_credentials?
    # All authenticated users can test credentials
    user.present?
  end

  def test_sciformation_cookie?
    # All authenticated users can test cookies
    user.present?
  end

  def get_sciformation_cookie?
    # All authenticated users can get cookies
    user.present?
  end
end
