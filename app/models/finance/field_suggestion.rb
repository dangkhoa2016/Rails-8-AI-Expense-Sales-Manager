# frozen_string_literal: true
module Finance
  class FieldSuggestion < ApplicationRecord
    self.table_name = 'finance_field_suggestions'
    belongs_to :finance_transaction, class_name: 'Finance::Transaction', foreign_key: :transaction_id
    belongs_to :extraction_run, class_name: 'Finance::ExtractionRun'
    validates :field_key, presence: true
    validates :review_status, inclusion: { in: %w[pending accepted rejected] }
    validate :same_transaction_as_extraction
    scope :pending, -> { where(review_status: 'pending') }
    private
    def same_transaction_as_extraction
      return if extraction_run&.document_version&.transaction_id == transaction_id
      errors.add(:extraction_run, 'must belong to the same transaction')
    end
  end
end
