# frozen_string_literal: true
module Finance
  class AuditEvent < ApplicationRecord
    self.table_name = 'finance_audit_events'
    belongs_to :finance_transaction, class_name: 'Finance::Transaction', foreign_key: :transaction_id
    validates :workspace_id, :actor_id, :event_type, presence: true
    validate :workspace_matches_transaction
    def readonly? = persisted?
    private
    def workspace_matches_transaction
      errors.add(:workspace_id, 'does not match transaction') if finance_transaction && workspace_id != finance_transaction.workspace_id
    end
  end
end
