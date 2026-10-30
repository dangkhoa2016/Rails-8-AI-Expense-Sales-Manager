# frozen_string_literal: true
require "csv"

module Finance
  class ReportsController < BaseController
    def show
      @month = month_parameter
      period = @month.beginning_of_month..@month.end_of_month
      confirmed = finance_scope.effective_confirmed.where(transaction_date: period)

      @totals = confirmed.group(:kind).sum(:amount)
      # One amount per transaction, assigned to its first associated Tag.
      # Additional Tags never multiply the accounting total.
      @tag_totals = Finance::TagBreakdown.call(
        transactions: confirmed.where(kind: "expense"), item_level: false)
      @transactions_count = confirmed.count
      @recent_transactions = confirmed.includes(:active_document_version).order(transaction_date: :desc, id: :desc).limit(8)
      @draft_count = finance_scope.where(status: "draft").count

      previous = @month.prev_month
      @previous_totals = finance_scope.effective_confirmed
        .where(transaction_date: previous.beginning_of_month..previous.end_of_month)
        .group(:kind).sum(:amount)

      first_month = @month.beginning_of_month - 5.months
      months_data = finance_scope.effective_confirmed
        .where(transaction_date: first_month..@month.end_of_month)
        .group("DATE_TRUNC('month', transaction_date)::date", :kind).sum(:amount)
      @six_months = (0..5).map do |i|
        date = (first_month + i.months).to_date
        { date: date, income: months_data.fetch([date, "income"], BigDecimal("0")),
          expense: months_data.fetch([date, "expense"], BigDecimal("0")) }
      end
      @trend_max = [@six_months.flat_map { |row| [row[:income], row[:expense]] }.max || BigDecimal("0"), BigDecimal("1")].max

      daily = confirmed.group(:transaction_date, :kind).sum(:amount)
      @daily_rows = (@month.beginning_of_month..@month.end_of_month).filter_map do |date|
        income = daily.fetch([date, "income"], BigDecimal("0"))
        expense = daily.fetch([date, "expense"], BigDecimal("0"))
        { date: date, income: income, expense: expense } if income.positive? || expense.positive?
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
      month = month_parameter
      rows = finance_scope.effective_confirmed
        .where(transaction_date: month.beginning_of_month..month.end_of_month)
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
      send_data csv, filename: "finance-confirmed-#{month.strftime('%Y-%m')}.csv",
                type: "text/csv; charset=utf-8", disposition: "attachment"
    end

    private

    def month_parameter
      value = params[:month].presence || Date.current.strftime("%Y-%m")
      raise ActionController::BadRequest, "Invalid month" unless value.to_s.match?(/\A\d{4}-(0[1-9]|1[0-2])\z/)
      Date.strptime(value, "%Y-%m")
    end

    def safe_csv(value)
      text = value.to_s.delete("\r\n")
      text.lstrip.match?(/\A[=+@\-\t]/) ? "'#{text}" : text
    end
  end
end
