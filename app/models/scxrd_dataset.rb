class ScxrdDataset < ApplicationRecord
  belongs_to :well
  belongs_to :lattice_centring, optional: true
  has_one_attached :archive
  has_one_attached :peak_table
  has_one_attached :first_image

  validates :experiment_name, :date_measured, presence: true
  validates :a, :b, :c, :alpha, :beta, :gamma, numericality: { greater_than: 0 }, allow_nil: true

  def has_peak_table?
    peak_table.attached?
  end

  def has_first_image?
    first_image.attached?
  end

  def peak_table_size
    return 0 unless peak_table.attached?
    peak_table.blob.byte_size
  end

  def first_image_size
    return 0 unless first_image.attached?
    first_image.blob.byte_size
  end
end
