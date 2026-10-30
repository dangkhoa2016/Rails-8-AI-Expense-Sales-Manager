# frozen_string_literal: true

module Finance
  class LineItemTag < ApplicationRecord
    self.table_name = "finance_line_item_tags"
    belongs_to :line_item, class_name: "Finance::LineItem", inverse_of: :line_item_tags
    belongs_to :category, class_name: "Finance::Category"

    validates :category_id, uniqueness: { scope: :line_item_id }
    validate :same_workspace_and_editable

    private

    def same_workspace_and_editable
      return unless line_item && category
      tx = line_item.finance_transaction
      errors.add(:base, "Draft line items only") unless tx&.draft?
      errors.add(:category, "must belong to the same workspace") unless
        tx&.workspace_id == category.workspace_id
    end
  end
end
