class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.integer     :actor_id
      t.string      :kind
      t.references  :notifiable, :polymorphic => true
      t.timestamp   :created_at
    end

    add_index :notifications, [:notifiable_type, :notifiable_id]
    add_index :notifications, :actor_id
  end
end
