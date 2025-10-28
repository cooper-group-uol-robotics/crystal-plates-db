class AddSciformationCookieSetting < ActiveRecord::Migration[8.0]
  def up
    # Add the sciformation cookie setting if it doesn't exist
    unless Setting.exists?(key: 'sciformation_cookie')
      Setting.create!(
        key: 'sciformation_cookie',
        value: 'not_configured',
        description: 'Cookie value for Sciformation API authentication (without SCIFORMATION= prefix)'
      )
    end
  end

  def down
    # Remove the sciformation cookie setting
    Setting.find_by(key: 'sciformation_cookie')&.destroy
  end
end
