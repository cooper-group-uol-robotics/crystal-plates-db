class DiffractionImage < ApplicationRecord
  belongs_to :scxrd_dataset
  
  # ActiveStorage attachment for the rodhypix file
  has_one_attached :rodhypix_file
  
  # Validations
  validates :run_number, presence: true, numericality: { greater_than: 0 }
  validates :image_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :filename, presence: true
  validates :run_number, uniqueness: { scope: [:scxrd_dataset_id, :image_number] }
  
  # Scopes for ordering and filtering
  scope :ordered, -> { order(:run_number, :image_number) }
  scope :for_run, ->(run_number) { where(run_number: run_number) }
  scope :first_of_each_run, -> { 
    joins("INNER JOIN (SELECT scxrd_dataset_id, run_number, MIN(image_number) as min_image_number FROM diffraction_images GROUP BY scxrd_dataset_id, run_number) grouped ON diffraction_images.scxrd_dataset_id = grouped.scxrd_dataset_id AND diffraction_images.run_number = grouped.run_number AND diffraction_images.image_number = grouped.min_image_number")
  }
  
  # Class methods
  def self.runs_for_dataset(dataset_id)
    where(scxrd_dataset_id: dataset_id).distinct.pluck(:run_number).sort
  end
  
  def self.images_for_run(dataset_id, run_number)
    where(scxrd_dataset_id: dataset_id, run_number: run_number).order(:image_number)
  end
  
  # Instance methods
  def display_name
    "Run #{run_number}, Image #{image_number}"
  end
  
  def sequence_position
    "#{run_number}-#{image_number.to_s.rjust(4, '0')}"
  end
  
  def next_image
    self.class.where(scxrd_dataset: scxrd_dataset)
             .where('run_number > ? OR (run_number = ? AND image_number > ?)', 
                    run_number, run_number, image_number)
             .order(:run_number, :image_number)
             .first
  end
  
  def previous_image
    self.class.where(scxrd_dataset: scxrd_dataset)
             .where('run_number < ? OR (run_number = ? AND image_number < ?)', 
                    run_number, run_number, image_number)
             .order(:run_number, :image_number)
             .last
  end
  
  def file_size_human
    return 'Unknown' unless file_size
    
    if file_size < 1024
      "#{file_size} B"
    elsif file_size < 1024 * 1024
      "#{(file_size / 1024.0).round(1)} KB"
    elsif file_size < 1024 * 1024 * 1024
      "#{(file_size / (1024.0 * 1024)).round(1)} MB"
    else
      "#{(file_size / (1024.0 * 1024 * 1024)).round(1)} GB"
    end
  end
end
