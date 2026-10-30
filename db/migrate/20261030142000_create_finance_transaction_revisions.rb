# frozen_string_literal: true

class CreateFinanceTransactionRevisions < ActiveRecord::Migration[8.1]
  def up
    create_table :finance_transaction_revisions do |t|
      t.references :transaction, null: false, foreign_key: { to_table: :finance_transactions }
      t.references :workspace, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.integer :version_number, null: false
      t.string :action, null: false
      t.text :reason, null: false
      t.jsonb :before_state, null: false, default: {}
      t.jsonb :after_state, null: false, default: {}
      t.jsonb :change_set, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :finance_transaction_revisions, [:transaction_id, :version_number],
      unique: true, name: 'idx_finance_transaction_revision_version'
    add_index :finance_transaction_revisions, [:workspace_id, :created_at],
      name: 'idx_finance_transaction_revision_workspace_time'
    add_check_constraint :finance_transaction_revisions, 'version_number > 0',
      name: 'finance_transaction_revision_positive_version'
    add_check_constraint :finance_transaction_revisions, 'char_length(btrim(reason)) BETWEEN 10 AND 2000',
      name: 'finance_transaction_revision_reason_length'
    execute <<~SQL
      CREATE TRIGGER deny_finance_transaction_revisions_mutation
      BEFORE UPDATE OR DELETE ON finance_transaction_revisions
      FOR EACH ROW EXECUTE FUNCTION finance_deny_history_mutation();
    SQL
  end

  def down
    execute 'DROP TRIGGER IF EXISTS deny_finance_transaction_revisions_mutation ON finance_transaction_revisions'
    drop_table :finance_transaction_revisions
  end
end
