# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    # All authenticated users can view lists
    user.present?
  end

  def show?
    # All authenticated users can view individual records
    user.present?
  end

  def create?
    # Only writable and admin users can create
    user.present? && (user.writable? || user.admin?)
  end

  def new?
    create?
  end

  def update?
    # Only writable and admin users can update
    user.present? && (user.writable? || user.admin?)
  end

  def edit?
    update?
  end

  def destroy?
    # Only writable and admin users can destroy
    user.present? && (user.writable? || user.admin?)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      # By default, return all records if user is authenticated
      # Individual policies can override this for more specific scoping
      if user.present?
        scope.all
      else
        scope.none
      end
    end

    private

    attr_reader :user, :scope
  end
end
