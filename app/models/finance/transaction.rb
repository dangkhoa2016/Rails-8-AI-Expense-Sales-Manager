# frozen_string_literal: true
module Finance
  class Transaction < ApplicationRecord
    self.table_name = 'finance_transactions'
    has_many :line_items, class_name: 'Finance::LineItem', foreign_key: :transaction_id, inverse_of: :finance_transaction, dependent: :restrict_with_exception
    has_many :document_versions, class_name: 'Finance::DocumentVersion', foreign_key: :transaction_id, inverse_of: :finance_transaction, dependent: :restrict_with_exception
    has_many :field_suggestions, class_name: 'Finance::FieldSuggestion', foreign_key: :transaction_id, dependent: :restrict_with_exception
    has_many :audit_events, class_name: 'Finance::AuditEvent', foreign_key: :transaction_id, dependent: :restrict_with_exception
    belongs_to :active_document_version, class_name: 'Finance::DocumentVersion', optional: true
    has_one :context, class_name: "Finance::TransactionContext", foreign_key: :transaction_id,
      inverse_of: :finance_transaction, dependent: :restrict_with_exception

    accepts_nested_attributes_for :context, update_only: true,
      reject_if: ->(attrs) {
        attrs['purchase_details'].blank? && attrs['occurred_time'].blank? && attrs['location_text'].blank?
      }


    has_one :correction_as_original, class_name: "Finance::Correction",
      foreign_key: :original_transaction_id, inverse_of: :original_transaction,
      dependent: :restrict_with_exception
    has_one :correction_as_replacement, class_name: "Finance::Correction",
      foreign_key: :replacement_transaction_id, inverse_of: :replacement_transaction,
      dependent: :restrict_with_exception

    has_many :line_import_batches, class_name: 'Finance::LineImportBatch', foreign_key: :transaction_id, dependent: :restrict_with_exception

    accepts_nested_attributes_for :line_items, allow_destroy: true, limit: 200,
      reject_if: ->(attrs) { attrs['description'].blank? && attrs['amount'].blank? }

    validates :workspace_id, :created_by_id, presence: true
    validates :kind, inclusion: { in: %w[income expense] }
    validates :status, inclusion: { in: %w[draft confirmed] }
    validates :currency_code, inclusion: { in: %w[VND] }
    validates :entry_source, inclusion: { in: %w[manual ai_assisted] }
    validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :transaction_date, :confirmed_by_id, :confirmed_at, presence: true, if: :confirmed?
    validates :amount, numericality: { greater_than: 0 }, if: :confirmed?
    validate :active_version_belongs_to_this_transaction
    validate :confirmed_record_is_readonly, on: :update

    scope :confirmed, -> { where(status: 'confirmed') }
    # Corrections replace the effective value without mutating or double-counting the original.
    scope :effective_confirmed, -> {
      confirmed.where.not(
        id: Finance::Correction.confirmed.select(:original_transaction_id)
      )
    }
    scope :for_workspace, ->(id) { where(workspace_id: id) }

    def confirmed? = status == 'confirmed'
    def draft? = status == 'draft'

    private

    def active_version_belongs_to_this_transaction
      return if active_document_version_id.blank?
      return if active_document_version&.transaction_id == id
      errors.add(:active_document_version, 'must belong to this transaction')
    end

    def confirmed_record_is_readonly
      return unless status_in_database == 'confirmed'
      errors.add(:base, 'Confirmed transactions are immutable; record a separate correction.')
    end
  end
end
