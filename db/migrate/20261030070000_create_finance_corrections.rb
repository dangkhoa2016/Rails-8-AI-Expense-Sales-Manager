# frozen_string_literal: true

class CreateFinanceCorrections < ActiveRecord::Migration[8.1]
  def up
    create_table :finance_corrections do |t|
      t.references :original_transaction, null: false,
        foreign_key: { to_table: :finance_transactions },
        index: { unique: true, name: "idx_finance_correction_original" }
      t.references :replacement_transaction, null: false,
        foreign_key: { to_table: :finance_transactions },
        index: { unique: true, name: "idx_finance_correction_replacement" }
      t.bigint :workspace_id, null: false
      t.bigint :requested_by_id, null: false
      t.bigint :confirmed_by_id
      t.text :reason, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :confirmed_at
      t.timestamps
    end

    add_foreign_key :finance_corrections, :workspaces, column: :workspace_id
    add_foreign_key :finance_corrections, :users, column: :requested_by_id
    add_foreign_key :finance_corrections, :users, column: :confirmed_by_id
    add_check_constraint :finance_corrections,
      "status IN ('draft', 'confirmed')", name: "finance_corrections_status_check"
    add_check_constraint :finance_corrections,
      "char_length(btrim(reason)) BETWEEN 10 AND 2000", name: "finance_corrections_reason_check"
    add_check_constraint :finance_corrections,
      "original_transaction_id <> replacement_transaction_id", name: "finance_corrections_distinct_check"
    add_check_constraint :finance_corrections,
      "status <> 'confirmed' OR (confirmed_by_id IS NOT NULL AND confirmed_at IS NOT NULL)",
      name: "finance_corrections_confirm_check"

    execute <<~SQL
      CREATE FUNCTION finance_guard_correction_mutation() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'finance corrections cannot be deleted';
        END IF;
        IF TG_OP = 'UPDATE' THEN
          IF OLD.status = 'confirmed' THEN
            RAISE EXCEPTION 'confirmed finance correction cannot be modified';
          END IF;
          IF NEW.original_transaction_id <> OLD.original_transaction_id
            OR NEW.replacement_transaction_id <> OLD.replacement_transaction_id
            OR NEW.workspace_id <> OLD.workspace_id
            OR NEW.requested_by_id <> OLD.requested_by_id
            OR NEW.reason <> OLD.reason THEN
            RAISE EXCEPTION 'finance correction provenance is immutable';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER guard_finance_correction_mutation
        BEFORE UPDATE OR DELETE ON finance_corrections
        FOR EACH ROW EXECUTE FUNCTION finance_guard_correction_mutation();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS guard_finance_correction_mutation ON finance_corrections"
    execute "DROP FUNCTION IF EXISTS finance_guard_correction_mutation()"
    drop_table :finance_corrections
  end
end
