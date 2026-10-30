# frozen_string_literal: true

class CreateFinanceItemTags < ActiveRecord::Migration[8.1]
  def up
    create_table :finance_line_item_tags do |t|
      t.references :line_item, null: false, foreign_key: { to_table: :finance_line_items }
      t.references :category, null: false, foreign_key: { to_table: :finance_categories }
      t.timestamps
    end
    add_index :finance_line_item_tags, [:line_item_id, :category_id],
      unique: true, name: "idx_finance_line_item_tags_unique"

    # Legacy single category remains an immutable primary reporting classification.
    # Attach matching workspace tags to existing lines without changing their amounts.
    execute <<~SQL
      INSERT INTO finance_line_item_tags
        (line_item_id, category_id, created_at, updated_at)
      SELECT l.id, c.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM finance_line_items l
      INNER JOIN finance_transactions tx ON tx.id = l.transaction_id
      INNER JOIN finance_categories c
        ON c.workspace_id = tx.workspace_id AND c.key = l.category
      WHERE l.category IS NOT NULL
      ON CONFLICT (line_item_id, category_id) DO NOTHING;
    SQL

    execute <<~SQL
      CREATE FUNCTION finance_guard_line_item_tags() RETURNS trigger AS $$
      DECLARE
        item_tx bigint;
        item_workspace bigint;
        item_status text;
        tag_workspace bigint;
      BEGIN
        SELECT tx.id, tx.workspace_id, tx.status
        INTO item_tx, item_workspace, item_status
        FROM finance_line_items li
        JOIN finance_transactions tx ON tx.id = li.transaction_id
        WHERE li.id = CASE WHEN TG_OP = 'DELETE' THEN OLD.line_item_id ELSE NEW.line_item_id END;

        IF item_tx IS NULL OR item_status <> 'draft' THEN
          RAISE EXCEPTION 'Confirmed or missing transaction line tags are immutable';
        END IF;

        IF TG_OP <> 'DELETE' THEN
          SELECT workspace_id INTO tag_workspace
          FROM finance_categories WHERE id = NEW.category_id;
          IF tag_workspace IS DISTINCT FROM item_workspace THEN
            RAISE EXCEPTION 'Cross-workspace line tags are forbidden';
          END IF;
        END IF;

        IF TG_OP = 'UPDATE' THEN
          RAISE EXCEPTION 'Update tag links by delete/insert only';
        END IF;

        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER guard_finance_line_item_tags
      BEFORE INSERT OR UPDATE OR DELETE ON finance_line_item_tags
      FOR EACH ROW EXECUTE FUNCTION finance_guard_line_item_tags();
    SQL
  end

  def down
    drop_table :finance_line_item_tags
    execute "DROP FUNCTION IF EXISTS finance_guard_line_item_tags()"
  end
end
