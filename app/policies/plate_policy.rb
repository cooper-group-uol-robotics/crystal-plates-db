# frozen_string_literal: true

class PlatePolicy < ApplicationPolicy
  # All authenticated users can view plates
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  # Only writable and admin users can create/update/delete
  def create?
    user.present? && (user.writable? || user.admin?)
  end

  def new?
    create?
  end

  def update?
    user.present? && (user.writable? || user.admin?)
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && (user.writable? || user.admin?)
  end

  # Custom actions
  def builder?
    create?
  end

  def create_from_builder?
    create?
  end

  def restore?
    destroy?
  end

  def permanent_delete?
    user.present? && user.admin?
  end

  def bulk_upload_contents?
    update?
  end

  def bulk_upload_attributes?
    update?
  end

  def download_contents_csv?
    show?
  end

  def download_attributes_csv?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.present?
        scope.all
      else
        scope.none
      end
    end
  end
end
