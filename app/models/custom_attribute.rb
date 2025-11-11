class CustomAttribute < ApplicationRecord
  has_many :well_scores, dependent: :destroy
  has_many :wells, through: :well_scores

  # Attribute names must be unique globally
  validates :name, presence: true, uniqueness: { message: "already exists. Custom attribute names must be unique." }
  validates :data_type, presence: true, inclusion: { in: %w[numeric text json boolean] }
  scope :with_well_scores_in_plate, ->(plate) {
    joins(:well_scores)
      .joins('JOIN wells ON wells.id = well_scores.well_id')
      .where('wells.plate_id = ?', plate.id)
      .distinct
  }

  def display_name
    name
  end

  # Get all wells that have a score for this attribute within the given plate
  def scored_wells_in_plate(plate)
    wells.joins(:well_scores)
         .where(well_scores: { custom_attribute: self })
         .where(plate: plate)
  end

  # Get statistics for this attribute within a plate
  def statistics_for_plate(plate)
    scores = well_scores.joins(:well)
                       .where(wells: { plate: plate })
                       .pluck(:value)
                       .compact
                       
    return {} if scores.empty?
    
    {
      count: scores.count,
      min: scores.min,
      max: scores.max,
      mean: scores.sum / scores.count.to_f,
      median: scores.sort[scores.count / 2]
    }
  end
end