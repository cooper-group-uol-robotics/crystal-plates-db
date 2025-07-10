module Api::V1
  class StatsController < BaseController
    def show
      render_success({
        overview: {
          total_plates: Plate.count,
          total_locations: Location.count,
          total_wells: Well.count,
          occupied_locations: occupied_locations_count,
          available_locations: available_locations_count
        },
        locations: {
          carousel_locations: carousel_locations_count,
          special_locations: special_locations_count,
          occupancy_rate: occupancy_rate
        },
        plates: {
          plates_with_location: plates_with_location_count,
          plates_without_location: plates_without_location_count,
          recent_movements: recent_movements_count
        },
        wells: {
          wells_with_content: wells_with_content_count,
          wells_without_content: wells_without_content_count,
          average_wells_per_plate: average_wells_per_plate
        }
      })
    end

    private

    def occupied_locations_count
      Location.joins(:plate_locations)
              .where(plate_locations: { id: PlateLocation.select("MAX(id)").group(:plate_id) })
              .distinct
              .count
    end

    def available_locations_count
      Location.count - occupied_locations_count
    end

    def carousel_locations_count
      Location.where.not(carousel_position: nil, hotel_position: nil).count
    end

    def special_locations_count
      Location.where(carousel_position: nil, hotel_position: nil).count
    end

    def occupancy_rate
      return 0.0 if Location.count == 0
      (occupied_locations_count.to_f / Location.count * 100).round(2)
    end

    def plates_with_location_count
      Plate.joins(:plate_locations)
           .where(plate_locations: { id: PlateLocation.select("MAX(id)").group(:plate_id) })
           .distinct
           .count
    end

    def plates_without_location_count
      Plate.count - plates_with_location_count
    end

    def recent_movements_count
      PlateLocation.where("moved_at > ?", 24.hours.ago).count
    end

    def wells_with_content_count
      Well.joins(:well_content).distinct.count
    end

    def wells_without_content_count
      Well.count - wells_with_content_count
    end

    def average_wells_per_plate
      return 0.0 if Plate.count == 0
      (Well.count.to_f / Plate.count).round(2)
    end
  end
end
