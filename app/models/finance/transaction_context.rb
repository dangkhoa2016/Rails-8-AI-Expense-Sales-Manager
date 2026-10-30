# frozen_string_literal: true

module Finance
  class TransactionContext < ApplicationRecord
    self.table_name = "finance_transaction_contexts"

    belongs_to :finance_transaction, class_name: "Finance::Transaction",
      foreign_key: :transaction_id, inverse_of: :context
    belongs_to :recorded_by, class_name: "User"
    validates :source, inclusion: { in: %w[manual demo_seed] }
    validates :purchase_details, length: { maximum: 1000 }, allow_blank: true
    validates :location_text, length: { maximum: 400 }, allow_blank: true
    validate :confirmed_context_is_readonly, on: :update

    before_validation :normalize_optional_text

    private

    def normalize_optional_text
      self.purchase_details = purchase_details.to_s.strip.presence
      self.location_text = location_text.to_s.strip.presence
    end

    def confirmed_context_is_readonly
      if finance_transaction&.confirmed?
        errors.add(:base, "Confirmed transaction context is immutable")
      end
    end
  end
end
