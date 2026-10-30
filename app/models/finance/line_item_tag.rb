# frozen_string_literal: true

module Finance
  class LineItemTag < ApplicationRecord
    self.table_name = "finance_line_item_tags"
    belongs_to :line_item, class_name: "Finance::LineItem", inverse_of: :line_item_tags
    belongs_to :tag, class_name: "Finance::Tag"

    validates :tag_id, uniqueness: { scope: :line_item_id }
    validate :same_workspace_and_editable

    private

    def same_workspace_and_editable
      return unless line_item && tag
      tx = line_item.finance_transaction
      errors.add(:base, "Draft line items only") unless tx&.draft?
      errors.add(:tag, "must belong to the same workspace") unless
        tx&.workspace_id == tag.workspace_id
    end
  end
end
