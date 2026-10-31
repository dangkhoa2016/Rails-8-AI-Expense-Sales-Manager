# frozen_string_literal: true

module Finance
  # Read-only, tenant-safe filtering of items inside the already scoped parent
  # transaction. No financial figures or persisted item positions are changed.
  class LineItemFiltering
    KEYS = %w[name time_from time_to amount_min amount_max].freeze
    TIME_FORMAT = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/
    AMOUNT_FORMAT = /\A\d{1,12}(?:\.\d{1,2})?\z/

    attr_reader :name, :time_from, :time_to, :amount_min, :amount_max

    def self.from_params(params)
      inputs = KEYS.to_h do |key|
        value = params[key]
        raise ActionController::BadRequest, "Invalid item filter" unless value.nil? || value.is_a?(String)
        [key, value.to_s.strip]
      end
      raise ActionController::BadRequest, "Invalid item name filter" if inputs["name"].length > 200
      %w[time_from time_to].each do |key|
        value = inputs[key]
        raise ActionController::BadRequest, "Invalid time filter" if value.present? && !TIME_FORMAT.match?(value)
      end
      %w[amount_min amount_max].each do |key|
        value = inputs[key]
        raise ActionController::BadRequest, "Invalid amount filter" if value.present? && !AMOUNT_FORMAT.match?(value)
      end
      if inputs["time_from"].present? && inputs["time_to"].present? &&
          inputs["time_from"] > inputs["time_to"]
        raise ActionController::BadRequest, "Time range must be ascending"
      end
      if inputs["amount_min"].present? && inputs["amount_max"].present? &&
          BigDecimal(inputs["amount_min"]) > BigDecimal(inputs["amount_max"])
        raise ActionController::BadRequest, "Amount range must be ascending"
      end
      new(**inputs.transform_keys(&:to_sym))
    end

    def initialize(name:, time_from:, time_to:, amount_min:, amount_max:)
      @name, @time_from, @time_to = name, time_from, time_to
      @amount_min, @amount_max = amount_min, amount_max
    end

    def active? = query_params.any?

    def query_params
      {name: name, time_from: time_from, time_to: time_to,
       amount_min: amount_min, amount_max: amount_max}.reject { |_, v| v.blank? }
    end

    def apply(scope)
      if name.present?
        escaped = ActiveRecord::Base.sanitize_sql_like(name)
        scope = scope.where("finance_line_items.description ILIKE ?", "%#{escaped}%")
      end
      scope = scope.where("finance_line_items.occurred_time >= ?", time_from) if time_from.present?
      scope = scope.where("finance_line_items.occurred_time <= ?", time_to) if time_to.present?
      scope = scope.where("finance_line_items.amount >= ?", BigDecimal(amount_min)) if amount_min.present?
      scope = scope.where("finance_line_items.amount <= ?", BigDecimal(amount_max)) if amount_max.present?
      scope
    end
  end
end
