# frozen_string_literal: true
require "digest"

class ReplaceLegacyCategoriesWithTags < ActiveRecord::Migration[8.1]
  KEY_RE = /\A[a-z][a-z0-9_]{1,49}\z/
  # Backfill existing tag links BEFORE deleting the single-category strings.
  # Ledger amounts, dates, statuses and immutable revision/audit JSON are untouched.
  def up
    names = select_rows(<<~SQL)
      SELECT DISTINCT workspace_id, category FROM finance_transactions WHERE category IS NOT NULL AND btrim(category)<>''
      UNION
      SELECT DISTINCT tx.workspace_id, li.category
      FROM finance_line_items li JOIN finance_transactions tx ON tx.id=li.transaction_id
      WHERE li.category IS NOT NULL AND btrim(li.category)<>''
    SQL
    key_map = {}
    names.each do |workspace_id, raw_value|
      key = raw_value.match?(KEY_RE) ? raw_value : "legacy_#{Digest::SHA256.hexdigest(raw_value)[0,32]}"
      name = raw_value.tr("_", " ").strip.first(120)
      name = "Imported tag" if name.empty?
      execute <<~SQL
        INSERT INTO finance_categories (workspace_id, key, name_en, name_vi, active, created_at, updated_at)
        VALUES (#{workspace_id.to_i}, #{quote(key)}, #{quote(name)}, #{quote(name)}, true, NOW(), NOW())
        ON CONFLICT (workspace_id, key) DO NOTHING
      SQL
      key_map[[workspace_id.to_i, raw_value]] = key
    end

    # Historical joins are metadata, not changes to immutable confirmed ledger
    # rows. Temporarily bypass ONLY association mutability triggers for this
    # one-time strictly insert-only preservation, in a transactional migration.
    execute "ALTER TABLE finance_line_item_tags DISABLE TRIGGER guard_finance_line_item_tags"
    execute "ALTER TABLE finance_transaction_tags DISABLE TRIGGER guard_finance_transaction_tags"
    begin
      key_map.each do |(workspace_id, old), key|
        execute <<~SQL
          INSERT INTO finance_transaction_tags (transaction_id, category_id, created_at, updated_at)
          SELECT tx.id, t.id, NOW(), NOW()
          FROM finance_transactions tx
          JOIN finance_categories t ON t.workspace_id=tx.workspace_id AND t.key=#{quote(key)}
          WHERE tx.workspace_id=#{workspace_id} AND tx.category=#{quote(old)}
            AND NOT EXISTS(SELECT 1 FROM finance_transaction_tags rel WHERE rel.transaction_id=tx.id)
          ON CONFLICT(transaction_id,category_id) DO NOTHING
        SQL
        execute <<~SQL
          INSERT INTO finance_line_item_tags (line_item_id, category_id, created_at, updated_at)
          SELECT li.id, t.id, NOW(), NOW()
          FROM finance_line_items li
          JOIN finance_transactions tx ON tx.id=li.transaction_id
          JOIN finance_categories t ON t.workspace_id=tx.workspace_id AND t.key=#{quote(key)}
          WHERE tx.workspace_id=#{workspace_id} AND li.category=#{quote(old)}
            AND NOT EXISTS(SELECT 1 FROM finance_line_item_tags rel WHERE rel.line_item_id=li.id)
          ON CONFLICT(line_item_id,category_id) DO NOTHING
        SQL
      end
    ensure
      execute "ALTER TABLE finance_line_item_tags ENABLE TRIGGER guard_finance_line_item_tags"
      execute "ALTER TABLE finance_transaction_tags ENABLE TRIGGER guard_finance_transaction_tags"
    end

    missing_tx = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM finance_transactions tx
      WHERE tx.category IS NOT NULL AND btrim(tx.category)<>''
      AND NOT EXISTS (SELECT 1 FROM finance_transaction_tags tt WHERE tt.transaction_id=tx.id)
    SQL
    missing_item = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM finance_line_items li
      WHERE li.category IS NOT NULL AND btrim(li.category)<>''
      AND NOT EXISTS (SELECT 1 FROM finance_line_item_tags it WHERE it.line_item_id=li.id)
    SQL
    raise ActiveRecord::MigrationError, "Legacy tag preservation failed: tx=#{missing_tx}, items=#{missing_item}" if missing_tx.positive? || missing_item.positive?

    rename_table :finance_categories, :finance_tags
    rename_column :finance_transaction_tags, :category_id, :tag_id
    rename_column :finance_line_item_tags, :category_id, :tag_id

    # Legacy PL/pgSQL trigger bodies are stored as source; PostgreSQL renaming
    # the underlying relation/column does not update those source strings.
    %w[finance_guard_line_item_tags finance_guard_transaction_tags].each do |fn|
      definition = select_value("SELECT pg_get_functiondef('#{fn}()'::regprocedure)")
      execute definition.gsub("finance_categories", "finance_tags").gsub("category_id", "tag_id")
    end
    rename_index :finance_tags, :idx_finance_categories_tenant_key, :idx_finance_tags_tenant_key
    rename_index :finance_line_item_tags, :idx_finance_line_item_tags_unique, :idx_finance_line_item_tags_unique_by_tag
    rename_index :finance_transaction_tags, :idx_finance_transaction_tags_unique, :idx_finance_transaction_tags_unique_by_tag
    remove_column :finance_transactions, :category, :string
    remove_column :finance_line_items, :category, :string, limit: 100
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Legacy category strings were retired after preserving associations as Tags"
  end
end
