# frozen_string_literal: true

class ChemicalPolicy < ApplicationPolicy
  # All authenticated users can view chemicals
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

  def import_from_sciformation?
    user.present? && (user.writable? || user.admin?)
  end

  def sciformation_auth?
    user.present?
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
