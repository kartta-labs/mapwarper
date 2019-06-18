class NotificationSerializer < ActiveModel::Serializer
  include ActionView::Helpers::DateHelper
  
  belongs_to :actor, :class_name => "User",  :key => :by
  has_one :notifiable, polymorphic: true

  attributes  :id, :kind, :created_at, :when

  def when
    time_ago_in_words(object.created_at)
  end

  class UserSerializer < ActiveModel::Serializer
    attributes :name
    def name
      object.login.titlecase
    end
  end

  class MapSerializer < ActiveModel::Serializer
    attributes :id
  end

  class GcpSerializer < ActiveModel::Serializer
    attributes :id
  end
  

end
