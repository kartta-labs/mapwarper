class AddUniqueIdToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :unique_id, :string
  end
end
