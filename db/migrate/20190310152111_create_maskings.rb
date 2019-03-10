class CreateMaskings < ActiveRecord::Migration
  def change
    create_table :maskings do |t|
      t.text :transformed_geojson
      t.text :original_gml
      t.text :original_ol_gml
      t.references :map

      t.timestamps
    end

    remove_column :maps, :mask_geojson, :text
  end
end
