# frozen_string_literal: true

module Finance
  class TransactionTag < ApplicationRecord
    self.table_name = "finance_transaction_tags"
    belongs_to :finance_transaction, class_name: "Finance::Transaction", foreign_key: :transaction_id,
      inverse_of: :transaction_tags
    belongs_to :category, class_name: "Finance::Category"
    validates :category_id, uniqueness: {scope: :transaction_id}
    validate :editable_and_same_workspace

    private

    def editable_and_same_workspace
      return unless finance_transaction && category
      errors.add(:base, "Draft transaction required") unless finance_transaction.draft?
      errors.add(:category, "must be in the same workspace") unless
        finance_transaction.workspace_id == category.workspace_id
    end
  end
end
