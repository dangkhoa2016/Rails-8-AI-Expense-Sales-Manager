# frozen_string_literal: true
module Finance
  class LineItem < ApplicationRecord
    self.table_name = 'finance_line_items'
    belongs_to :finance_transaction, class_name: 'Finance::Transaction', foreign_key: :transaction_id, inverse_of: :line_items
    has_many :line_item_tags, class_name: "Finance::LineItemTag", dependent: :destroy,
      inverse_of: :line_item
    has_many :tags, through: :line_item_tags, source: :category, class_name: "Finance::Category"
    validates :description, presence: true, length: { maximum: 500 }
    validates :category, length: { maximum: 100 }, allow_nil: true
    validates :location_text, length: { maximum: 400 }, allow_nil: true
    validates :quantity, numericality: { greater_than: 0 }, allow_nil: true
    validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :amount, presence: true
    # occurred_on is historical read-only data. The effective date is always
    # sourced from the parent transaction; new item inputs never set it.
    def effective_date = finance_transaction&.transaction_date
    before_validation :normalize_values

    def normalize_values
      self.description = description.to_s.strip
      self.category = category.to_s.strip.presence
      self.location_text = location_text.to_s.strip.presence
    end
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
