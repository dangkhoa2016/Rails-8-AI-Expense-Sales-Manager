# frozen_string_literal: true

module Finance
  class Correction < ApplicationRecord
    self.table_name = "finance_corrections"

    belongs_to :original_transaction, class_name: "Finance::Transaction"
    belongs_to :replacement_transaction, class_name: "Finance::Transaction"
    belongs_to :requested_by, class_name: "User"
    belongs_to :confirmed_by, class_name: "User", optional: true

    validates :status, inclusion: { in: %w[draft confirmed] }
    validates :reason, presence: true, length: { minimum: 10, maximum: 2000 }
    validates :workspace_id, :requested_by_id, presence: true
    validate :consistent_transactions
    validate :confirmed_record_readonly, on: :update

    scope :confirmed, -> { where(status: "confirmed") }

    def draft? = status == "draft"
    def confirmed? = status == "confirmed"

    private

    def consistent_transactions
      return unless original_transaction && replacement_transaction
      unless original_transaction.workspace_id == workspace_id &&
             replacement_transaction.workspace_id == workspace_id &&
             original_transaction.kind == replacement_transaction.kind
        errors.add(:base, "Correction must stay in the same workspace and transaction type")
      end
      errors.add(:base, "Correction source must be confirmed") unless original_transaction.confirmed?
    end

    def confirmed_record_readonly
      errors.add(:base, "Confirmed corrections are immutable") if status_in_database == "confirmed"
    end
  end
end
