# frozen_string_literal: true

module Finance
  # Shared transaction-date filtering for the ledger and human-confirmed reports.
  # The same range is used for visible rows, report aggregates and CSV exports.
  class DateRangeFilter
    PRESETS = %w[all this_week previous_week first_two_weeks_this_month last_two_weeks_this_month this_month previous_month last_7_days last_30_days custom].freeze
    REPORT_PRESETS = (PRESETS - ["all"]).freeze
    EARLIEST_DATE = Date.new(1900, 1, 1)
    LATEST_DATE = Date.new(2100, 12, 31)

    attr_reader :preset, :from_date, :to_date

    def self.for_params(params, default:, reports: false, today: Time.find_zone!("Asia/Ho_Chi_Minh").today)
      value = params[:preset].presence
      value = nil unless value.present?
      explicit_dates = params.key?(:from) || params.key?(:to)
      if value.nil? && explicit_dates
        value = "custom"
      elsif value.nil? && params[:month].present?
        value = "legacy_month"
      end
      value ||= default
      permitted = reports ? REPORT_PRESETS : PRESETS
      unless permitted.include?(value) || value == "legacy_month"
        raise ActionController::BadRequest, "Invalid date preset"
      end

      range = case value
      when "all" then nil
      when "this_week" then today.beginning_of_week(:monday)..today.end_of_week(:monday)
      when "previous_week"
        last = today - 7
        last.beginning_of_week(:monday)..last.end_of_week(:monday)
      when "first_two_weeks_this_month" then today.beginning_of_month..(today.beginning_of_month + 13)
      when "last_two_weeks_this_month" then (today.end_of_month - 13)..today.end_of_month
      when "this_month" then today.beginning_of_month..today.end_of_month
      when "previous_month"
        last = today.prev_month
        last.beginning_of_month..last.end_of_month
      when "last_7_days" then (today - 6)..today
      when "last_30_days" then (today - 29)..today
      when "legacy_month"
        month = params[:month].to_s
        raise ActionController::BadRequest, "Invalid month" unless month.match?(/\A\d{4}-(0[1-9]|1[0-2])\z/)
        date = Date.strptime(month, "%Y-%m")
        date.beginning_of_month..date.end_of_month
      when "custom"
        from = strict_date(params[:from])
        to = strict_date(params[:to])
        from..to
      end
      if range
        if reports && (range.end - range.begin).to_i > 3652
          raise ActionController::BadRequest, "Date range exceeds ten years"
        end
        unless range.begin.between?(EARLIEST_DATE, LATEST_DATE) &&
               range.end.between?(EARLIEST_DATE, LATEST_DATE) && range.begin <= range.end
          raise ActionController::BadRequest, "Invalid date range"
        end
      end
      new(preset: value == "legacy_month" ? "custom" : value,
          from_date: range&.begin, to_date: range&.end)
    end

    def initialize(preset:, from_date:, to_date:)
      @preset, @from_date, @to_date = preset, from_date, to_date
    end

    def range
      from_date && to_date ? (from_date..to_date) : nil
    end
    def active? = !!range
    def query_params
      return {preset: "all"} unless active?
      {preset: preset, from: from_date.iso8601, to: to_date.iso8601}
    end

    private_class_method def self.strict_date(input)
      value = input.to_s
      raise ActionController::BadRequest, "Invalid ISO date" unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.iso8601(value)
    rescue Date::Error
      raise ActionController::BadRequest, "Invalid ISO date"
    end
  end
end
