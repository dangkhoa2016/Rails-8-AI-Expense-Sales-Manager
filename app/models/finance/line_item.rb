# frozen_string_literal: true
module Finance
  class LineItem < ApplicationRecord
    self.table_name = 'finance_line_items'
    belongs_to :finance_transaction, class_name: 'Finance::Transaction', foreign_key: :transaction_id, inverse_of: :line_items
    validates :description, presence: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :entry_source, inclusion: { in: %w[manual ai_approved] }
    validate :transaction_is_draft
    private
    def transaction_is_draft
      errors.add(:base, 'Cannot change confirmed transaction line items') unless finance_transaction&.draft?
    end
  end
end
