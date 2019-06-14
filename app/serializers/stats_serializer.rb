class StatsSerializer < ActiveModel::Serializer
  attributes :whodunnit, :total_count, :map_count, :gcp_update_count, :gcp_create_count, :gcp_destroy_count
end


