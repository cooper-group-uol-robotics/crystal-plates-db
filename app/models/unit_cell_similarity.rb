class UnitCellSimilarity < ApplicationRecord
  belongs_to :dataset_1, class_name: 'ScxrdDataset'
  belongs_to :dataset_2, class_name: 'ScxrdDataset'

  validates :g6_distance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :dataset_1_id, presence: true
  validates :dataset_2_id, presence: true
  validate :different_datasets
  validate :canonical_order

  # Ensure we always store pairs in a canonical order (dataset_1_id < dataset_2_id)
  # to avoid duplicate entries
  before_validation :ensure_canonical_order

  scope :for_dataset, ->(dataset_id) {
    where("dataset_1_id = ? OR dataset_2_id = ?", dataset_id, dataset_id)
  }

  scope :within_tolerance, ->(tolerance) { where("g6_distance <= ?", tolerance) }

  # Find similarities for a specific dataset with optional tolerance filtering
  def self.similarities_for_dataset(dataset_id, tolerance: nil)
    similarities = for_dataset(dataset_id)
    similarities = similarities.within_tolerance(tolerance) if tolerance
    similarities.includes(:dataset_1, :dataset_2)
  end

  # Get the other dataset in this similarity pair
  def other_dataset(dataset_id)
    if dataset_1_id == dataset_id
      dataset_2
    elsif dataset_2_id == dataset_id
      dataset_1
    else
      nil
    end
  end

  private

  def different_datasets
    if dataset_1_id == dataset_2_id
      errors.add(:dataset_2_id, "must be different from dataset_1")
    end
  end

  def canonical_order
    if dataset_1_id && dataset_2_id && dataset_1_id > dataset_2_id
      errors.add(:base, "Datasets should be stored in canonical order (dataset_1_id < dataset_2_id)")
    end
  end

  def ensure_canonical_order
    if dataset_1_id && dataset_2_id && dataset_1_id > dataset_2_id
      self.dataset_1_id, self.dataset_2_id = dataset_2_id, dataset_1_id
    end
  end
end
