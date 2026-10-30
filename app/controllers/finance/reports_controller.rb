# frozen_string_literal: true
require 'csv'
module Finance
  class ReportsController < BaseController
    def show
      @month = month_parameter
      start_date = @month.beginning_of_month
      end_date = @month.end_of_month
      confirmed = finance_scope.confirmed.where(transaction_date: start_date..end_date)
      @totals = confirmed.group(:kind).sum(:amount)
      @categories = confirmed.group(:kind, :category).sum(:amount)
      @transactions_count = confirmed.count
      @max_value = [@totals.values.max || BigDecimal('0'), BigDecimal('1')].max
    end

    def export
      start_date = month_parameter.beginning_of_month
      finish_date = month_parameter.end_of_month
      rows = finance_scope.confirmed.where(transaction_date: start_date..finish_date).order(:transaction_date, :id)
      csv = CSV.generate(headers: true, encoding: 'UTF-8') do |sheet|
        sheet << %w[ID Date Kind Amount Currency Category Description DocumentSHA256]
        rows.find_each do |tx|
          digest = tx.active_document_version&.sha256
          sheet << [tx.id, tx.transaction_date.iso8601, tx.kind,
                    tx.amount.to_s('F'), tx.currency_code, safe_csv(tx.category),
                    safe_csv(tx.description), digest]
        end
      end
      send_data csv, filename: "finance-confirmed-#{month_parameter.strftime('%Y-%m')}.csv",
                type: 'text/csv; charset=utf-8', disposition: 'attachment'
    end

    private
    def month_parameter
      value = params[:month].presence || Date.current.strftime('%Y-%m')
      raise ActionController::BadRequest, 'Invalid month' unless value.match?(/\A\d{4}-(0[1-9]|1[0-2])\z/)
      Date.strptime(value, '%Y-%m')
    end

    def safe_csv(value)
      text = value.to_s.delete("\r\n")
      text.lstrip.match?(/\A[=+@\-\t]/) ? "'#{text}" : text
    end
  end
end
