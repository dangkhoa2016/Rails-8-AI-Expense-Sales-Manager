# frozen_string_literal: true

module Finance
  class TransactionRevision < ApplicationRecord
    self.table_name = "finance_transaction_revisions"

    belongs_to :finance_transaction, class_name: "Finance::Transaction", foreign_key: :transaction_id,
      inverse_of: :revisions
    belongs_to :workspace
    belongs_to :actor, class_name: "User"

    validates :version_number, numericality: { only_integer: true, greater_than: 0 }
    validates :reason, presence: true, length: { minimum: 10, maximum: 2000 }
    validates :action, inclusion: { in: %w[draft_edited correction_requested correction_confirmed correction_cancelled] }
    validate :workspace_matches_transaction

    def readonly? = persisted?

    private

    def workspace_matches_transaction
      errors.add(:workspace_id, "must match transaction") if
        finance_transaction && workspace_id != finance_transaction.workspace_id
    end
  end
end
