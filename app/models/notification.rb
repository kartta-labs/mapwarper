class Notification < ActiveRecord::Base
  belongs_to :actor, class_name: "User"
  belongs_to :notifiable, polymorphic: true

  scope :latest, ->{ where("created_at > ?", Time.now - 10.minutes) }
end