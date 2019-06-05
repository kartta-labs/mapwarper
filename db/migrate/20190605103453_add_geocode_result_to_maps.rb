class AddGeocodeResultToMaps < ActiveRecord::Migration
  def change
    add_column :maps, :geocode_result, :text
  end
end
