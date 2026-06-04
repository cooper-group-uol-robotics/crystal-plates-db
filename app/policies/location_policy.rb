# frozen_string_literal: true

class LocationPolicy < ApplicationPolicy
  # All authenticated users can view locations
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def grid?
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
