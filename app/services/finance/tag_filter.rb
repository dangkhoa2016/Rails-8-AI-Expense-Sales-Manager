# frozen_string_literal: true

module Finance
  # Select full transactions that have ANY selected Tag at transaction OR item level.
  # Correlated EXISTS avoids multiplying transactions and their monetary amounts
  # when one transaction has multiple matching Tags and line items.
  class TagFilter
    MAX_SELECTION = 50
    attr_reader :available_tags, :selected_ids

    def self.for_params(params, workspace:)
      tags = Finance::Tag.for_workspace(workspace.id).order(:name_vi, :id).to_a
      raw = params[:tag_ids]
      unless raw.nil? || raw.is_a?(Array)
        raise ActionController::BadRequest, "Tag selection must be an array"
      end
      values = Array(raw).reject(&:blank?)
      if values.length > MAX_SELECTION || values.any? { |id| !id.to_s.match?(/\A[1-9]\d*\z/) }
        raise ActionController::BadRequest, "Invalid Tag selection"
      end
      ids = values.map(&:to_i).uniq
      unless (ids - tags.map(&:id)).empty?
        raise ActionController::BadRequest, "Tag does not belong to workspace"
      end
      new(available_tags: tags, selected_ids: ids)
    end

    def initialize(available_tags:, selected_ids:)
      @available_tags = available_tags
      @selected_ids = selected_ids
    end

    def active? = selected_ids.any?

    def query_params
      active? ? { tag_ids: selected_ids } : {}
    end

    def selected_labels
      available_tags.select { |tag| selected_ids.include?(tag.id) }.map(&:label)
    end

    def apply(scope)
      return scope unless active?
      scope.where(<<~SQL, ids: selected_ids)
        EXISTS (
          SELECT 1 FROM finance_transaction_tags direct_tags
          WHERE direct_tags.transaction_id = finance_transactions.id
            AND direct_tags.tag_id IN (:ids)
        ) OR EXISTS (
          SELECT 1 FROM finance_line_items tag_items
          INNER JOIN finance_line_item_tags item_tags ON item_tags.line_item_id = tag_items.id
          WHERE tag_items.transaction_id = finance_transactions.id
            AND item_tags.tag_id IN (:ids)
        )
      SQL
    end
  end
end
