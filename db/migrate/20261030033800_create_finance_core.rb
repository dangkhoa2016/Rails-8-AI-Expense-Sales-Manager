# frozen_string_literal: true

class CreateFinanceCore < ActiveRecord::Migration[8.0]
  def up
    create_table :finance_transactions do |t|
      t.bigint :workspace_id, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: 'draft'
      t.date :transaction_date
      t.string :currency_code, null: false, default: 'VND'
      t.decimal :amount, precision: 20, scale: 2
      t.text :description
      t.string :category
      t.string :entry_source, null: false, default: 'manual'
      t.bigint :active_document_version_id
      t.bigint :created_by_id, null: false
      t.bigint :confirmed_by_id
      t.datetime :confirmed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :finance_transactions, [:workspace_id, :status, :transaction_date], name: 'idx_finance_tenant_status_date'
    add_check_constraint :finance_transactions, "kind IN ('income','expense')", name: 'finance_transactions_kind_check'
    add_check_constraint :finance_transactions, "status IN ('draft','confirmed')", name: 'finance_transactions_status_check'
    add_check_constraint :finance_transactions, "entry_source IN ('manual','ai_assisted')", name: 'finance_transactions_source_check'
    add_check_constraint :finance_transactions, "amount IS NULL OR amount >= 0", name: 'finance_transactions_amount_check'
    add_check_constraint :finance_transactions,
      "status <> 'confirmed' OR (transaction_date IS NOT NULL AND amount > 0 AND confirmed_by_id IS NOT NULL AND confirmed_at IS NOT NULL)",
      name: 'finance_transactions_confirm_check'

    create_table :finance_line_items do |t|
      t.references :transaction, null: false, foreign_key: { to_table: :finance_transactions }, index: false
      t.integer :position, null: false
      t.text :description, null: false
      t.decimal :amount, precision: 20, scale: 2
      t.string :entry_source, null: false, default: 'manual'
      t.timestamps
    end
    add_index :finance_line_items, [:transaction_id, :position], unique: true
    add_check_constraint :finance_line_items, 'amount IS NULL OR amount >= 0', name: 'finance_line_items_amount_check'

    create_table :finance_document_versions do |t|
      t.references :transaction, null: false, foreign_key: { to_table: :finance_transactions }, index: false
      t.integer :version_number, null: false
      t.string :sha256, limit: 64, null: false
      t.string :original_filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false
      t.bigint :uploaded_by_id, null: false
      t.bigint :supersedes_version_id
      t.datetime :created_at, null: false
    end
    add_index :finance_document_versions, [:transaction_id, :version_number], unique: true, name: 'idx_finance_document_versions_sequence'
    add_check_constraint :finance_document_versions, 'version_number > 0 AND byte_size > 0', name: 'finance_document_version_valid_check'
    add_check_constraint :finance_document_versions, 'char_length(sha256) = 64', name: 'finance_document_version_digest_check'
    add_index :finance_document_versions, [:id, :transaction_id], unique: true, name: 'idx_finance_version_transaction_pair'
    execute <<~SQL
      ALTER TABLE finance_transactions
      ADD CONSTRAINT finance_active_doc_same_transaction
      FOREIGN KEY (active_document_version_id, id)
      REFERENCES finance_document_versions(id, transaction_id)
    SQL

    create_table :finance_extraction_runs do |t|
      t.references :document_version, null: false, foreign_key: { to_table: :finance_document_versions }
      t.string :model_sha256, limit: 64, null: false
      t.string :prompt_sha256, limit: 64, null: false
      t.string :schema_version, null: false
      t.string :parse_status, null: false
      t.jsonb :raw_output, null: false, default: {}
      t.text :diagnostic_code
      t.datetime :created_at, null: false
    end
    add_check_constraint :finance_extraction_runs,
      "parse_status IN ('readable','partially_readable','unreadable','processing_error')", name: 'finance_extraction_status_check'

    create_table :finance_field_suggestions do |t|
      t.references :transaction, null: false, foreign_key: { to_table: :finance_transactions }
      t.references :extraction_run, null: false, foreign_key: { to_table: :finance_extraction_runs }
      t.string :field_key, null: false
      t.text :proposed_value
      t.string :review_status, null: false, default: 'pending'
      t.bigint :reviewed_by_id
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :finance_field_suggestions, [:transaction_id, :review_status]
    add_check_constraint :finance_field_suggestions,
      "review_status IN ('pending','accepted','rejected')", name: 'finance_suggestions_review_check'

    create_table :finance_audit_events do |t|
      t.references :transaction, null: false, foreign_key: { to_table: :finance_transactions }
      t.bigint :workspace_id, null: false
      t.bigint :actor_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :finance_audit_events, [:workspace_id, :created_at]

    # Historical rows are append-only at database level, including SQL console access.
    execute <<~SQL
      CREATE FUNCTION finance_deny_history_mutation() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'finance evidence is append-only';
      END;
      $$ LANGUAGE plpgsql;
    SQL
    %w[finance_document_versions finance_extraction_runs finance_audit_events].each do |table|
      execute <<~SQL
        CREATE TRIGGER deny_#{table}_mutation
        BEFORE UPDATE OR DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION finance_deny_history_mutation();
      SQL
    end

    execute <<~SQL
      CREATE FUNCTION finance_deny_confirmed_line_item_mutation() RETURNS trigger AS $$
      DECLARE tx_id bigint;
      BEGIN
        tx_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.transaction_id ELSE NEW.transaction_id END;
        IF EXISTS (SELECT 1 FROM finance_transactions WHERE id = tx_id AND status = 'confirmed')
           OR (TG_OP = 'UPDATE' AND EXISTS (SELECT 1 FROM finance_transactions
              WHERE id = OLD.transaction_id AND status = 'confirmed')) THEN
          RAISE EXCEPTION 'confirmed finance line items cannot be changed';
        END IF;
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER deny_confirmed_finance_line_item_mutation
      BEFORE INSERT OR UPDATE OR DELETE ON finance_line_items
      FOR EACH ROW EXECUTE FUNCTION finance_deny_confirmed_line_item_mutation();
    SQL

    # Once confirmed, financial values cannot be silently changed or removed.
    execute <<~SQL
      CREATE FUNCTION finance_deny_confirmed_transaction_mutation() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND OLD.status = 'confirmed' THEN
          RAISE EXCEPTION 'confirmed finance transaction cannot be deleted';
        END IF;
        IF TG_OP = 'UPDATE' AND OLD.status = 'confirmed' THEN
          RAISE EXCEPTION 'confirmed finance transaction cannot be modified';
        END IF;
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER deny_confirmed_finance_transaction_mutation
      BEFORE UPDATE OR DELETE ON finance_transactions
      FOR EACH ROW EXECUTE FUNCTION finance_deny_confirmed_transaction_mutation();
    SQL
  end

  def down
    execute 'DROP TRIGGER IF EXISTS deny_confirmed_finance_line_item_mutation ON finance_line_items'
    execute 'DROP FUNCTION IF EXISTS finance_deny_confirmed_line_item_mutation()'
    execute 'DROP TRIGGER IF EXISTS deny_confirmed_finance_transaction_mutation ON finance_transactions'
    execute 'DROP FUNCTION IF EXISTS finance_deny_confirmed_transaction_mutation()'
    %w[finance_document_versions finance_extraction_runs finance_audit_events].each do |table|
      execute "DROP TRIGGER IF EXISTS deny_#{table}_mutation ON #{table}"
    end
    execute 'DROP FUNCTION IF EXISTS finance_deny_history_mutation()'
    drop_table :finance_audit_events
    drop_table :finance_field_suggestions
    drop_table :finance_extraction_runs
    drop_table :finance_document_versions
    drop_table :finance_line_items
    drop_table :finance_transactions
  end
end
