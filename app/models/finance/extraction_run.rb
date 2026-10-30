# frozen_string_literal: true
module Finance
  class ExtractionRun < ApplicationRecord
    self.table_name = 'finance_extraction_runs'
    belongs_to :document_version, class_name: 'Finance::DocumentVersion'
    has_many :field_suggestions, class_name: 'Finance::FieldSuggestion', foreign_key: :extraction_run_id, dependent: :restrict_with_exception
    validates :model_sha256, :prompt_sha256, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :schema_version, presence: true
    validates :parse_status, inclusion: { in: %w[readable partially_readable unreadable processing_error] }
    def readonly? = persisted?
  end
end
