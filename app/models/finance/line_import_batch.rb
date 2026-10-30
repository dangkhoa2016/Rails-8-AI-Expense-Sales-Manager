# frozen_string_literal: true
module Finance
  class LineImportBatch < ApplicationRecord
    self.table_name = "finance_line_import_batches"
    belongs_to :finance_transaction, class_name: "Finance::Transaction", foreign_key: :transaction_id
    validates :sha256, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :row_count, inclusion: { in: 1..500 }
    def readonly? = persisted?
  end
end
