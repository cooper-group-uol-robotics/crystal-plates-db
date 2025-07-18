class Api::V1::ChemicalsController < Api::V1::BaseController
  # GET /api/v1/chemicals/search
  def search
    query = params[:q]

    if query.blank?
      render json: []
      return
    end

    # Search by name, CAS, or barcode (using LIKE for SQLite compatibility)
    chemicals = Chemical.where(
      "name LIKE ? OR cas LIKE ? OR barcode LIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%"
    ).order(:name).limit(10)

    render json: chemicals.map { |chemical|
      {
        id: chemical.id,
        name: chemical.name,
        cas: chemical.cas,
        barcode: chemical.barcode,
        display_text: chemical_display_text(chemical)
      }
    }
  end

  private

  def chemical_display_text(chemical)
    parts = [ chemical.name ]
    parts << "CAS: #{chemical.cas}" if chemical.cas.present?
    parts << "Barcode: #{chemical.barcode}" if chemical.barcode.present?
    parts.join(" | ")
  end
end
