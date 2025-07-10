module Api::V1
    class PlatesController < ApplicationController
      def index
        render json: Plate.all.includes(:wells), include: [ "wells" ]
      end

      def show
        plate = Plate.find_by!(barcode: params[:id])
        render json: plate, include: [ "wells" ]
      end

      def create
        plate = Plate.new(plate_params)
        if plate.save
          render json: plate, include: [ "wells" ], status: :created
        else
          render json: plate.errors, status: :unprocessable_entity
        end
      end

      private

      def plate_params
        params.require(:plate).permit(
          :barcode, :location_position, :location_stack,
          wells_attributes: [ :well_position, :chemical_bottle_id, :volume_ul, :image ]
        )
      end
    end
end
