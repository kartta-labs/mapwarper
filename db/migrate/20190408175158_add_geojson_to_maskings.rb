class AddGeojsonToMaskings < ActiveRecord::Migration
  def change
    add_column :maskings, :geojson, :text
  end
end
