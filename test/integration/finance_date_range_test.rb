require "test_helper"
require "csv"

class FinanceDateRangeTest < ActionDispatch::IntegrationTest
  setup do
    @actor = User.create!(email_address: "range-owner@example.test", password: "ExamplePass-2026!")
    @workspace = @actor.workspaces.create!(name: "Date Range Workspace")
    other = User.create!(email_address: "range-outsider@example.test", password: "ExamplePass-2026!")
    @outside = other.workspaces.create!(name: "Other Workspace")
    post session_path, params: {email_address: @actor.email_address, password: "ExamplePass-2026!"}
    assert_response :redirect
  end

  def add_tx(date, amount, kind: "expense", status: "draft", description: "Sample", ws: @workspace)
    actor = User.find(ws.owner_id)
    tx = ws.finance_transactions.create!(kind: kind, status: "draft", amount: amount,
      currency_code: "VND", entry_source: "manual", created_by_id: actor.id,
      transaction_date: date, description: description)
    Finance::ConfirmTransaction.call(transaction: tx, actor: actor, reviewed: true) if status == "confirmed"
    tx
  end

  test "history filters by transaction day and preserves status kind search and pagination" do
    travel_to Time.utc(2026, 10, 31, 3, 0) do
      (1..22).each do |n|
        add_tx(Date.new(2026, 10, 20), 1000, description: "Filtered item #{n}")
      end
      add_tx(Date.new(2026, 10, 10), 9000, description: "Out of window")
      add_tx(Date.new(2026, 10, 20), 2000, kind: "income", description: "Wrong kind")
      add_tx(Date.new(2026, 10, 20), 6000, ws: @outside, description: "Other tenant")
      get finance_transactions_path(preset: "last_two_weeks_this_month", kind: "expense", status: "draft", q: "Filtered", locale: "vi")
      assert_response :success
      assert_select "input[name='from'][value='2026-10-18']"
      assert_select "input[name='to'][value='2026-10-31']"
      assert_select "form[data-controller='date-range'][data-date-range-applied-preset-value='last_two_weeks_this_month'][data-date-range-applied-from-value='2026-10-18'][data-date-range-applied-to-value='2026-10-31']", count: 1
      assert_select ".date-range-pending[hidden]", count: 1
      assert_select ".table-pagination", text: /22 giao dịch/
      assert_select ".data-table tbody tr", count: 20
      refute_includes response.body, "Out of window"
      assert_select ".pagination-links a[href*='preset=last_two_weeks_this_month'][href*='kind=expense'][href*='status=draft'][href*='q=Filtered']", minimum: 1
      get finance_transactions_path(preset: "last_two_weeks_this_month", kind: "expense", status: "draft", q: "Filtered", page: 2)
      assert_response :success
      assert_select ".data-table tbody tr", count: 2
    end
  end

  test "reports use one date range for counts totals daily trend and CSV export" do
    travel_to Time.utc(2026, 10, 31, 3, 0) do
      before = add_tx(Date.new(2026, 10, 10), 11000, status: "confirmed", description: "Outside confirmed")
      inside = add_tx(Date.new(2026, 10, 20), 22000, status: "confirmed", description: "Included expense")
      add_tx(Date.new(2026, 10, 25), 8000, kind: "income", status: "confirmed", description: "Included income")
      add_tx(Date.new(2026, 10, 22), 93000, description: "Excluded draft")
      add_tx(Date.new(2026, 10, 21), 700000, status: "confirmed", ws: @outside, description: "Other tenant")
      params = {preset: "last_two_weeks_this_month", locale: "vi"}
      get finance_reports_path(params)
      assert_response :success
      assert_select ".report-filter input[name='from'][value='2026-10-18']"
      assert_select ".report-filter input[name='to'][value='2026-10-31']"
      assert_select "form[data-controller='date-range'][data-date-range-applied-preset-value='last_two_weeks_this_month'][data-date-range-applied-from-value='2026-10-18'][data-date-range-applied-to-value='2026-10-31']", count: 1
      assert_select ".date-range-pending[hidden]", count: 1
      assert_select ".report-kpis .kpi-income .kpi-value", text: /8.000/
      assert_select ".report-kpis .kpi-expense .kpi-value", text: /22.000/
      assert_select ".report-kpis .kpi-drafts", text: /1/
      assert_select ".trend-col", count: 1
      assert_select ".daily-panel tbody tr", count: 2
      assert_select ".recent-panel a[href='#{finance_transaction_path(inside)}']", count: 1
      refute_includes response.body, "Outside confirmed"
      refute_includes response.body, "Other tenant"
      assert_select ".heading-actions a[href*='/finance/reports/export'][href*='preset=last_two_weeks_this_month'][href*='from=2026-10-18'][href*='to=2026-10-31']", count: 1
      get finance_reports_export_path(params)
      assert_response :success
      rows = CSV.parse(response.body, headers: true)
      assert_equal 2, rows.length
      assert_equal [BigDecimal("8000"), BigDecimal("22000")],
        rows.map { |r| BigDecimal(r.fetch("Amount")) }.sort
      assert_match(/2026-10-18-to-2026-10-31/, response.headers["Content-Disposition"])
      assert_not rows.any? { |r| r.fetch("ID").to_i == before.id }
    end
  end

  test "custom dates cross month boundaries and legacy month URLs still work" do
    add_tx(Date.new(2026, 9, 30), 45000, status: "confirmed", description: "September close")
    add_tx(Date.new(2026, 10, 1), 55000, status: "confirmed", description: "October open")
    add_tx(Date.new(2026, 10, 2), 95000, status: "confirmed", description: "Outside")
    get finance_reports_path(from: "2026-09-30", to: "2026-10-01", locale: "en")
    assert_response :success
    assert_select "select[name='preset'] option[selected][value='custom']", count: 1
    assert_select ".trend-col", count: 2
    assert_select ".daily-panel tbody tr", count: 2
    get finance_reports_export_path(from: "2026-09-30", to: "2026-10-01")
    assert_equal 2, CSV.parse(response.body, headers: true).length
    get finance_reports_path(month: "2026-10")
    assert_response :success
    assert_select ".daily-panel tbody tr", count: 2
  end

  test "history defaults to all while report defaults to current month" do
    travel_to Time.utc(2026, 10, 31, 3, 0) do
      get finance_transactions_path(locale: "en")
      assert_response :success
      assert_select "select[name='preset'] option[selected][value='all']"
      get finance_reports_path(locale: "vi")
      assert_response :success
      assert_select "select[name='preset'] option[selected][value='this_month']"
      assert_select "input[name='from'][value='2026-10-01']"
      assert_select "input[name='to'][value='2026-10-31']"
      assert_select "select[name='preset'] option[value='all']", count: 0
      assert_includes response.body, "2 tuần cuối tháng này"
    end
  end
end
