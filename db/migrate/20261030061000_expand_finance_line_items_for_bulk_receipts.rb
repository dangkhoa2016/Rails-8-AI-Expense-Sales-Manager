# frozen_string_literal: true

class ExpandFinanceLineItemsForBulkReceipts < ActiveRecord::Migration[8.1]
  def change
    add_column :finance_line_items, :quantity, :decimal, precision: 12, scale: 3
    add_column :finance_line_items, :unit_price, :decimal, precision: 20, scale: 2
    add_column :finance_line_items, :category, :string, limit: 100
    add_check_constraint :finance_line_items, 'quantity IS NULL OR quantity > 0',
      name: 'finance_line_items_quantity_check'
    add_check_constraint :finance_line_items, 'unit_price IS NULL OR unit_price >= 0',
      name: 'finance_line_items_unit_price_check'
    create_table :finance_line_import_batches do |t|
      t.references :transaction, null: false, foreign_key: { to_table: :finance_transactions }
      t.string :sha256, limit: 64, null: false
      t.integer :row_count, null: false
      t.bigint :uploaded_by_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :finance_line_import_batches, [:transaction_id, :sha256],
      unique: true, name: 'idx_finance_line_import_replay'
    add_check_constraint :finance_line_import_batches,
      'row_count BETWEEN 1 AND 500 AND char_length(sha256) = 64',
      name: 'finance_line_import_valid_check'
    execute <<~SQL
      CREATE TRIGGER deny_finance_line_import_mutation
      BEFORE UPDATE OR DELETE ON finance_line_import_batches
      FOR EACH ROW EXECUTE FUNCTION finance_deny_history_mutation();
    SQL
  end
end
