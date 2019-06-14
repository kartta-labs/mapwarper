class VersionSerializer < ActiveModel::Serializer
  attributes :id, :item_type, :index, :item_id, :event, :whodunnit, :created_at, :transaction_id
end


