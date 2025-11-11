module Api::V1
  class WellScoresController < BaseController
    before_action :set_plate_and_well
    before_action :set_well_score, only: [:update, :destroy]

    # GET /api/v1/plates/:plate_barcode/wells/:well_id/well_scores
    def index
      well_scores = @well.well_scores.includes(:custom_attribute).order('custom_attributes.name')
      render_success(well_scores.map { |score| serialize_well_score(score) })
    end

    # POST /api/v1/plates/:plate_barcode/wells/:well_id/well_scores
    def create
      custom_attribute = find_or_create_custom_attribute
      return unless custom_attribute

      well_score = @well.well_scores.find_or_initialize_by(custom_attribute: custom_attribute)
      well_score.set_display_value(params[:value])

      if well_score.save
        # Always add attribute to all other wells in the plate
        add_attribute_to_other_wells(custom_attribute)

        render_success(serialize_well_score(well_score), status: :created)
      else
        render_error("Failed to create/update well score", 
                    status: :unprocessable_entity, 
                    details: well_score.errors.full_messages)
      end
    end

    # PATCH/PUT /api/v1/plates/:plate_barcode/wells/:well_id/well_scores/:id
    def update
      @well_score.set_display_value(params[:value])

      if @well_score.save
        render_success(serialize_well_score(@well_score))
      else
        render_error("Failed to update well score", 
                    status: :unprocessable_entity, 
                    details: @well_score.errors.full_messages)
      end
    end

    # DELETE /api/v1/plates/:plate_barcode/wells/:well_id/well_scores/:id
    def destroy
      if @well_score.destroy
        render_success({ message: "Well score deleted successfully" })
      else
        render_error("Failed to delete well score", 
                    status: :unprocessable_entity,
                    details: @well_score.errors.full_messages)
      end
    end

    private

    def set_plate_and_well
      @plate = Plate.find_by!(barcode: params[:plate_barcode])
      @well = @plate.wells.find(params[:well_id])
    end

    def set_well_score
      @well_score = @well.well_scores.find(params[:id])
    end

    def find_or_create_custom_attribute
      attribute_params = params[:custom_attribute] || {}
      
      if attribute_params[:id].present?
        CustomAttribute.find(attribute_params[:id])
      elsif attribute_params[:name].present?
        # Creating new attribute or finding existing by name
        existing_attr = CustomAttribute.find_by(name: attribute_params[:name])
        return existing_attr if existing_attr

        attr_data = {
          name: attribute_params[:name],
          description: attribute_params[:description],
          data_type: attribute_params[:data_type] || 'numeric'
        }

        CustomAttribute.create!(attr_data)
      else
        render_error("Custom attribute ID or name is required", status: :bad_request)
        nil
      end
    rescue ActiveRecord::RecordInvalid => e
      render_error("Failed to create custom attribute: #{e.message}", 
                  status: :unprocessable_entity,
                  details: e.record.errors.full_messages)
      nil
    end

    def add_attribute_to_other_wells(custom_attribute)
      # Get all well IDs that don't already have this custom attribute
      existing_well_ids = WellScore.joins(:well)
                                  .where(wells: { plate_id: @plate.id })
                                  .where(custom_attribute: custom_attribute)
                                  .pluck('wells.id')
      
      # Get well IDs that need the attribute added
      wells_needing_attribute = @plate.wells.where.not(id: existing_well_ids)
                                           .pluck(:id)
      
      # Bulk insert well scores for wells that don't have this attribute yet
      if wells_needing_attribute.any?
        timestamp = Time.current
        well_scores_to_insert = wells_needing_attribute.map do |well_id|
          {
            well_id: well_id,
            custom_attribute_id: custom_attribute.id,
            value: nil, # Start with null value
            created_at: timestamp,
            updated_at: timestamp
          }
        end
        
        begin
          WellScore.insert_all(well_scores_to_insert)
        rescue ActiveRecord::RecordNotUnique
          # Handle race condition where records might be created between our check and insert
          Rails.logger.warn "Some well scores already existed during bulk insert for custom_attribute #{custom_attribute.id}"
        end
      end
    end

    def serialize_well_score(score)
      {
        id: score.id,
        value: score.display_value,
        well_id: score.well_id,
        well_label: score.well.well_label_with_subwell,
        custom_attribute: {
          id: score.custom_attribute.id,
          name: score.custom_attribute.name,
          description: score.custom_attribute.description,
          data_type: score.custom_attribute.data_type
        },
        created_at: score.created_at,
        updated_at: score.updated_at
      }
    end
  end
end