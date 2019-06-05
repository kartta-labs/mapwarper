class AddOcrResultToMaps < ActiveRecord::Migration
  def change
    add_column :maps, :ocr_result, :text
  end
end
