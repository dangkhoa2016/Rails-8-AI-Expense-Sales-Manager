# frozen_string_literal: true
module Finance
  class DocumentVersion < ApplicationRecord
    self.table_name = 'finance_document_versions'
    belongs_to :finance_transaction, class_name: 'Finance::Transaction', foreign_key: :transaction_id, inverse_of: :document_versions
    has_one_attached :image
    has_many :extraction_runs, class_name: 'Finance::ExtractionRun', foreign_key: :document_version_id, dependent: :restrict_with_exception
    validates :version_number, numericality: { only_integer: true, greater_than: 0 }
    validates :sha256, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :uploaded_by_id, :original_filename, :content_type, presence: true
    validates :byte_size, numericality: { greater_than: 0, less_than_or_equal_to: 10.megabytes }
    def readonly? = persisted?
  end
end
