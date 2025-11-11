module Api::V1
  class CustomAttributesController < BaseController
    before_action :set_plate, only: [:index, :create, :destroy, :add_to_all_wells]
    before_action :set_custom_attribute, only: [:update, :destroy, :add_to_all_wells]

    # GET /api/v1/custom_attributes
    # GET /api/v1/plates/:barcode/custom_attributes
    def index
      if @plate
        # For plate-specific listing, return attributes that have well scores in the plate
        attributes = CustomAttribute.with_well_scores_in_plate(@plate)
                                     .includes(:well_scores)
                                     .order(:name)
      else
        attributes = CustomAttribute.includes(:well_scores).order(:name)
      end

      render_success(attributes.map { |attr| serialize_custom_attribute(attr) })
    end

    # GET /api/v1/custom_attributes/global
    def global
      attributes = CustomAttribute.includes(:well_scores).order(:name)
      render_success(attributes.map { |attr| serialize_custom_attribute(attr) })
    end

    # GET /api/v1/custom_attributes/search?q=term
    def search
      term = params[:q]
      return render_error("Search term is required", status: :bad_request) if term.blank?

      attributes = CustomAttribute.where("name ILIKE ?", "%#{term}%")
                                 .limit(20)
                                 .order(:name)

      suggestions = attributes.map do |attr|
        {
          id: attr.id,
          name: attr.name,
          description: attr.description
        }
      end

      render_success(suggestions)
    end

    # POST /api/v1/custom_attributes
    # POST /api/v1/plates/:barcode/custom_attributes
    def create
      # Always create global attributes now
  attribute = CustomAttribute.new(custom_attribute_params)

      if attribute.save
        render_success(serialize_custom_attribute(attribute), status: :created)
      else
        render_error("Failed to create custom attribute", 
                    status: :unprocessable_entity, 
                    details: attribute.errors.full_messages)
      end
    end

    # PATCH/PUT /api/v1/custom_attributes/:id
    def update
      if @custom_attribute.update(custom_attribute_params)
        render_success(serialize_custom_attribute(@custom_attribute))
      else
        render_error("Failed to update custom attribute", 
                    status: :unprocessable_entity, 
                    details: @custom_attribute.errors.full_messages)
      end
    end

    # DELETE /api/v1/custom_attributes/:id
    # DELETE /api/v1/plates/:barcode/custom_attributes/:id
    def destroy
      if @custom_attribute.destroy
        render_success({ message: "Custom attribute deleted successfully" })
      else
        render_error("Failed to delete custom attribute", 
                    status: :unprocessable_entity,
                    details: @custom_attribute.errors.full_messages)
      end
    end

    # POST /api/v1/plates/:barcode/custom_attributes/:id/add_to_all_wells
    def add_to_all_wells
      return render_error("Plate is required for this action", status: :bad_request) unless @plate

      begin
        # Get all well IDs that don't already have this custom attribute
        existing_well_ids = WellScore.joins(:well)
                                    .where(wells: { plate_id: @plate.id })
                                    .where(custom_attribute: @custom_attribute)
                                    .pluck('wells.id')
        
        # Get well IDs that need the attribute added
        wells_needing_attribute = @plate.wells.where.not(id: existing_well_ids)
                                             .pluck(:id)
        
        wells_added = 0
        
        # Bulk insert well scores for wells that don't have this attribute yet
        if wells_needing_attribute.any?
          timestamp = Time.current
          well_scores_to_insert = wells_needing_attribute.map do |well_id|
            {
              well_id: well_id,
              custom_attribute_id: @custom_attribute.id,
              value: nil, # Start with null value
              created_at: timestamp,
              updated_at: timestamp
            }
          end
          
          begin
            WellScore.insert_all(well_scores_to_insert)
            wells_added = wells_needing_attribute.count
          rescue ActiveRecord::RecordNotUnique
            # Handle race condition where records might be created between our check and insert
            Rails.logger.warn "Some well scores already existed during bulk insert for custom_attribute #{@custom_attribute.id}"
            wells_added = wells_needing_attribute.count # Approximate count
          end
        end

        render_success({
          message: "Custom attribute added to #{wells_added} wells",
          attribute: serialize_custom_attribute(@custom_attribute),
          wells_added: wells_added
        })
      rescue => e
        render_error("Failed to add attribute to wells: #{e.message}", 
                    status: :internal_server_error)
      end
    end

    private

    def set_plate
      if params[:plate_barcode]
        @plate = Plate.find_by!(barcode: params[:plate_barcode])
      end
    end

    def set_custom_attribute
      @custom_attribute = CustomAttribute.find(params[:id])
    end

    def custom_attribute_params
      params.require(:custom_attribute).permit(:name, :description, :data_type)
    end

    def serialize_custom_attribute(attribute)
      {
        id: attribute.id,
        name: attribute.name,
        description: attribute.description,
        data_type: attribute.data_type,
        wells_count: attribute.well_scores.count,
        statistics: @plate ? attribute.statistics_for_plate(@plate) : {},
        created_at: attribute.created_at,
        updated_at: attribute.updated_at
      }
    end
  end
end