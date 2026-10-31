# frozen_string_literal: true

module Finance
  # Read-only ordering for the itemized ledger view. All SQL identifiers and
  # directions come from a closed allowlist; the user can never supply SQL.
  # The persisted position is never updated by sorting.
  class LineItemSorting
    FIELDS = %w[position description amount occurred_time location_text].freeze
    DIRECTIONS = %w[asc desc].freeze

    attr_reader :field, :direction

    def self.from_params(params)
      field = params[:sort].presence || "position"
      direction = params[:direction].presence || "asc"
      unless FIELDS.include?(field) && DIRECTIONS.include?(direction)
        raise ActionController::BadRequest, "Invalid item sorting"
      end
      new(field: field, direction: direction)
    end

    def initialize(field:, direction:)
      @field, @direction = field, direction
    end

    def default? = field == "position" && direction == "asc"

    def query_params
      default? ? {} : { sort: field, direction: direction }
    end

    def next_direction(for_field)
      for_field == field && direction == "asc" ? "desc" : "asc"
    end

    def apply(scope)
      order = case field
      when "position" then "finance_line_items.position #{direction.upcase}"
      when "description" then "LOWER(finance_line_items.description) #{direction.upcase}"
      when "amount" then "finance_line_items.amount #{direction.upcase}"
      when "occurred_time" then "finance_line_items.occurred_time #{direction.upcase} NULLS LAST"
      when "location_text" then "LOWER(NULLIF(BTRIM(finance_line_items.location_text), '')) #{direction.upcase} NULLS LAST"
      end
      scope.reorder(Arel.sql(order), :position, :id)
    end

    def page_of(scope, item_id, per_page: 25)
      index = apply(scope).pluck(:id).index(item_id)
      index ? (index / per_page) + 1 : 1
    end
  end
end
