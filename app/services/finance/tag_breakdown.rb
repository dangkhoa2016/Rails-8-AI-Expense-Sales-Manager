# frozen_string_literal: true

module Finance
  # Group financial amounts by the FIRST user-selected Tag only. Secondary
  # labels must never cause revenue or costs to be counted more than once.
  class TagBreakdown
    def self.call(transactions:, item_level:)
      source_table = item_level ? "finance_line_items" : "finance_transactions"
      fk = item_level ? "line_item_id" : "transaction_id"
      association = item_level ? "finance_line_item_tags" : "finance_transaction_tags"
      filter = item_level ? "source.transaction_id" : "source.id"
      subquery = transactions.reselect(:id).reorder(nil).to_sql
      sql = <<~SQL
        SELECT COALESCE(first_tag.key, '') AS tag_key, COALESCE(SUM(source.amount), 0) AS total
        FROM #{source_table} source
        LEFT JOIN LATERAL (
          SELECT tag.key FROM #{association} rel
          JOIN finance_tags tag ON tag.id=rel.tag_id
          WHERE rel.#{fk}=source.id
          ORDER BY rel.id LIMIT 1
        ) first_tag ON TRUE
        WHERE #{filter} IN (#{subquery})
        GROUP BY first_tag.key
      SQL
      Finance::Transaction.connection.select_all(sql).each_with_object({}) do |row, result|
        result[row.fetch("tag_key")] = BigDecimal(row.fetch("total").to_s)
      end
    end
  end
end
