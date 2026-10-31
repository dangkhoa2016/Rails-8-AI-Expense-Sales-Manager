# frozen_string_literal: true
require "csv"

module Finance
  class ReportsController < BaseController
    def show
      @date_range = Finance::DateRangeFilter.for_params(params, default: "this_month", reports: true)
      period = @date_range.range
      confirmed = finance_scope.effective_confirmed.where(transaction_date: period)

      @totals = confirmed.group(:kind).sum(:amount)
      @tag_totals = Finance::TagBreakdown.call(
        transactions: confirmed.where(kind: "expense"), item_level: false)
      @transactions_count = confirmed.count
      @recent_transactions = confirmed.includes(:active_document_version, :tags)
        .order(transaction_date: :desc, id: :desc).limit(8)
      @draft_count = finance_scope.where(status: "draft").count

      # Compare equivalent, adjacent periods (not an entire previous month
      # when the chosen range is a week or arbitrary date span).
      length = (period.end - period.begin).to_i + 1
      previous = (period.begin - length)..(period.begin - 1)
      @previous_totals = finance_scope.effective_confirmed
        .where(transaction_date: previous).group(:kind).sum(:amount)

      monthly = confirmed.group("DATE_TRUNC('month', transaction_date)::date", :kind).sum(:amount)
      start_month = period.begin.beginning_of_month
      end_month = period.end.beginning_of_month
      @trend_months = []
      month = start_month
      while month <= end_month
        @trend_months << {date: month,
          income: monthly.fetch([month, "income"], BigDecimal("0")),
          expense: monthly.fetch([month, "expense"], BigDecimal("0"))}
        month = month.next_month
      end
      @trend_max = [@trend_months.flat_map { |row| [row[:income], row[:expense]] }.max || BigDecimal("0"), BigDecimal("1")].max

      daily = confirmed.group(:transaction_date, :kind).sum(:amount)
      @daily_rows = daily.keys.map(&:first).uniq.sort.filter_map do |date|
        income = daily.fetch([date, "income"], BigDecimal("0"))
        expense = daily.fetch([date, "expense"], BigDecimal("0"))
        {date: date, income: income, expense: expense} if income.positive? || expense.positive?
      end
      @item_tag_totals = Finance::TagBreakdown.call(
        transactions: confirmed.where(kind: "expense"), item_level: true)
      @item_allocation_total = @item_tag_totals.values.sum(BigDecimal("0"))
      @expense_total = @totals.fetch("expense", BigDecimal("0"))
      @income_total = @totals.fetch("income", BigDecimal("0"))
      @item_allocation_difference = @expense_total - @item_allocation_total
      @net = @income_total - @expense_total
    end

    def export
      date_range = Finance::DateRangeFilter.for_params(params, default: "this_month", reports: true)
      rows = finance_scope.effective_confirmed
        .where(transaction_date: date_range.range)
        .includes(:context, :active_document_version, :correction_as_replacement, :tags)
        .order(:transaction_date, :id)
      csv = CSV.generate(headers: true, encoding: "UTF-8") do |sheet|
        sheet << %w[ID Date Kind Amount Currency Tags Description DocumentSHA256 PurchaseDetails TransactionTime Location CorrectsTransactionID]
        rows.each do |tx|
          sheet << [tx.id, tx.transaction_date.iso8601, tx.kind, tx.amount.to_s("F"),
                    tx.currency_code, safe_csv(tx.tags.map(&:key).join(';')), safe_csv(tx.description),
                    tx.active_document_version&.sha256,
                    safe_csv(tx.context&.purchase_details),
                    tx.context&.occurred_time&.strftime("%H:%M"),
                    safe_csv(tx.context&.location_text),
                    tx.correction_as_replacement&.original_transaction_id]
        end
      end
      send_data csv, filename: "finance-confirmed-#{date_range.from_date.iso8601}-to-#{date_range.to_date.iso8601}.csv",
                type: "text/csv; charset=utf-8", disposition: "attachment"
    end

    private

    def safe_csv(value)
      text = value.to_s.delete("\r\n")
      text.lstrip.match?(/\A[=+@\-\t]/) ? "'#{text}" : text
    end
  end
end
