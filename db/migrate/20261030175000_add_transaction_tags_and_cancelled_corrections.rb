# frozen_string_literal: true

class AddTransactionTagsAndCancelledCorrections < ActiveRecord::Migration[8.1]
  def up
    # Preserve preexisting legacy amounts without inventing historical items.
    # App-created drafts use the managed total and require real user-entered lines.
    add_column :finance_transactions, :line_total_managed, :boolean,
      null: false, default: false
    # Historical data is untouched; only future correction drafts can be cancelled.
    remove_check_constraint :finance_transactions, name: "finance_transactions_status_check"
    add_check_constraint :finance_transactions, "status IN ('draft', 'confirmed', 'cancelled')",
      name: "finance_transactions_status_check"
    remove_check_constraint :finance_corrections, name: "finance_corrections_status_check"
    add_check_constraint :finance_corrections, "status IN ('draft', 'confirmed', 'cancelled')",
      name: "finance_corrections_status_check"
    remove_index :finance_corrections, name: "idx_finance_correction_original"
    add_index :finance_corrections, :original_transaction_id,
      unique: true, where: "status IN ('draft','confirmed')",
      name: "idx_finance_correction_original"
    execute <<~SQL
      CREATE OR REPLACE FUNCTION finance_guard_correction_mutation() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'finance corrections cannot be deleted';
        END IF;
        IF TG_OP = 'UPDATE' THEN
          IF OLD.status IN ('confirmed','cancelled') THEN
            RAISE EXCEPTION 'completed finance correction cannot be modified';
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
    SQL

    # Cancelled replacement rows are read-only even when accessed via raw SQL.
    # Confirmed records already have their own immutable guards.
    execute <<~SQL
      CREATE FUNCTION finance_deny_cancelled_transaction_mutation() RETURNS trigger AS $$
      BEGIN
        IF OLD.status = 'cancelled' THEN
          RAISE EXCEPTION 'cancelled correction draft cannot be modified or deleted';
        END IF;
        RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER deny_cancelled_finance_transaction_mutation
      BEFORE UPDATE OR DELETE ON finance_transactions FOR EACH ROW
      EXECUTE FUNCTION finance_deny_cancelled_transaction_mutation();

      CREATE FUNCTION finance_deny_cancelled_item_mutation() RETURNS trigger AS $$
      BEGIN
        IF EXISTS (SELECT 1 FROM finance_transactions WHERE
           id=CASE WHEN TG_OP='DELETE' THEN OLD.transaction_id ELSE NEW.transaction_id END
           AND status='cancelled')
           OR (TG_OP='UPDATE' AND EXISTS (SELECT 1 FROM finance_transactions
           WHERE id=OLD.transaction_id AND status='cancelled')) THEN
          RAISE EXCEPTION 'cancelled finance items cannot be changed';
        END IF;
        RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER deny_cancelled_finance_line_item_mutation
      BEFORE INSERT OR UPDATE OR DELETE ON finance_line_items FOR EACH ROW
      EXECUTE FUNCTION finance_deny_cancelled_item_mutation();

      CREATE FUNCTION finance_deny_cancelled_context_mutation() RETURNS trigger AS $$
      BEGIN
        IF EXISTS (SELECT 1 FROM finance_transactions WHERE
          id=CASE WHEN TG_OP='DELETE' THEN OLD.transaction_id ELSE NEW.transaction_id END
          AND status='cancelled') THEN
          RAISE EXCEPTION 'cancelled finance context cannot be changed';
        END IF;
        RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER deny_cancelled_finance_context_mutation
      BEFORE INSERT OR UPDATE OR DELETE ON finance_transaction_contexts FOR EACH ROW
      EXECUTE FUNCTION finance_deny_cancelled_context_mutation();
    SQL

    create_table :finance_transaction_tags do |t|
      t.references :transaction, null: false, foreign_key: {to_table: :finance_transactions}
      t.references :category, null: false, foreign_key: {to_table: :finance_categories}
      t.timestamps
    end
    add_index :finance_transaction_tags, [:transaction_id, :category_id],
      unique: true, name: "idx_finance_transaction_tags_unique"
    execute <<~SQL
      CREATE FUNCTION finance_guard_transaction_tags() RETURNS trigger AS $$
      DECLARE
        parent_workspace bigint;
        parent_status text;
        tag_workspace bigint;
      BEGIN
        SELECT workspace_id, status INTO parent_workspace, parent_status
          FROM finance_transactions
          WHERE id = CASE WHEN TG_OP = 'DELETE' THEN OLD.transaction_id ELSE NEW.transaction_id END;
        IF parent_workspace IS NULL OR parent_status <> 'draft' THEN
          RAISE EXCEPTION 'Only editable draft transactions can change tags';
        END IF;
        IF TG_OP = 'UPDATE' THEN
          RAISE EXCEPTION 'Transaction tag links are immutable; delete and insert instead';
        END IF;
        IF TG_OP = 'INSERT' THEN
          SELECT workspace_id INTO tag_workspace FROM finance_categories WHERE id = NEW.category_id;
          IF tag_workspace IS DISTINCT FROM parent_workspace THEN
            RAISE EXCEPTION 'Transaction tag must belong to same workspace';
          END IF;
        END IF;
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER guard_finance_transaction_tags
        BEFORE INSERT OR UPDATE OR DELETE ON finance_transaction_tags
        FOR EACH ROW EXECUTE FUNCTION finance_guard_transaction_tags();
    SQL
    # Existing category is an internal primary reporting key, not an extra user choice.
    # Historical confirmed rows are never touched; only draft tags are backfilled.
    execute <<~SQL
      INSERT INTO finance_transaction_tags
        (transaction_id, category_id, created_at, updated_at)
      SELECT tx.id, c.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM finance_transactions tx
      JOIN finance_categories c ON c.workspace_id=tx.workspace_id AND c.key=tx.category
      WHERE tx.status='draft' AND tx.category IS NOT NULL
      ON CONFLICT (transaction_id, category_id) DO NOTHING;
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS deny_cancelled_finance_context_mutation ON finance_transaction_contexts"
    execute "DROP FUNCTION IF EXISTS finance_deny_cancelled_context_mutation()"
    execute "DROP TRIGGER IF EXISTS deny_cancelled_finance_line_item_mutation ON finance_line_items"
    execute "DROP FUNCTION IF EXISTS finance_deny_cancelled_item_mutation()"
    execute "DROP TRIGGER IF EXISTS deny_cancelled_finance_transaction_mutation ON finance_transactions"
    execute "DROP FUNCTION IF EXISTS finance_deny_cancelled_transaction_mutation()"
    remove_column :finance_transactions, :line_total_managed
    execute "DROP TRIGGER IF EXISTS guard_finance_transaction_tags ON finance_transaction_tags"
    drop_table :finance_transaction_tags
    execute "DROP FUNCTION IF EXISTS finance_guard_transaction_tags()"
    remove_index :finance_corrections, name: "idx_finance_correction_original"
    add_index :finance_corrections, :original_transaction_id,
      unique: true, name: "idx_finance_correction_original"
    remove_check_constraint :finance_corrections, name: "finance_corrections_status_check"
    add_check_constraint :finance_corrections, "status IN ('draft','confirmed')", name: "finance_corrections_status_check"
    remove_check_constraint :finance_transactions, name: "finance_transactions_status_check"
    add_check_constraint :finance_transactions, "status IN ('draft','confirmed')", name: "finance_transactions_status_check"
  end
end
