# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20191123174639) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "audits", force: :cascade do |t|
    t.integer  "auditable_id"
    t.string   "auditable_type"
    t.integer  "user_id"
    t.string   "user_type"
    t.string   "username"
    t.string   "action"
    t.text     "audited_changes"
    t.integer  "version",         default: 0
    t.datetime "created_at"
    t.string   "comment"
    t.string   "remote_address"
    t.integer  "associated_id"
    t.string   "associated_type"
    t.string   "request_uuid"
  end

  add_index "audits", ["associated_id", "associated_type"], name: "associated_index", using: :btree
  add_index "audits", ["auditable_id", "auditable_type"], name: "auditable_index", using: :btree
  add_index "audits", ["created_at"], name: "index_audits_on_created_at", using: :btree
  add_index "audits", ["request_uuid"], name: "index_audits_on_request_uuid", using: :btree
  add_index "audits", ["user_id", "user_type"], name: "user_index", using: :btree

  create_table "client_applications", force: :cascade do |t|
    t.string   "name"
    t.string   "url"
    t.string   "support_url"
    t.string   "callback_url"
    t.string   "key",          limit: 20
    t.string   "secret",       limit: 40
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "client_applications", ["key"], name: "index_client_applications_on_key", unique: true, using: :btree

  create_table "comments", force: :cascade do |t|
    t.string   "title",            limit: 50, default: ""
    t.text     "comment",                     default: ""
    t.integer  "commentable_id"
    t.string   "commentable_type"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "comments", ["commentable_id"], name: "index_comments_on_commentable_id", using: :btree
  add_index "comments", ["commentable_type"], name: "index_comments_on_commentable_type", using: :btree
  add_index "comments", ["user_id"], name: "index_comments_on_user_id", using: :btree

  create_table "gcps", force: :cascade do |t|
    t.integer  "map_id"
    t.float    "x"
    t.float    "y"
    t.decimal  "lat",        precision: 15, scale: 10
    t.decimal  "lon",        precision: 15, scale: 10
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "soft",                                 default: false
    t.string   "name"
  end

  add_index "gcps", ["soft"], name: "index_gcps_on_soft", using: :btree

  create_table "groups", force: :cascade do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "creator_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "groups_maps", force: :cascade do |t|
    t.integer  "group_id"
    t.integer  "map_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "groups_maps", ["map_id", "group_id"], name: "index_groups_maps_on_map_id_and_group_id", unique: true, using: :btree
  add_index "groups_maps", ["map_id"], name: "index_groups_maps_on_map_id", using: :btree

  create_table "imports", force: :cascade do |t|
    t.string   "path"
    t.string   "name"
    t.string   "layer_title"
    t.string   "map_title_suffix"
    t.string   "map_description"
    t.string   "map_publisher"
    t.string   "map_author"
    t.string   "state"
    t.integer  "layer_id"
    t.integer  "uploader_user_id"
    t.integer  "user_id"
    t.integer  "file_count"
    t.integer  "imported_count"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status"
    t.boolean  "save_layer"
    t.string   "log_filename"
    t.string   "metadata_file_name"
    t.string   "metadata_content_type"
    t.integer  "metadata_file_size"
    t.datetime "metadata_updated_at"
    t.datetime "finished_at"
  end

  create_table "imports_layers", force: :cascade do |t|
    t.integer "import_id"
    t.integer "layer_id"
  end

  add_index "imports_layers", ["import_id"], name: "index_imports_layers_on_import_id", using: :btree
  add_index "imports_layers", ["layer_id"], name: "index_imports_layers_on_layer_id", using: :btree

  create_table "layers", force: :cascade do |t|
    t.string   "name"
    t.text     "description"
    t.string   "bbox"
    t.integer  "owner"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.string   "depicts_year",         limit: 4,                               default: ""
    t.integer  "maps_count",                                                   default: 0
    t.integer  "rectified_maps_count",                                         default: 0
    t.boolean  "is_visible",                                                   default: true
    t.string   "source_uri"
    t.geometry "bbox_geom",            limit: {:srid=>0, :type=>"st_polygon"}
    t.string   "unique_id"
    t.boolean  "published",                                                    default: false
  end

  add_index "layers", ["bbox_geom"], name: "index_layers_on_bbox_geom", using: :gist

  create_table "layers_maps", force: :cascade do |t|
    t.integer  "layer_id"
    t.integer  "map_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "layers_maps", ["layer_id"], name: "index_layers_maps_on_layer_id", using: :btree
  add_index "layers_maps", ["map_id"], name: "index_layers_maps_on_map_id", using: :btree

  create_table "maps", force: :cascade do |t|
    t.string   "title"
    t.text     "description"
    t.string   "filename"
    t.integer  "width"
    t.integer  "height"
    t.integer  "status"
    t.integer  "mask_status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "upload_file_name"
    t.string   "upload_content_type"
    t.integer  "upload_file_size"
    t.datetime "upload_file_updated_at"
    t.string   "bbox"
    t.string   "publisher"
    t.string   "authors"
    t.string   "scale"
    t.datetime "published_date"
    t.datetime "reprint_date"
    t.integer  "owner_id"
    t.boolean  "public",                                                                                   default: true
    t.boolean  "downloadable",                                                                             default: true
    t.string   "cached_tag_list"
    t.integer  "map_type",                                                                                 default: 1
    t.string   "source_uri"
    t.geometry "bbox_geom",              limit: {:srid=>0, :type=>"st_polygon"}
    t.decimal  "rough_lat",                                                      precision: 15, scale: 10
    t.decimal  "rough_lon",                                                      precision: 15, scale: 10
    t.geometry "rough_centroid",         limit: {:srid=>0, :type=>"st_point"}
    t.integer  "rough_zoom"
    t.integer  "rough_state"
    t.integer  "import_id"
    t.string   "publication_place"
    t.string   "subject_area"
    t.string   "unique_id"
    t.string   "metadata_projection"
    t.decimal  "metadata_lat",                                                   precision: 15, scale: 10
    t.decimal  "metadata_lon",                                                   precision: 15, scale: 10
    t.string   "date_depicted",          limit: 4,                                                         default: ""
    t.string   "call_number"
    t.datetime "rectified_at"
    t.datetime "gcp_touched_at"
    t.integer  "issue_year"
    t.boolean  "protect",                                                                                  default: false
    t.text     "ocr_result"
    t.text     "geocode_result"
  end

  add_index "maps", ["bbox_geom"], name: "index_maps_on_bbox_geom", using: :gist
  add_index "maps", ["rough_centroid"], name: "index_maps_on_rough_centroid", using: :gist

  create_table "maskings", force: :cascade do |t|
    t.text     "transformed_geojson"
    t.text     "original_gml"
    t.text     "original_ol_gml"
    t.integer  "map_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "geojson"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "memberships", ["user_id", "group_id"], name: "index_memberships_on_user_id_and_group_id", unique: true, using: :btree
  add_index "memberships", ["user_id"], name: "index_memberships_on_user_id", using: :btree

  create_table "my_maps", force: :cascade do |t|
    t.integer  "map_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "my_maps", ["map_id", "user_id"], name: "index_my_maps_on_map_id_and_user_id", unique: true, using: :btree
  add_index "my_maps", ["map_id"], name: "index_my_maps_on_map_id", using: :btree

  create_table "notifications", force: :cascade do |t|
    t.integer  "actor_id"
    t.string   "kind"
    t.integer  "notifiable_id"
    t.string   "notifiable_type"
    t.datetime "created_at"
  end

  add_index "notifications", ["actor_id"], name: "index_notifications_on_actor_id", using: :btree
  add_index "notifications", ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id", using: :btree

  create_table "oauth_nonces", force: :cascade do |t|
    t.string   "nonce"
    t.integer  "timestamp"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "oauth_nonces", ["nonce", "timestamp"], name: "index_oauth_nonces_on_nonce_and_timestamp", unique: true, using: :btree

  create_table "oauth_tokens", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "type",                  limit: 20
    t.integer  "client_application_id"
    t.string   "token",                 limit: 20
    t.string   "secret",                limit: 40
    t.string   "callback_url"
    t.string   "verifier",              limit: 20
    t.datetime "authorized_at"
    t.datetime "invalidated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "oauth_tokens", ["token"], name: "index_oauth_tokens_on_token", unique: true, using: :btree

  create_table "permissions", force: :cascade do |t|
    t.integer  "role_id",    null: false
    t.integer  "user_id",    null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text     "content"
    t.integer  "searchable_id"
    t.string   "searchable_type"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "pg_search_documents", ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable_type_and_searchable_id", using: :btree

  create_table "roles", force: :cascade do |t|
    t.string   "name"
    t.integer  "updated_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "taggings", force: :cascade do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.datetime "created_at"
    t.string   "context",       limit: 128
    t.integer  "tagger_id"
    t.string   "tagger_type"
  end

  add_index "taggings", ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true, using: :btree
  add_index "taggings", ["taggable_id", "taggable_type"], name: "index_taggings_on_taggable_id_and_taggable_type", using: :btree

  create_table "tags", force: :cascade do |t|
    t.string  "name"
    t.integer "taggings_count", default: 0
  end

  create_table "user_warnings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "user_id"
    t.string   "category"
    t.string   "status"
    t.text     "note"
  end

  add_index "user_warnings", ["user_id"], name: "index_user_warnings_on_user_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "login"
    t.string   "email"
    t.string   "encrypted_password",        limit: 128, default: "",   null: false
    t.string   "password_salt",                         default: "",   null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "remember_token"
    t.datetime "remember_token_expires_at"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.string   "reset_password_token"
    t.boolean  "enabled",                               default: true
    t.integer  "updated_by"
    t.text     "description",                           default: ""
    t.datetime "confirmation_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                         default: 0,    null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "reset_password_sent_at"
    t.string   "provider"
    t.string   "uid"
    t.string   "authentication_token",      limit: 30
    t.integer  "own_maps_count"
    t.integer  "upload_filesize_sum",       limit: 8
    t.integer  "disk_usage",                limit: 8
  end

  add_index "users", ["authentication_token"], name: "index_users_on_authentication_token", unique: true, using: :btree

  create_table "version_associations", force: :cascade do |t|
    t.integer "version_id"
    t.string  "foreign_key_name", null: false
    t.integer "foreign_key_id"
    t.string  "foreign_type"
  end

  add_index "version_associations", ["foreign_key_name", "foreign_key_id"], name: "index_version_associations_on_foreign_key", using: :btree
  add_index "version_associations", ["version_id"], name: "index_version_associations_on_version_id", using: :btree

  create_table "versions", force: :cascade do |t|
    t.string   "item_type",      null: false
    t.integer  "item_id",        null: false
    t.string   "event",          null: false
    t.string   "whodunnit"
    t.text     "object"
    t.datetime "created_at"
    t.string   "ip"
    t.integer  "user_id"
    t.string   "user_agent"
    t.text     "object_changes"
    t.integer  "transaction_id"
    t.string   "whodeadit"
  end

  add_index "versions", ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id", using: :btree
  add_index "versions", ["transaction_id"], name: "index_versions_on_transaction_id", using: :btree

end
