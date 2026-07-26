# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_17_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "unaccent"

  create_table "access_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.inet "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.uuid "organization_id", null: false
    t.uuid "recorded_by_person_id"
    t.uuid "residential_property_id", null: false
    t.string "result", default: "success", null: false
    t.string "source", default: "web", null: false
    t.uuid "staff_shift_id"
    t.uuid "unit_id"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.uuid "vehicle_id"
    t.uuid "visit_id"
    t.uuid "visit_participant_id"
    t.uuid "visitor_profile_id"
    t.index ["metadata"], name: "index_access_events_on_metadata", using: :gin
    t.index ["organization_id", "event_type", "result", "occurred_at"], name: "index_access_events_on_org_type_result_occurred_at"
    t.index ["organization_id", "residential_property_id", "occurred_at"], name: "index_access_events_on_org_property_occurred_at"
    t.index ["organization_id", "unit_id", "occurred_at"], name: "index_access_events_on_org_unit_occurred_at"
    t.index ["organization_id", "visit_id", "occurred_at"], name: "index_access_events_on_org_visit_occurred_at"
    t.index ["organization_id"], name: "index_access_events_on_organization_id"
    t.index ["recorded_by_person_id"], name: "index_access_events_on_recorded_by_person_id"
    t.index ["residential_property_id"], name: "index_access_events_on_residential_property_id"
    t.index ["unit_id"], name: "index_access_events_on_unit_id"
    t.index ["vehicle_id"], name: "index_access_events_on_vehicle_id"
    t.index ["visit_id"], name: "index_access_events_on_visit_id"
    t.index ["visit_participant_id"], name: "index_access_events_on_visit_participant_id"
    t.index ["visitor_profile_id"], name: "index_access_events_on_visitor_profile_id"
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "organization_id"
    t.jsonb "properties"
    t.datetime "time"
    t.uuid "user_id"
    t.uuid "visit_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["organization_id", "name", "time"], name: "index_ahoy_events_on_org_name_time"
    t.index ["organization_id"], name: "index_ahoy_events_on_organization_id"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "app_version"
    t.string "browser"
    t.string "city"
    t.string "country"
    t.string "device_type"
    t.string "ip"
    t.text "landing_page"
    t.float "latitude"
    t.float "longitude"
    t.uuid "organization_id"
    t.string "os"
    t.string "os_version"
    t.string "platform"
    t.text "referrer"
    t.string "referring_domain"
    t.string "region"
    t.datetime "started_at"
    t.text "user_agent"
    t.uuid "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.index ["organization_id", "started_at"], name: "index_ahoy_visits_on_org_started_at"
    t.index ["organization_id"], name: "index_ahoy_visits_on_organization_id"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "announcement_reads", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.uuid "announcement_id", null: false
    t.string "channel"
    t.datetime "created_at", null: false
    t.jsonb "device_info", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "notified_at"
    t.uuid "organization_id", null: false
    t.uuid "person_id"
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.index ["announcement_id"], name: "index_announcement_reads_on_announcement_id"
    t.index ["device_info"], name: "index_announcement_reads_on_device_info", using: :gin
    t.index ["metadata"], name: "index_announcement_reads_on_metadata", using: :gin
    t.index ["organization_id", "announcement_id", "person_id"], name: "index_announcement_reads_unique_per_person_when_present", unique: true, where: "(person_id IS NOT NULL)"
    t.index ["organization_id", "announcement_id", "read_at"], name: "index_announcement_reads_on_org_announcement_read_at"
    t.index ["organization_id", "person_id", "read_at"], name: "index_announcement_reads_on_org_person_read_at"
    t.index ["organization_id"], name: "index_announcement_reads_on_organization_id"
    t.index ["person_id"], name: "index_announcement_reads_on_person_id"
  end

  create_table "announcement_targets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "announcement_id", null: false
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.uuid "target_id", null: false
    t.jsonb "target_rule", default: {}, null: false
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.index ["announcement_id"], name: "index_announcement_targets_on_announcement_id"
    t.index ["organization_id", "announcement_id"], name: "idx_on_organization_id_announcement_id_fddacab166"
    t.index ["organization_id", "target_type", "target_id"], name: "index_announcement_targets_on_org_target"
    t.index ["organization_id"], name: "index_announcement_targets_on_organization_id"
    t.index ["target_rule"], name: "index_announcement_targets_on_target_rule", using: :gin
  end

  create_table "announcements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "author_person_id", null: false
    t.string "category"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "expires_at"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.string "priority", default: "normal", null: false
    t.datetime "published_at"
    t.boolean "requires_acknowledgement", default: false
    t.uuid "residential_property_id", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["author_person_id"], name: "index_announcements_on_author_person_id"
    t.index ["deleted_at"], name: "index_announcements_on_deleted_at"
    t.index ["metadata"], name: "index_announcements_on_metadata", using: :gin
    t.index ["organization_id", "author_person_id"], name: "index_announcements_on_organization_id_and_author_person_id"
    t.index ["organization_id", "priority"], name: "index_announcements_on_organization_id_and_priority"
    t.index ["organization_id", "residential_property_id", "status", "published_at"], name: "index_announcements_on_org_property_status_published_at"
    t.index ["organization_id"], name: "index_announcements_on_organization_id"
    t.index ["residential_property_id"], name: "index_announcements_on_residential_property_id"
  end

  create_table "audits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action"
    t.uuid "associated_id"
    t.string "associated_type"
    t.uuid "auditable_id"
    t.string "auditable_type"
    t.text "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.uuid "organization_id"
    t.string "remote_address"
    t.string "request_uuid"
    t.uuid "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "organization_id", "version"], name: "index_audits_on_auditable_org_version"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["organization_id", "auditable_type", "auditable_id", "created_at"], name: "index_audits_on_org_auditable_created_at"
    t.index ["organization_id"], name: "index_audits_on_organization_id"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "authorized_residents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "authorized_by_person_id"
    t.boolean "can_authorize_visits", default: false, null: false
    t.boolean "can_reserve_common_areas", default: false, null: false
    t.boolean "can_withdraw_parcels", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.uuid "organization_id", null: false
    t.uuid "person_id", null: false
    t.string "relationship_type", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "pending", null: false
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["metadata"], name: "index_authorized_residents_on_metadata", using: :gin
    t.index ["organization_id", "authorized_by_person_id"], name: "index_authorized_residents_on_org_authorized_by_person_id"
    t.index ["organization_id", "person_id", "status"], name: "index_authorized_residents_on_org_person_status"
    t.index ["organization_id", "unit_id", "status"], name: "index_authorized_residents_on_org_unit_status"
    t.index ["organization_id"], name: "index_authorized_residents_on_organization_id"
    t.index ["person_id"], name: "index_authorized_residents_on_person_id"
    t.index ["unit_id"], name: "index_authorized_residents_on_unit_id"
    t.check_constraint "ends_at IS NULL OR ends_at >= starts_at", name: "authorized_residents_date_range_valid"
  end

  create_table "bulk_import_rows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "bulk_import_id", null: false
    t.datetime "created_at", null: false
    t.datetime "failed_at"
    t.text "failure_message"
    t.string "group_key"
    t.string "import_status", default: "pending", null: false
    t.datetime "imported_at"
    t.jsonb "normalized_payload", default: {}, null: false
    t.string "onboarding_classification"
    t.string "operation"
    t.jsonb "raw_payload", default: {}, null: false
    t.integer "row_number", null: false
    t.string "sheet_name"
    t.datetime "skipped_at"
    t.uuid "target_record_id"
    t.string "target_record_type"
    t.datetime "updated_at", null: false
    t.datetime "validated_at"
    t.jsonb "validation_errors", default: [], null: false
    t.string "validation_status", default: "pending", null: false
    t.jsonb "validation_warnings", default: [], null: false
    t.index ["bulk_import_id", "group_key"], name: "index_bulk_import_rows_on_bulk_import_id_and_group_key"
    t.index ["bulk_import_id", "import_status"], name: "index_bulk_import_rows_on_bulk_import_id_and_import_status"
    t.index ["bulk_import_id", "row_number"], name: "index_bulk_import_rows_on_bulk_import_id_and_row_number", unique: true
    t.index ["bulk_import_id", "validation_status"], name: "index_bulk_import_rows_on_bulk_import_id_and_validation_status"
    t.index ["bulk_import_id"], name: "index_bulk_import_rows_on_bulk_import_id"
    t.index ["normalized_payload"], name: "index_bulk_import_rows_on_normalized_payload", using: :gin
    t.index ["raw_payload"], name: "index_bulk_import_rows_on_raw_payload", using: :gin
    t.index ["row_number"], name: "index_bulk_import_rows_on_row_number"
    t.index ["target_record_type", "target_record_id"], name: "idx_on_target_record_type_target_record_id_ce961e50be"
  end

  create_table "bulk_imports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "cancelled_at"
    t.datetime "confirmed_at"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.uuid "created_by_id", null: false
    t.integer "error_rows", default: 0, null: false
    t.datetime "expires_at"
    t.integer "failed_rows", default: 0, null: false
    t.text "failure_message"
    t.string "file_checksum"
    t.bigint "file_size"
    t.datetime "finished_at"
    t.string "import_type", null: false
    t.integer "imported_rows", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.string "original_filename"
    t.datetime "processing_started_at"
    t.uuid "property_section_id"
    t.uuid "residential_property_id"
    t.integer "skipped_rows", default: 0, null: false
    t.string "status", default: "draft", null: false
    t.jsonb "summary", default: {}, null: false
    t.integer "total_rows", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "valid_rows", default: 0, null: false
    t.datetime "validated_at"
    t.integer "warning_rows", default: 0, null: false
    t.index ["created_at"], name: "index_bulk_imports_on_created_at"
    t.index ["created_by_id"], name: "index_bulk_imports_on_created_by_id"
    t.index ["expires_at"], name: "index_bulk_imports_on_expires_at"
    t.index ["file_checksum"], name: "index_bulk_imports_on_file_checksum"
    t.index ["import_type"], name: "index_bulk_imports_on_import_type"
    t.index ["metadata"], name: "index_bulk_imports_on_metadata", using: :gin
    t.index ["organization_id", "created_at"], name: "index_bulk_imports_on_organization_id_and_created_at"
    t.index ["organization_id", "import_type"], name: "index_bulk_imports_on_organization_id_and_import_type"
    t.index ["organization_id", "status"], name: "index_bulk_imports_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_bulk_imports_on_organization_id"
    t.index ["property_section_id"], name: "index_bulk_imports_on_property_section_id"
    t.index ["residential_property_id"], name: "index_bulk_imports_on_residential_property_id"
    t.index ["status"], name: "index_bulk_imports_on_status"
    t.index ["summary"], name: "index_bulk_imports_on_summary", using: :gin
  end

  create_table "common_area_reservation_status_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "changed_by_person_id"
    t.uuid "common_area_reservation_id", null: false
    t.datetime "created_at", null: false
    t.string "from_status"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.text "reason"
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_person_id"], name: "idx_on_changed_by_person_id_882d57421f"
    t.index ["common_area_reservation_id"], name: "idx_on_common_area_reservation_id_f6c327d821"
    t.index ["metadata"], name: "index_common_area_reservation_status_histories_on_metadata", using: :gin
    t.index ["organization_id", "changed_by_person_id"], name: "idx_c_area_res_status_histories_on_org_changed_by"
    t.index ["organization_id", "common_area_reservation_id", "created_at"], name: "idx_c_area_res_status_histories_on_org_res_created"
    t.index ["organization_id"], name: "idx_on_organization_id_e7e8651341"
  end

  create_table "common_area_reservations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "approved_at"
    t.uuid "approved_by_person_id"
    t.uuid "common_area_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.integer "guest_count", default: 0
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.text "rejection_reason"
    t.uuid "requested_by_person_id", null: false
    t.uuid "residential_property_id", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "pending", null: false
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_person_id"], name: "index_common_area_reservations_on_approved_by_person_id"
    t.index ["common_area_id"], name: "index_common_area_reservations_on_common_area_id"
    t.index ["metadata"], name: "index_common_area_reservations_on_metadata", using: :gin
    t.index ["organization_id", "approved_by_person_id"], name: "index_common_area_reservations_on_org_approved_by_person"
    t.index ["organization_id", "common_area_id", "starts_at", "ends_at"], name: "index_common_area_reservations_on_org_area_time_range"
    t.index ["organization_id", "requested_by_person_id", "status"], name: "index_common_area_reservations_on_org_requester_status"
    t.index ["organization_id", "status"], name: "index_common_area_reservations_on_organization_id_and_status"
    t.index ["organization_id", "unit_id", "status"], name: "idx_on_organization_id_unit_id_status_00945a979c"
    t.index ["organization_id"], name: "index_common_area_reservations_on_organization_id"
    t.index ["requested_by_person_id"], name: "index_common_area_reservations_on_requested_by_person_id"
    t.index ["residential_property_id"], name: "index_common_area_reservations_on_residential_property_id"
    t.index ["unit_id"], name: "index_common_area_reservations_on_unit_id"
    t.check_constraint "ends_at > starts_at", name: "common_area_reservations_time_range_valid"
    t.exclusion_constraint "organization_id WITH =, common_area_id WITH =, tsrange(starts_at, ends_at, '[)'::text) WITH &&", where: "(status)::text = ANY (ARRAY[('pending'::character varying)::text, ('approved'::character varying)::text])", using: :gist, name: "common_area_reservations_no_overlap"
  end

  create_table "common_area_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "common_area_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.integer "position"
    t.string "rule_type", null: false
    t.datetime "updated_at", null: false
    t.integer "value_int"
    t.text "value_text"
    t.index ["common_area_id"], name: "index_common_area_rules_on_common_area_id"
    t.index ["metadata"], name: "index_common_area_rules_on_metadata", using: :gin
    t.index ["organization_id", "common_area_id", "rule_type"], name: "index_common_area_rules_unique_per_area_type", unique: true
    t.index ["organization_id", "rule_type"], name: "index_common_area_rules_on_org_rule_type"
    t.index ["organization_id"], name: "index_common_area_rules_on_organization_id"
    t.check_constraint "value_int IS NOT NULL OR value_text IS NOT NULL", name: "common_area_rules_value_present"
  end

  create_table "common_areas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "area_type", null: false
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.boolean "requires_approval", default: true, null: false
    t.uuid "residential_property_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_common_areas_on_deleted_at"
    t.index ["metadata"], name: "index_common_areas_on_metadata", using: :gin
    t.index ["organization_id", "residential_property_id", "name"], name: "index_common_areas_unique_name_per_property_when_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id", "residential_property_id", "status"], name: "idx_on_organization_id_residential_property_id_stat_8348429f7a"
    t.index ["organization_id"], name: "index_common_areas_on_organization_id"
    t.index ["residential_property_id"], name: "index_common_areas_on_residential_property_id"
  end

  create_table "device_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_seen_at"
    t.string "platform", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_device_tokens_on_user_id", unique: true
  end

  create_table "documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.uuid "documentable_id", null: false
    t.string "documentable_type", null: false
    t.datetime "expires_at"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.boolean "sensitive", default: false, null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "uploaded_by_person_id"
    t.string "visibility", default: "private", null: false
    t.index ["deleted_at"], name: "index_documents_on_deleted_at"
    t.index ["metadata"], name: "index_documents_on_metadata", using: :gin
    t.index ["organization_id", "category"], name: "index_documents_on_organization_id_and_category"
    t.index ["organization_id", "documentable_type", "documentable_id"], name: "index_documents_on_org_documentable"
    t.index ["organization_id", "sensitive"], name: "index_documents_on_organization_id_and_sensitive"
    t.index ["organization_id", "status", "expires_at"], name: "index_documents_on_org_status_expires_at"
    t.index ["organization_id", "uploaded_by_person_id"], name: "index_documents_on_org_uploaded_by_person"
    t.index ["organization_id"], name: "index_documents_on_organization_id"
    t.index ["uploaded_by_person_id"], name: "index_documents_on_uploaded_by_person_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "icons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_icons_on_name", unique: true
  end

  create_table "incident_status_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "changed_by_person_id"
    t.datetime "created_at", null: false
    t.string "from_status"
    t.uuid "incident_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.text "reason"
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_person_id"], name: "index_incident_status_histories_on_changed_by_person_id"
    t.index ["incident_id"], name: "index_incident_status_histories_on_incident_id"
    t.index ["metadata"], name: "index_incident_status_histories_on_metadata", using: :gin
    t.index ["organization_id", "changed_by_person_id"], name: "index_incident_status_histories_on_org_changed_by_person"
    t.index ["organization_id", "incident_id", "created_at"], name: "index_incident_status_histories_on_org_incident_created_at"
    t.index ["organization_id"], name: "index_incident_status_histories_on_organization_id"
  end

  create_table "incidents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "assigned_to_person_id"
    t.string "category", null: false
    t.uuid "common_area_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at"
    t.uuid "organization_id", null: false
    t.uuid "parcel_delivery_id"
    t.string "priority", default: "normal", null: false
    t.uuid "reported_by_person_id"
    t.uuid "residential_property_id", null: false
    t.text "resolution"
    t.datetime "resolved_at"
    t.string "status", default: "open", null: false
    t.uuid "unit_id"
    t.datetime "updated_at", null: false
    t.uuid "vehicle_id"
    t.uuid "visit_id"
    t.index ["assigned_to_person_id"], name: "index_incidents_on_assigned_to_person_id"
    t.index ["common_area_id"], name: "index_incidents_on_common_area_id"
    t.index ["deleted_at"], name: "index_incidents_on_deleted_at"
    t.index ["metadata"], name: "index_incidents_on_metadata", using: :gin
    t.index ["organization_id", "assigned_to_person_id", "status"], name: "index_incidents_on_org_assigned_person_status"
    t.index ["organization_id", "reported_by_person_id"], name: "index_incidents_on_org_reported_by_person"
    t.index ["organization_id", "residential_property_id", "status", "priority", "occurred_at"], name: "index_incidents_on_org_property_status_priority_occurred"
    t.index ["organization_id", "unit_id", "occurred_at"], name: "index_incidents_on_organization_id_and_unit_id_and_occurred_at"
    t.index ["organization_id"], name: "index_incidents_on_organization_id"
    t.index ["parcel_delivery_id"], name: "index_incidents_on_parcel_delivery_id"
    t.index ["reported_by_person_id"], name: "index_incidents_on_reported_by_person_id"
    t.index ["residential_property_id"], name: "index_incidents_on_residential_property_id"
    t.index ["unit_id"], name: "index_incidents_on_unit_id"
    t.index ["vehicle_id"], name: "index_incidents_on_vehicle_id"
    t.index ["visit_id"], name: "index_incidents_on_visit_id"
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "lease_contracts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "can_authorize_visits", default: true, null: false
    t.boolean "can_reserve_common_areas", default: true, null: false
    t.boolean "can_withdraw_parcels", default: true, null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_person_id"
    t.date "ends_at"
    t.uuid "lessee_person_id", null: false
    t.uuid "lessor_person_id"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.date "starts_at", null: false
    t.string "status", default: "draft", null: false
    t.uuid "terminated_by_person_id"
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_person_id"], name: "index_lease_contracts_on_created_by_person_id"
    t.index ["lessee_person_id"], name: "index_lease_contracts_on_lessee_person_id"
    t.index ["lessor_person_id"], name: "index_lease_contracts_on_lessor_person_id"
    t.index ["metadata"], name: "index_lease_contracts_on_metadata", using: :gin
    t.index ["organization_id", "lessee_person_id", "status"], name: "index_lease_contracts_on_org_lessee_person_status"
    t.index ["organization_id", "status", "ends_at"], name: "index_lease_contracts_on_org_status_ends_at"
    t.index ["organization_id", "unit_id", "starts_at", "ends_at"], name: "index_lease_contracts_on_org_unit_date_range"
    t.index ["organization_id", "unit_id"], name: "index_lease_contracts_on_org_unit_unique_when_active", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["organization_id"], name: "index_lease_contracts_on_organization_id"
    t.index ["terminated_by_person_id"], name: "index_lease_contracts_on_terminated_by_person_id"
    t.index ["unit_id"], name: "index_lease_contracts_on_unit_id"
    t.check_constraint "ends_at IS NULL OR ends_at >= starts_at", name: "lease_contracts_date_range_valid"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempts_count", default: 0, null: false
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.text "last_error"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.string "notification_type", null: false
    t.uuid "organization_id", null: false
    t.datetime "read_at"
    t.uuid "recipient_person_id", null: false
    t.uuid "residential_property_id"
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.uuid "unit_id"
    t.datetime "updated_at", null: false
    t.index ["metadata"], name: "index_notifications_on_metadata", using: :gin
    t.index ["organization_id", "channel", "status", "created_at"], name: "index_notifications_on_org_channel_pending_status", where: "((status)::text = 'pending'::text)"
    t.index ["organization_id", "notifiable_type", "notifiable_id"], name: "index_notifications_on_org_notifiable"
    t.index ["organization_id", "recipient_person_id", "read_at"], name: "index_notifications_on_org_recipient_read_at"
    t.index ["organization_id", "recipient_person_id", "status", "created_at"], name: "index_notifications_on_org_recipient_status_created_at"
    t.index ["organization_id"], name: "index_notifications_on_organization_id"
    t.index ["recipient_person_id"], name: "index_notifications_on_recipient_person_id"
    t.index ["residential_property_id"], name: "index_notifications_on_residential_property_id"
    t.index ["unit_id"], name: "index_notifications_on_unit_id"
    t.check_constraint "recipient_person_id IS NOT NULL", name: "notifications_recipient_person_required"
  end

  create_table "onboarding_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "conflict_reason"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "expires_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.uuid "person_id"
    t.uuid "requested_by_person_id"
    t.string "requested_relationship", null: false
    t.jsonb "requested_roles", default: [], null: false
    t.uuid "residential_property_id"
    t.string "status", default: "pending", null: false
    t.string "token_digest"
    t.uuid "unit_id"
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["deleted_at"], name: "index_onboarding_requests_on_deleted_at"
    t.index ["organization_id", "person_id", "requested_relationship", "residential_property_id", "unit_id"], name: "idx_onboarding_requests_unique_pending_scope", unique: true, where: "(((status)::text = 'pending'::text) AND (deleted_at IS NULL))"
    t.index ["organization_id"], name: "index_onboarding_requests_on_organization_id"
    t.index ["person_id"], name: "index_onboarding_requests_on_person_id"
    t.index ["requested_by_person_id"], name: "index_onboarding_requests_on_requested_by_person_id"
    t.index ["residential_property_id"], name: "index_onboarding_requests_on_residential_property_id"
    t.index ["status"], name: "index_onboarding_requests_on_status"
    t.index ["token_digest"], name: "idx_onboarding_requests_unique_token_digest", unique: true, where: "(token_digest IS NOT NULL)"
    t.index ["unit_id"], name: "index_onboarding_requests_on_unit_id"
    t.index ["user_id"], name: "index_onboarding_requests_on_user_id"
  end

  create_table "organization_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "joined_at"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.uuid "person_id", null: false
    t.datetime "revoked_at"
    t.string "status", default: "invited", null: false
    t.datetime "suspended_at"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_organization_memberships_on_deleted_at"
    t.index ["metadata"], name: "index_organization_memberships_on_metadata", using: :gin
    t.index ["organization_id", "person_id"], name: "idx_org_memberships_unique_active_invited", unique: true, where: "(((status)::text = ANY (ARRAY[('invited'::character varying)::text, ('active'::character varying)::text])) AND (deleted_at IS NULL))"
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["person_id"], name: "index_organization_memberships_on_person_id"
    t.index ["status"], name: "index_organization_memberships_on_status"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "country_code", default: "CL", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "legal_name"
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "plan", default: "free", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "status", default: "active", null: false
    t.string "subdomain"
    t.text "tax_identifier_ciphertext"
    t.string "tax_identifier_digest"
    t.string "tax_identifier_type", default: "rut", null: false
    t.datetime "updated_at", null: false
    t.index ["country_code", "tax_identifier_type", "tax_identifier_digest"], name: "idx_organizations_unique_tax_identifier", unique: true, where: "((tax_identifier_digest IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["deleted_at"], name: "index_organizations_on_deleted_at"
    t.index ["metadata"], name: "index_organizations_on_metadata", using: :gin
    t.index ["plan"], name: "index_organizations_on_plan"
    t.index ["settings"], name: "index_organizations_on_settings", using: :gin
    t.index ["status"], name: "index_organizations_on_status"
    t.index ["subdomain"], name: "index_organizations_on_subdomain", unique: true
  end

  create_table "parcel_deliveries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "courier_company"
    t.datetime "created_at", null: false
    t.string "delivery_type", default: "parcel", null: false
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.datetime "notified_at"
    t.uuid "organization_id", null: false
    t.datetime "received_at", null: false
    t.uuid "received_by_person_id"
    t.uuid "recipient_person_id"
    t.uuid "residential_property_id", null: false
    t.uuid "staff_shift_id"
    t.string "status", default: "received", null: false
    t.string "tracking_code"
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "withdrawn_at"
    t.uuid "withdrawn_by_person_id"
    t.index ["metadata"], name: "index_parcel_deliveries_on_metadata", using: :gin
    t.index ["organization_id", "received_by_person_id"], name: "index_parcel_deliveries_on_org_received_by_person"
    t.index ["organization_id", "residential_property_id", "status", "received_at"], name: "index_parcel_deliveries_on_org_property_status_received_at"
    t.index ["organization_id", "staff_shift_id"], name: "index_parcel_deliveries_on_organization_id_and_staff_shift_id"
    t.index ["organization_id", "tracking_code"], name: "index_parcel_deliveries_on_org_tracking_code"
    t.index ["organization_id", "unit_id", "status", "received_at"], name: "index_parcel_deliveries_on_org_unit_status_received_at"
    t.index ["organization_id", "withdrawn_by_person_id"], name: "index_parcel_deliveries_on_org_withdrawn_by_person"
    t.index ["organization_id"], name: "index_parcel_deliveries_on_organization_id"
    t.index ["received_by_person_id"], name: "index_parcel_deliveries_on_received_by_person_id"
    t.index ["recipient_person_id"], name: "index_parcel_deliveries_on_recipient_person_id"
    t.index ["residential_property_id"], name: "index_parcel_deliveries_on_residential_property_id"
    t.index ["staff_shift_id"], name: "index_parcel_deliveries_on_staff_shift_id"
    t.index ["unit_id"], name: "index_parcel_deliveries_on_unit_id"
    t.index ["withdrawn_by_person_id"], name: "index_parcel_deliveries_on_withdrawn_by_person_id"
    t.check_constraint "withdrawn_at IS NULL OR withdrawn_at >= received_at", name: "parcel_deliveries_withdrawn_after_received"
  end

  create_table "parcel_delivery_status_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "changed_by_person_id"
    t.datetime "created_at", null: false
    t.string "from_status"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.uuid "parcel_delivery_id", null: false
    t.text "reason"
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_person_id"], name: "index_parcel_delivery_status_histories_on_changed_by_person_id"
    t.index ["metadata"], name: "index_parcel_delivery_status_histories_on_metadata", using: :gin
    t.index ["organization_id", "changed_by_person_id"], name: "index_parcel_delivery_status_histories_on_org_changed_by"
    t.index ["organization_id", "parcel_delivery_id", "created_at"], name: "index_parcel_delivery_status_histories_on_org_delivery_created"
    t.index ["organization_id"], name: "index_parcel_delivery_status_histories_on_organization_id"
    t.index ["parcel_delivery_id"], name: "index_parcel_delivery_status_histories_on_parcel_delivery_id"
  end

  create_table "people", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "birthdate"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "display_name", null: false
    t.text "document_number_ciphertext"
    t.string "document_number_digest"
    t.string "document_type"
    t.text "email_ciphertext"
    t.string "first_name"
    t.string "last_name"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.string "person_type", default: "natural", null: false
    t.text "phone_ciphertext"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["deleted_at"], name: "index_people_on_deleted_at"
    t.index ["metadata"], name: "index_people_on_metadata", using: :gin
    t.index ["organization_id", "display_name"], name: "index_people_on_organization_id_and_display_name"
    t.index ["organization_id", "document_type", "document_number_digest"], name: "idx_people_unique_document_per_org_when_present", unique: true, where: "((document_number_digest IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "status"], name: "index_people_on_organization_id_and_status"
    t.index ["organization_id", "user_id"], name: "idx_people_unique_user_per_org_when_present", unique: true, where: "((user_id IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "user_id"], name: "index_people_on_organization_id_and_user_id"
    t.index ["organization_id"], name: "index_people_on_organization_id"
    t.index ["user_id"], name: "index_people_on_user_id"
  end

  create_table "people_roles", id: false, force: :cascade do |t|
    t.uuid "person_id", null: false
    t.uuid "role_id", null: false
    t.index ["person_id", "role_id"], name: "index_people_roles_on_person_id_and_role_id"
  end

  create_table "property_sections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.uuid "organization_id", null: false
    t.uuid "parent_id"
    t.integer "position"
    t.uuid "residential_property_id", null: false
    t.string "section_type", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_property_sections_on_deleted_at"
    t.index ["metadata"], name: "index_property_sections_on_metadata", using: :gin
    t.index ["organization_id", "residential_property_id", "normalized_name"], name: "idx_property_sections_unique_root_name", unique: true, where: "((parent_id IS NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "residential_property_id", "parent_id", "normalized_name"], name: "idx_property_sections_unique_child_name", unique: true, where: "((parent_id IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "residential_property_id", "parent_id", "section_type", "code"], name: "idx_property_sections_unique_code_in_context", unique: true, where: "((code IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "residential_property_id", "parent_id"], name: "idx_property_sections_on_org_property_parent"
    t.index ["organization_id"], name: "index_property_sections_on_organization_id"
    t.index ["parent_id"], name: "index_property_sections_on_parent_id"
    t.index ["residential_property_id", "parent_id", "position"], name: "idx_property_sections_property_parent_position"
    t.index ["residential_property_id"], name: "index_property_sections_on_residential_property_id"
    t.check_constraint "section_type::text = ANY (ARRAY['building'::character varying, 'tower'::character varying, 'floor'::character varying, 'block'::character varying, 'stage'::character varying, 'sector'::character varying, 'parking_area'::character varying, 'storage_area'::character varying, 'other'::character varying, 'parking'::character varying, 'storage'::character varying, 'commercial'::character varying, 'amenities'::character varying, 'entrance'::character varying, 'garden'::character varying]::text[])", name: "property_sections_section_type_allowed"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'archived'::character varying]::text[])", name: "property_sections_status_allowed"
  end

  create_table "property_setting_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "change_reason"
    t.uuid "changed_by_person_id"
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.uuid "property_setting_id", null: false
    t.uuid "residential_property_id", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.datetime "updated_at", null: false
    t.integer "version_number", null: false
    t.index ["changed_by_person_id"], name: "index_property_setting_versions_on_changed_by_person_id"
    t.index ["organization_id", "property_setting_id"], name: "idx_property_setting_versions_on_org_and_setting"
    t.index ["organization_id", "residential_property_id", "version_number"], name: "idx_property_setting_versions_on_org_property_version"
    t.index ["organization_id"], name: "index_property_setting_versions_on_organization_id"
    t.index ["property_setting_id"], name: "index_property_setting_versions_on_property_setting_id"
    t.index ["residential_property_id"], name: "index_property_setting_versions_on_residential_property_id"
    t.index ["snapshot"], name: "index_property_setting_versions_on_snapshot", using: :gin
  end

  create_table "property_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "active_notification_channels", default: {}, null: false
    t.boolean "allow_recurring_visits", default: false, null: false
    t.boolean "concierge_can_approve_visits", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "max_reservations_per_month"
    t.integer "max_simultaneous_visitors_per_unit", default: 5, null: false
    t.integer "max_visitors_per_visit", default: 5, null: false
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.boolean "parcel_requires_signature", default: false, null: false
    t.integer "reservation_max_duration_minutes"
    t.integer "reservation_min_advance_hours", default: 0, null: false
    t.boolean "reservation_requires_approval", default: true, null: false
    t.uuid "residential_property_id", null: false
    t.datetime "updated_at", null: false
    t.boolean "vehicle_plate_required", default: false, null: false
    t.boolean "visit_requires_concierge_validation", default: true, null: false
    t.boolean "visit_requires_resident_approval", default: true, null: false
    t.boolean "visitor_identity_document_required", default: false, null: false
    t.index ["active_notification_channels"], name: "index_property_settings_on_active_notification_channels", using: :gin
    t.index ["metadata"], name: "index_property_settings_on_metadata", using: :gin
    t.index ["organization_id", "residential_property_id"], name: "idx_on_organization_id_residential_property_id_ef39d448db", unique: true
    t.index ["organization_id"], name: "index_property_settings_on_organization_id"
    t.index ["residential_property_id"], name: "index_property_settings_on_residential_property_id"
  end

  create_table "residential_properties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address_line"
    t.string "city"
    t.string "code"
    t.string "country", default: "Chile", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.uuid "organization_id", null: false
    t.string "property_type", null: false
    t.string "region"
    t.string "status", default: "active", null: false
    t.string "timezone", default: "America/Santiago", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_residential_properties_on_deleted_at"
    t.index ["metadata"], name: "index_residential_properties_on_metadata", using: :gin
    t.index ["organization_id", "code"], name: "idx_residential_properties_unique_code_per_org", unique: true, where: "((code IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "id"], name: "idx_residential_properties_organization_id_id", unique: true
    t.index ["organization_id", "normalized_name"], name: "idx_residential_properties_unique_normalized_name_per_org", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id", "property_type"], name: "idx_on_organization_id_property_type_d2e2ee8ca6"
    t.index ["organization_id", "status"], name: "index_residential_properties_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_residential_properties_on_organization_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'created'::character varying, 'configured'::character varying, 'active'::character varying, 'inactive'::character varying, 'archived'::character varying]::text[])", name: "residential_properties_status_allowed"
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.uuid "organization_id"
    t.string "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["name"], name: "index_roles_on_name"
    t.index ["organization_id"], name: "index_roles_on_organization_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource"
  end

  create_table "staff_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "confirmation_state", default: "confirmed", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.date "ends_at"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.uuid "person_id", null: false
    t.uuid "residential_property_id", null: false
    t.string "staff_type", null: false
    t.date "starts_at"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_state"], name: "index_staff_assignments_on_confirmation_state"
    t.index ["metadata"], name: "index_staff_assignments_on_metadata", using: :gin
    t.index ["organization_id", "person_id", "status"], name: "idx_on_organization_id_person_id_status_36b5c5bfed"
    t.index ["organization_id", "residential_property_id", "staff_type", "status"], name: "index_staff_assignments_on_org_property_type_status"
    t.index ["organization_id"], name: "index_staff_assignments_on_organization_id"
    t.index ["person_id"], name: "index_staff_assignments_on_person_id"
    t.index ["residential_property_id"], name: "index_staff_assignments_on_residential_property_id"
  end

  create_table "staff_shifts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "actual_ends_at"
    t.datetime "actual_starts_at"
    t.uuid "closed_by_person_id"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.uuid "opened_by_person_id"
    t.uuid "organization_id", null: false
    t.uuid "person_id", null: false
    t.datetime "planned_ends_at", null: false
    t.datetime "planned_starts_at", null: false
    t.uuid "replaced_by_shift_id"
    t.uuid "residential_property_id", null: false
    t.uuid "staff_assignment_id", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["closed_by_person_id"], name: "index_staff_shifts_on_closed_by_person_id"
    t.index ["metadata"], name: "index_staff_shifts_on_metadata", using: :gin
    t.index ["opened_by_person_id"], name: "index_staff_shifts_on_opened_by_person_id"
    t.index ["organization_id", "person_id", "planned_starts_at", "planned_ends_at"], name: "index_staff_shifts_on_org_person_planned_range"
    t.index ["organization_id", "residential_property_id", "planned_starts_at", "planned_ends_at"], name: "index_staff_shifts_on_org_property_planned_range"
    t.index ["organization_id", "residential_property_id", "status"], name: "index_staff_shifts_on_org_property_in_progress", where: "((status)::text = 'in_progress'::text)"
    t.index ["organization_id", "status"], name: "index_staff_shifts_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_staff_shifts_on_organization_id"
    t.index ["person_id"], name: "index_staff_shifts_on_person_id"
    t.index ["residential_property_id"], name: "index_staff_shifts_on_residential_property_id"
    t.index ["staff_assignment_id"], name: "index_staff_shifts_on_staff_assignment_id"
    t.check_constraint "planned_ends_at >= planned_starts_at", name: "staff_shifts_planned_range_valid"
  end

  create_table "unit_occupancies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "can_authorize_visits", default: false, null: false
    t.boolean "can_reserve_common_areas", default: false, null: false
    t.boolean "can_withdraw_parcels", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "ends_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "occupancy_type", null: false
    t.uuid "organization_id", null: false
    t.uuid "person_id", null: false
    t.uuid "source_id"
    t.string "source_type"
    t.datetime "starts_at", null: false
    t.string "status", default: "active", null: false
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_unit_occupancies_on_deleted_at"
    t.index ["metadata"], name: "index_unit_occupancies_on_metadata", using: :gin
    t.index ["organization_id", "person_id", "status"], name: "index_unit_occupancies_on_org_person_status"
    t.index ["organization_id", "source_type", "source_id"], name: "index_unit_occupancies_on_org_source"
    t.index ["organization_id", "unit_id", "person_id"], name: "index_unit_occupancies_on_org_unit_person_not_deleted", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id", "unit_id", "status", "starts_at", "ends_at"], name: "index_unit_occupancies_on_org_unit_status_dates"
    t.index ["organization_id"], name: "index_unit_occupancies_on_organization_id"
    t.index ["person_id"], name: "index_unit_occupancies_on_person_id"
    t.index ["unit_id"], name: "index_unit_occupancies_on_unit_id"
    t.check_constraint "ends_at IS NULL OR ends_at >= starts_at", name: "unit_occupancies_date_range_valid"
  end

  create_table "unit_ownerships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_person_id"
    t.datetime "deleted_at"
    t.uuid "ended_by_person_id"
    t.date "ends_at"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.decimal "ownership_percentage", precision: 5, scale: 2, default: "100.0", null: false
    t.uuid "person_id", null: false
    t.date "starts_at", null: false
    t.string "status", default: "active", null: false
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_person_id"], name: "index_unit_ownerships_on_created_by_person_id"
    t.index ["deleted_at"], name: "index_unit_ownerships_on_deleted_at"
    t.index ["ended_by_person_id"], name: "index_unit_ownerships_on_ended_by_person_id"
    t.index ["metadata"], name: "index_unit_ownerships_on_metadata", using: :gin
    t.index ["organization_id", "person_id", "status"], name: "index_unit_ownerships_on_org_person_status"
    t.index ["organization_id", "unit_id", "starts_at", "ends_at"], name: "index_unit_ownerships_on_org_unit_date_range"
    t.index ["organization_id", "unit_id", "status"], name: "index_unit_ownerships_on_org_unit_status"
    t.index ["organization_id"], name: "index_unit_ownerships_on_organization_id"
    t.index ["person_id"], name: "index_unit_ownerships_on_person_id"
    t.index ["unit_id"], name: "index_unit_ownerships_on_unit_id"
    t.check_constraint "ends_at IS NULL OR ends_at >= starts_at", name: "unit_ownerships_date_range_valid"
    t.check_constraint "ownership_percentage > 0::numeric AND ownership_percentage <= 100::numeric", name: "unit_ownerships_percentage_range"
  end

  create_table "units", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "area_m2", precision: 10, scale: 2
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "display_name"
    t.string "identifier", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "normalized_identifier", null: false
    t.uuid "organization_id", null: false
    t.uuid "property_section_id"
    t.uuid "residential_property_id", null: false
    t.string "status", default: "available", null: false
    t.string "unit_type", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_units_on_deleted_at"
    t.index ["metadata"], name: "index_units_on_metadata", using: :gin
    t.index ["organization_id", "property_section_id"], name: "index_units_on_organization_id_and_property_section_id"
    t.index ["organization_id", "residential_property_id", "code"], name: "idx_units_unique_code_in_property_root", unique: true, where: "((deleted_at IS NULL) AND (property_section_id IS NULL) AND (code IS NOT NULL))"
    t.index ["organization_id", "residential_property_id", "normalized_identifier"], name: "idx_units_on_org_property_normalized_identifier_lookup", where: "(deleted_at IS NULL)"
    t.index ["organization_id", "residential_property_id", "normalized_identifier"], name: "index_units_on_org_property_normalized_when_no_section", unique: true, where: "((property_section_id IS NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "residential_property_id", "property_section_id", "code"], name: "idx_units_unique_code_in_section", unique: true, where: "((deleted_at IS NULL) AND (property_section_id IS NOT NULL) AND (code IS NOT NULL))"
    t.index ["organization_id", "residential_property_id", "property_section_id", "normalized_identifier"], name: "index_units_on_org_property_section_normalized_when_section", unique: true, where: "((property_section_id IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "residential_property_id", "status"], name: "idx_on_organization_id_residential_property_id_stat_47cefd6e3a"
    t.index ["organization_id"], name: "index_units_on_organization_id"
    t.index ["property_section_id"], name: "index_units_on_property_section_id"
    t.index ["residential_property_id"], name: "index_units_on_residential_property_id"
    t.check_constraint "area_m2 IS NULL OR area_m2 > 0::numeric", name: "units_area_m2_positive"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.datetime "deleted_at"
    t.string "dni"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "global_status", default: "active", null: false
    t.string "language"
    t.datetime "last_active_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "suspended_at"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["deactivated_at"], name: "index_users_on_deactivated_at"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["global_status"], name: "index_users_on_global_status"
    t.index ["metadata"], name: "index_users_on_metadata", using: :gin
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["suspended_at"], name: "index_users_on_suspended_at"
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.uuid "role_id"
    t.uuid "user_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
  end

  create_table "vehicles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "authorized_from"
    t.datetime "authorized_until"
    t.string "brand"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "model"
    t.uuid "organization_id", null: false
    t.uuid "person_id"
    t.text "plate_number_ciphertext"
    t.string "plate_number_digest"
    t.string "status", default: "active", null: false
    t.uuid "unit_id"
    t.datetime "updated_at", null: false
    t.string "vehicle_type"
    t.index ["deleted_at"], name: "index_vehicles_on_deleted_at"
    t.index ["organization_id", "person_id"], name: "index_vehicles_on_org_person"
    t.index ["organization_id", "plate_number_digest"], name: "index_vehicles_unique_plate_digest_per_org_when_present", unique: true, where: "((deleted_at IS NULL) AND (plate_number_digest IS NOT NULL))"
    t.index ["organization_id", "status"], name: "index_vehicles_on_org_status"
    t.index ["organization_id", "unit_id"], name: "index_vehicles_on_org_unit"
    t.index ["organization_id"], name: "index_vehicles_on_organization_id"
    t.index ["person_id"], name: "index_vehicles_on_person_id"
    t.index ["unit_id"], name: "index_vehicles_on_unit_id"
  end

  create_table "visit_participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "checked_in_at"
    t.datetime "checked_out_at"
    t.datetime "created_at", null: false
    t.string "document_snapshot_digest"
    t.jsonb "metadata", default: {}, null: false
    t.string "name_snapshot"
    t.text "notes"
    t.uuid "organization_id", null: false
    t.uuid "person_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.uuid "validated_by_person_id"
    t.uuid "visit_id", null: false
    t.uuid "visitor_profile_id"
    t.index ["metadata"], name: "index_visit_participants_on_metadata", using: :gin
    t.index ["organization_id", "document_snapshot_digest"], name: "index_visit_participants_on_org_document_snapshot_digest"
    t.index ["organization_id", "person_id"], name: "index_visit_participants_on_organization_id_and_person_id"
    t.index ["organization_id", "visit_id", "status"], name: "idx_on_organization_id_visit_id_status_d1b6982805"
    t.index ["organization_id", "visitor_profile_id"], name: "idx_on_organization_id_visitor_profile_id_0adf418fb3"
    t.index ["organization_id"], name: "index_visit_participants_on_organization_id"
    t.index ["person_id"], name: "index_visit_participants_on_person_id"
    t.index ["validated_by_person_id"], name: "index_visit_participants_on_validated_by_person_id"
    t.index ["visit_id"], name: "index_visit_participants_on_visit_id"
    t.index ["visitor_profile_id"], name: "index_visit_participants_on_visitor_profile_id"
    t.check_constraint "person_id IS NOT NULL OR visitor_profile_id IS NOT NULL OR name_snapshot IS NOT NULL", name: "visit_participants_identity_present"
  end

  create_table "visit_recurrences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "byday"
    t.string "bymonth"
    t.string "bymonthday"
    t.integer "count"
    t.datetime "created_at", null: false
    t.datetime "dtstart", null: false
    t.string "freq", null: false
    t.integer "interval", default: 1, null: false
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.string "timezone", default: "America/Santiago", null: false
    t.datetime "until_at"
    t.datetime "updated_at", null: false
    t.uuid "visit_id", null: false
    t.string "wkst", default: "MO", null: false
    t.index ["metadata"], name: "index_visit_recurrences_on_metadata", using: :gin
    t.index ["organization_id", "dtstart"], name: "index_visit_recurrences_on_org_dtstart"
    t.index ["organization_id", "freq"], name: "index_visit_recurrences_on_org_freq"
    t.index ["organization_id", "visit_id"], name: "index_visit_recurrences_unique_per_visit", unique: true
    t.index ["organization_id"], name: "index_visit_recurrences_on_organization_id"
    t.index ["visit_id"], name: "index_visit_recurrences_on_visit_id"
    t.check_constraint "\"interval\" > 0", name: "visit_recurrences_interval_positive"
    t.check_constraint "count IS NULL OR count > 0", name: "visit_recurrences_count_positive"
    t.check_constraint "freq::text = ANY (ARRAY['DAILY'::character varying::text, 'WEEKLY'::character varying::text, 'MONTHLY'::character varying::text, 'YEARLY'::character varying::text])", name: "visit_recurrences_freq_allowed"
    t.check_constraint "until_at IS NULL OR count IS NULL", name: "visit_recurrences_until_or_count"
    t.check_constraint "until_at IS NULL OR until_at >= dtstart", name: "visit_recurrences_until_after_dtstart"
  end

  create_table "visit_status_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "changed_by_id"
    t.uuid "changed_by_person_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "from_status"
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.uuid "organization_id", null: false
    t.text "reason"
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.uuid "visit_id", null: false
    t.index ["changed_by_id"], name: "index_visit_status_histories_on_changed_by_id"
    t.index ["changed_by_person_id"], name: "index_visit_status_histories_on_changed_by_person_id"
    t.index ["metadata"], name: "index_visit_status_histories_on_metadata", using: :gin
    t.index ["organization_id", "event_type"], name: "index_visit_status_histories_on_org_event_type"
    t.index ["organization_id", "to_status"], name: "index_visit_status_histories_on_organization_id_and_to_status"
    t.index ["organization_id", "visit_id", "created_at"], name: "index_visit_status_histories_on_org_visit_created_at"
    t.index ["organization_id", "visit_id", "occurred_at"], name: "index_visit_status_histories_on_org_visit_occurred_at"
    t.index ["organization_id"], name: "index_visit_status_histories_on_organization_id"
    t.index ["visit_id"], name: "index_visit_status_histories_on_visit_id"
  end

  create_table "visitor_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "company_name"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "document_number_ciphertext"
    t.string "document_number_digest"
    t.string "document_type"
    t.text "email_ciphertext"
    t.string "external_name"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.uuid "person_id"
    t.text "phone_ciphertext"
    t.text "security_notes"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_visitor_profiles_on_deleted_at"
    t.index ["metadata"], name: "index_visitor_profiles_on_metadata", using: :gin
    t.index ["organization_id", "document_number_digest"], name: "index_visitor_profiles_unique_doc_digest_per_org_when_present", unique: true, where: "((deleted_at IS NULL) AND (document_number_digest IS NOT NULL))"
    t.index ["organization_id", "person_id"], name: "index_visitor_profiles_on_organization_id_and_person_id"
    t.index ["organization_id", "status"], name: "index_visitor_profiles_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_visitor_profiles_on_organization_id"
    t.index ["person_id"], name: "index_visitor_profiles_on_person_id"
  end

  create_table "visits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "authorized_at"
    t.uuid "authorized_by_id"
    t.datetime "checked_in_at"
    t.uuid "checked_in_by_id"
    t.datetime "checked_out_at"
    t.uuid "checked_out_by_id"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.string "notification_status", default: "pending", null: false
    t.uuid "organization_id", null: false
    t.uuid "property_section_id"
    t.uuid "residential_property_id", null: false
    t.datetime "scheduled_at", null: false
    t.string "status", default: "pending", null: false
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "valid_from", null: false
    t.datetime "valid_until"
    t.string "visit_type"
    t.uuid "visitor_person_id", null: false
    t.index ["authorized_by_id"], name: "index_visits_on_authorized_by_id"
    t.index ["checked_in_by_id"], name: "index_visits_on_checked_in_by_id"
    t.index ["checked_out_by_id"], name: "index_visits_on_checked_out_by_id"
    t.index ["created_by_id"], name: "index_visits_on_created_by_id"
    t.index ["metadata"], name: "index_visits_on_metadata", using: :gin
    t.index ["organization_id", "residential_property_id", "scheduled_at"], name: "index_visits_on_org_property_pending_scheduled_at", where: "((status)::text = 'pending'::text)"
    t.index ["organization_id", "residential_property_id", "status", "checked_out_at"], name: "index_visits_on_org_property_operational_statuses", where: "((status)::text = ANY (ARRAY[('authorized'::character varying)::text, ('checked_in'::character varying)::text, ('checked_out'::character varying)::text]))"
    t.index ["organization_id", "residential_property_id", "status", "scheduled_at"], name: "index_visits_on_org_property_status_scheduled_at"
    t.index ["organization_id", "unit_id", "scheduled_at"], name: "index_visits_on_org_unit_scheduled_at"
    t.index ["organization_id"], name: "index_visits_on_organization_id"
    t.index ["property_section_id"], name: "index_visits_on_property_section_id"
    t.index ["residential_property_id"], name: "index_visits_on_residential_property_id"
    t.index ["unit_id"], name: "index_visits_on_unit_id"
    t.index ["visitor_person_id"], name: "index_visits_on_visitor_person_id"
    t.check_constraint "valid_until IS NULL OR valid_until >= valid_from", name: "visits_validity_range_valid"
  end

  add_foreign_key "access_events", "organizations"
  add_foreign_key "access_events", "people", column: "recorded_by_person_id"
  add_foreign_key "access_events", "residential_properties"
  add_foreign_key "access_events", "staff_shifts"
  add_foreign_key "access_events", "units"
  add_foreign_key "access_events", "vehicles"
  add_foreign_key "access_events", "visit_participants"
  add_foreign_key "access_events", "visitor_profiles"
  add_foreign_key "access_events", "visits"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ahoy_events", "organizations"
  add_foreign_key "ahoy_visits", "organizations"
  add_foreign_key "announcement_reads", "announcements"
  add_foreign_key "announcement_reads", "organizations"
  add_foreign_key "announcement_reads", "people"
  add_foreign_key "announcement_targets", "announcements"
  add_foreign_key "announcement_targets", "organizations"
  add_foreign_key "announcements", "organizations"
  add_foreign_key "announcements", "people", column: "author_person_id"
  add_foreign_key "announcements", "residential_properties"
  add_foreign_key "audits", "organizations"
  add_foreign_key "authorized_residents", "organizations"
  add_foreign_key "authorized_residents", "people"
  add_foreign_key "authorized_residents", "people", column: "authorized_by_person_id"
  add_foreign_key "authorized_residents", "units"
  add_foreign_key "bulk_import_rows", "bulk_imports"
  add_foreign_key "bulk_imports", "organizations"
  add_foreign_key "bulk_imports", "property_sections"
  add_foreign_key "bulk_imports", "residential_properties"
  add_foreign_key "bulk_imports", "users", column: "created_by_id"
  add_foreign_key "common_area_reservation_status_histories", "common_area_reservations"
  add_foreign_key "common_area_reservation_status_histories", "organizations"
  add_foreign_key "common_area_reservation_status_histories", "people", column: "changed_by_person_id"
  add_foreign_key "common_area_reservations", "common_areas"
  add_foreign_key "common_area_reservations", "organizations"
  add_foreign_key "common_area_reservations", "people", column: "approved_by_person_id"
  add_foreign_key "common_area_reservations", "people", column: "requested_by_person_id"
  add_foreign_key "common_area_reservations", "residential_properties"
  add_foreign_key "common_area_reservations", "units"
  add_foreign_key "common_area_rules", "common_areas"
  add_foreign_key "common_area_rules", "organizations"
  add_foreign_key "common_areas", "organizations"
  add_foreign_key "common_areas", "residential_properties"
  add_foreign_key "device_tokens", "users"
  add_foreign_key "documents", "organizations"
  add_foreign_key "documents", "people", column: "uploaded_by_person_id"
  add_foreign_key "incident_status_histories", "incidents"
  add_foreign_key "incident_status_histories", "organizations"
  add_foreign_key "incident_status_histories", "people", column: "changed_by_person_id"
  add_foreign_key "incidents", "common_areas"
  add_foreign_key "incidents", "organizations"
  add_foreign_key "incidents", "parcel_deliveries"
  add_foreign_key "incidents", "people", column: "assigned_to_person_id"
  add_foreign_key "incidents", "people", column: "reported_by_person_id"
  add_foreign_key "incidents", "residential_properties"
  add_foreign_key "incidents", "units"
  add_foreign_key "incidents", "vehicles"
  add_foreign_key "incidents", "visits"
  add_foreign_key "lease_contracts", "organizations"
  add_foreign_key "lease_contracts", "people", column: "created_by_person_id"
  add_foreign_key "lease_contracts", "people", column: "lessee_person_id"
  add_foreign_key "lease_contracts", "people", column: "lessor_person_id"
  add_foreign_key "lease_contracts", "people", column: "terminated_by_person_id"
  add_foreign_key "lease_contracts", "units"
  add_foreign_key "notifications", "organizations"
  add_foreign_key "notifications", "people", column: "recipient_person_id"
  add_foreign_key "notifications", "residential_properties"
  add_foreign_key "notifications", "units"
  add_foreign_key "onboarding_requests", "organizations"
  add_foreign_key "onboarding_requests", "people"
  add_foreign_key "onboarding_requests", "people", column: "requested_by_person_id"
  add_foreign_key "onboarding_requests", "residential_properties"
  add_foreign_key "onboarding_requests", "units"
  add_foreign_key "onboarding_requests", "users"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "people"
  add_foreign_key "parcel_deliveries", "organizations"
  add_foreign_key "parcel_deliveries", "people", column: "received_by_person_id"
  add_foreign_key "parcel_deliveries", "people", column: "recipient_person_id"
  add_foreign_key "parcel_deliveries", "people", column: "withdrawn_by_person_id"
  add_foreign_key "parcel_deliveries", "residential_properties"
  add_foreign_key "parcel_deliveries", "staff_shifts"
  add_foreign_key "parcel_deliveries", "units"
  add_foreign_key "parcel_delivery_status_histories", "organizations"
  add_foreign_key "parcel_delivery_status_histories", "parcel_deliveries"
  add_foreign_key "parcel_delivery_status_histories", "people", column: "changed_by_person_id"
  add_foreign_key "people", "organizations"
  add_foreign_key "people", "users"
  add_foreign_key "people_roles", "people"
  add_foreign_key "people_roles", "roles"
  add_foreign_key "property_sections", "organizations"
  add_foreign_key "property_sections", "property_sections", column: "parent_id"
  add_foreign_key "property_sections", "residential_properties"
  add_foreign_key "property_setting_versions", "organizations"
  add_foreign_key "property_setting_versions", "people", column: "changed_by_person_id"
  add_foreign_key "property_setting_versions", "property_settings"
  add_foreign_key "property_setting_versions", "residential_properties"
  add_foreign_key "property_settings", "organizations"
  add_foreign_key "property_settings", "residential_properties"
  add_foreign_key "residential_properties", "organizations"
  add_foreign_key "roles", "organizations"
  add_foreign_key "staff_assignments", "organizations"
  add_foreign_key "staff_assignments", "people"
  add_foreign_key "staff_assignments", "residential_properties"
  add_foreign_key "staff_shifts", "organizations"
  add_foreign_key "staff_shifts", "people"
  add_foreign_key "staff_shifts", "people", column: "closed_by_person_id"
  add_foreign_key "staff_shifts", "people", column: "opened_by_person_id"
  add_foreign_key "staff_shifts", "residential_properties"
  add_foreign_key "staff_shifts", "staff_assignments"
  add_foreign_key "staff_shifts", "staff_shifts", column: "replaced_by_shift_id"
  add_foreign_key "unit_occupancies", "organizations"
  add_foreign_key "unit_occupancies", "people"
  add_foreign_key "unit_occupancies", "units"
  add_foreign_key "unit_ownerships", "organizations"
  add_foreign_key "unit_ownerships", "people"
  add_foreign_key "unit_ownerships", "people", column: "created_by_person_id"
  add_foreign_key "unit_ownerships", "people", column: "ended_by_person_id"
  add_foreign_key "unit_ownerships", "units"
  add_foreign_key "units", "organizations"
  add_foreign_key "units", "property_sections"
  add_foreign_key "units", "residential_properties"
  add_foreign_key "units", "residential_properties", column: ["organization_id", "residential_property_id"], primary_key: ["organization_id", "id"], name: "fk_units_organization_residential_property_coherent"
  add_foreign_key "vehicles", "organizations"
  add_foreign_key "vehicles", "people"
  add_foreign_key "vehicles", "units"
  add_foreign_key "visit_participants", "organizations"
  add_foreign_key "visit_participants", "people"
  add_foreign_key "visit_participants", "people", column: "validated_by_person_id"
  add_foreign_key "visit_participants", "visitor_profiles"
  add_foreign_key "visit_participants", "visits"
  add_foreign_key "visit_recurrences", "organizations"
  add_foreign_key "visit_recurrences", "visits"
  add_foreign_key "visit_status_histories", "organizations"
  add_foreign_key "visit_status_histories", "people", column: "changed_by_person_id"
  add_foreign_key "visit_status_histories", "users", column: "changed_by_id"
  add_foreign_key "visit_status_histories", "visits"
  add_foreign_key "visitor_profiles", "organizations"
  add_foreign_key "visitor_profiles", "people"
  add_foreign_key "visits", "organizations"
  add_foreign_key "visits", "people", column: "visitor_person_id"
  add_foreign_key "visits", "property_sections"
  add_foreign_key "visits", "residential_properties"
  add_foreign_key "visits", "units"
  add_foreign_key "visits", "users", column: "authorized_by_id"
  add_foreign_key "visits", "users", column: "checked_in_by_id"
  add_foreign_key "visits", "users", column: "checked_out_by_id"
  add_foreign_key "visits", "users", column: "created_by_id"
end
