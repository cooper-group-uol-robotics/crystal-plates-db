class PagesController < ApplicationController
  def home
  end

  def api_docs
    @markdown_content = File.read(Rails.root.join('API_DOCUMENTATION.md'))
  end
end
