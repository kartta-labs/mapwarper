class AddWhodeaditToVersions < ActiveRecord::Migration
  def change
    add_column :versions, :whodeadit, :string
  end
end
