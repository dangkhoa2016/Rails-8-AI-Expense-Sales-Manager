# frozen_string_literal: true

class CreateFinanceTransactionContexts < ActiveRecord::Migration[8.1]
  def up
    create_table :finance_transaction_contexts do |t|
      t.references :transaction, null: false, index: { unique: true },
                   foreign_key: { to_table: :finance_transactions }
      t.text :purchase_details
      t.time :occurred_time
      t.text :location_text
      t.string :source, null: false, default: "manual", limit: 24
      t.bigint :recorded_by_id, null: false
      t.timestamps
    end
    add_foreign_key :finance_transaction_contexts, :users, column: :recorded_by_id
    add_check_constraint :finance_transaction_contexts,
      "source IN ('manual', 'demo_seed')", name: "finance_transaction_contexts_source_check"
    add_check_constraint :finance_transaction_contexts,
      "purchase_details IS NULL OR (char_length(purchase_details) BETWEEN 1 AND 1000)",
      name: "finance_transaction_contexts_details_check"
    add_check_constraint :finance_transaction_contexts,
      "location_text IS NULL OR (char_length(location_text) BETWEEN 1 AND 400)",
      name: "finance_transaction_contexts_location_check"

    # Existing confirmed transactions may receive a one-time separately attributed
    # context row (e.g. a demo historical backfill). Subsequent UPDATE/DELETE is denied.
    # A context created on a draft can be changed until the transaction is confirmed.
    execute <<~SQL
      CREATE FUNCTION finance_guard_transaction_context_mutation() RETURNS trigger AS $$
      DECLARE
        tx_status text;
      BEGIN
        IF TG_OP = 'DELETE' THEN
          SELECT status INTO tx_status FROM finance_transactions WHERE id = OLD.transaction_id;
          IF tx_status = 'confirmed' THEN
            RAISE EXCEPTION 'confirmed financial context cannot be removed';
          END IF;
          RETURN OLD;
        END IF;

        IF TG_OP = 'UPDATE' THEN
          IF NEW.transaction_id <> OLD.transaction_id
             OR NEW.recorded_by_id <> OLD.recorded_by_id
             OR NEW.source <> OLD.source THEN
            RAISE EXCEPTION 'financial context provenance cannot be changed';
          END IF;

          SELECT status INTO tx_status FROM finance_transactions WHERE id = OLD.transaction_id;
          IF tx_status = 'confirmed' THEN
            RAISE EXCEPTION 'confirmed financial context cannot be changed';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER guard_finance_transaction_context_mutation
      BEFORE UPDATE OR DELETE ON finance_transaction_contexts
      FOR EACH ROW EXECUTE FUNCTION finance_guard_transaction_context_mutation();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS guard_finance_transaction_context_mutation ON finance_transaction_contexts"
    execute "DROP FUNCTION IF EXISTS finance_guard_transaction_context_mutation()"
    drop_table :finance_transaction_contexts
  end
end
