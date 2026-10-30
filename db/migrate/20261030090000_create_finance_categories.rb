# frozen_string_literal: true

class CreateFinanceCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :finance_categories do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :key, null: false, limit: 50
      t.string :name_en, null: false, limit: 120
      t.string :name_vi, null: false, limit: 120
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :finance_categories, [:workspace_id, :key], unique: true,
      name: "idx_finance_categories_tenant_key"
    add_check_constraint :finance_categories,
      "key ~ '^[a-z][a-z0-9_]{1,49}$'", name: "finance_categories_safe_key"
    add_check_constraint :finance_categories,
      "char_length(btrim(name_en)) > 0 AND char_length(btrim(name_vi)) > 0",
      name: "finance_categories_nonempty_names"
  end
end
