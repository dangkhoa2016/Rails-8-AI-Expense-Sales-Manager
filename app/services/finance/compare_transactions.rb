# frozen_string_literal: true

module Finance
  class CompareTransactions
    FIELDS = %w[transaction_date amount description category].freeze
    def self.call(original:, replacement:)
      raise ArgumentError, "Different workspaces" unless original.workspace_id == replacement.workspace_id
      fields = FIELDS.filter_map do |key|
        old = original.public_send(key)
        new_value = replacement.public_send(key)
        next if old == new_value
        {field: key, before: old, after: new_value}
      end
      ["purchase_details", "occurred_time", "location_text"].each do |key|
        left = original.context&.public_send(key)
        right = replacement.context&.public_send(key)
        left = left.strftime("%H:%M") if key == "occurred_time" && left
        right = right.strftime("%H:%M") if key == "occurred_time" && right
        fields << {field: key, before: left, after: right} unless left == right
      end
      source_lines = original.line_items.includes(:tags).order(:position, :id).to_a
      draft_lines = replacement.line_items.includes(:tags).order(:position, :id).to_a
      original_by_position = source_lines.index_by(&:position)
      replacement_by_position = draft_lines.index_by(&:position)
      item_diffs = (original_by_position.keys | replacement_by_position.keys).sort.filter_map do |position|
        a = original_by_position[position]
        b = replacement_by_position[position]
        left = a && a.attributes.slice("description", "amount", "quantity", "unit_price",
                                      "occurred_time", "location_text", "category")
        right = b && b.attributes.slice("description", "amount", "quantity", "unit_price",
                                       "occurred_time", "location_text", "category")
        left = left.merge("tags" => a.tags.map(&:key).sort) if left
        right = right.merge("tags" => b.tags.map(&:key).sort) if right
        next if left == right
        {position: position, original: left, replacement: right}
      end
      {fields: fields,
       source_count: source_lines.length, draft_count: draft_lines.length,
       source_total: source_lines.sum { |i| i.amount || 0 },
       draft_total: draft_lines.sum { |i| i.amount || 0 },
       item_differences: item_diffs,
       source_tags: effective_tags(original),
       draft_tags: effective_tags(replacement)}
    end

    def self.effective_tags(transaction)
      tags = transaction.tags.order(:key).pluck(:key)
      tags = [transaction.category] if tags.empty? && transaction.category.present?
      tags.sort
    end
  end
end
