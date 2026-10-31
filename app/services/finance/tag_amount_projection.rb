# frozen_string_literal: true

module Finance
  # A read-only projection of money attributable to the selected Tags.
  #
  # - Direct matching transaction Tag: entire transaction amount, exactly once.
  # - Otherwise: only line items with ANY matching Tag, each item's amount once.
  # - A transaction with both kinds of matches is counted only by the direct
  #   transaction Tag (no duplicate line-item money).
  #
  # Original stored transaction and line-item amounts are never altered.
  # Loading is batched, so a long report does not preload all line items at once.
  class TagAmountProjection
    Row = Struct.new(:id, :kind, :date, :matched_amount, :original_amount, keyword_init: true)

    attr_reader :rows, :breakdown

    def initialize(transactions:, tag_filter:)
      raise ArgumentError, "Select at least one Tag" unless tag_filter.active?

      chosen = tag_filter.selected_ids.to_set
      tag_keys = tag_filter.available_tags.index_by(&:id).transform_values(&:key)
      @rows = []
      @breakdown = Hash.new { |hash, key| hash[key] = BigDecimal("0") }

      transactions.includes(:transaction_tags, line_items: :line_item_tags).find_each(batch_size: 200) do |tx|
        # Relations are ordered by the original attachment id, for stable
        # first-matching-Tag allocation when more than one Tag is selected.
        direct = tx.transaction_tags.select { |link| chosen.include?(link.tag_id) }.min_by(&:id)
        if direct
          amount = tx.amount || BigDecimal("0")
          @breakdown[tag_keys.fetch(direct.tag_id)] += amount if tx.kind == "expense"
        else
          amount = BigDecimal("0")
          tx.line_items.each do |item|
            match = item.line_item_tags.select { |link| chosen.include?(link.tag_id) }.min_by(&:id)
            next unless match
            item_amount = item.amount || BigDecimal("0")
            amount += item_amount
            @breakdown[tag_keys.fetch(match.tag_id)] += item_amount if tx.kind == "expense"
          end
        end
        @rows << Row.new(
          id: tx.id, kind: tx.kind, date: tx.transaction_date,
          matched_amount: amount, original_amount: tx.amount || BigDecimal("0")
        )
      end
    end

    def totals
      rows.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |row, result|
        result[row.kind] += row.matched_amount
      end
    end

    def amounts_by_id
      rows.to_h { |row| [row.id, row.matched_amount] }
    end

    def month_totals
      rows.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |row, result|
        result[[row.date.beginning_of_month, row.kind]] += row.matched_amount
      end
    end

    def day_totals
      rows.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |row, result|
        result[[row.date, row.kind]] += row.matched_amount
      end
    end
  end
end
