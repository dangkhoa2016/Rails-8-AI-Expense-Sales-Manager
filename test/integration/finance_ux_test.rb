require "test_helper"

class FinanceUxTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email_address: "uxowner@example.test", password: "ExamplePass-2026!")
    @owner_workspace = @owner.workspaces.create!(name: "Owner Workspace")
    @stranger = User.create!(email_address: "stranger@example.test", password: "ExamplePass-2026!")
    @stranger_workspace = @stranger.workspaces.create!(name: "Other Workspace")
    post session_path, params: { email_address: @owner.email_address, password: "ExamplePass-2026!" }
    assert_response :redirect
  end

  test "English and Vietnamese interface language switches persist between pages" do
    get finance_transactions_path(locale: "vi")
    assert_response :success
    assert_select "html[lang=vi]"
    assert_select "h1", text: /Tổng quan giao dịch/
    assert_select "a", text: /Phân tích/
    get finance_reports_path(month: "2026-10")
    assert_response :success
    assert_select "html[lang=vi]"
    assert_select "h1", text: /Tình hình thu chi/
    get guide_path
    assert_response :success
    assert_select "h1", text: /Hiểu quy trình thu chi/
    get finance_transactions_path(locale: "en")
    assert_response :success
    assert_select "html[lang=en]"
    assert_select "h1", text: /Transactions overview/
  end

  test "reports exclude drafts and other workspaces while giving valid verified totals" do
    owner_income = @owner_workspace.finance_transactions.create!(
      kind: "income", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @owner.id, transaction_date: Date.new(2026, 10, 9),
      amount: BigDecimal("123400"), description: "Owner demo income")
    Finance::ConfirmTransaction.call(transaction: owner_income, actor: @owner, reviewed: true)
    owner_expense = @owner_workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @owner.id, transaction_date: Date.new(2026, 10, 10),
      amount: BigDecimal("34000"), category: "office", description: "Owner demo expense")
    Finance::ConfirmTransaction.call(transaction: owner_expense, actor: @owner, reviewed: true)
    @owner_workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @owner.id, transaction_date: Date.new(2026, 10, 10),
      amount: BigDecimal("9900000"), description: "Secret draft")
    @stranger_workspace.finance_transactions.create!(
      kind: "income", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @stranger.id, transaction_date: Date.new(2026, 10, 10),
      amount: BigDecimal("8888888"), description: "Secret other workspace")
    get finance_reports_path(month: "2026-10", locale: "en")
    assert_response :success
    assert_select "h1", text: /Financial performance/
    assert_includes response.body, "123,400"
    assert_includes response.body, "34,000"
    refute_includes response.body, "9,900,000"
    refute_includes response.body, "8,888,888"
    assert_select ".trend-col", count: 6
    assert_select ".category-row", count: 1

    get finance_reports_export_path(month: "2026-10", locale: "vi")
    assert_response :success
    assert_includes response.body, "123400"
    assert_includes response.body, "34000"
    refute_includes response.body, "9900000"
    refute_includes response.body, "8888888"
  end

  test "transaction list filters, search and pagination are tenant scoped" do
    @owner_workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @owner.id, description: "Office demo query", amount: BigDecimal("5000"))
    @owner_workspace.finance_transactions.create!(
      kind: "income", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @owner.id, description: "Service invoice", amount: BigDecimal("1200"))
    @stranger_workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @stranger.id, description: "Office private workspace", amount: BigDecimal("1234"))
    get finance_transactions_path(q: "Office", status: "draft", kind: "expense", locale: "en")
    assert_response :success
    assert_includes response.body, "Office demo query"
    refute_includes response.body, "Service invoice"
    refute_includes response.body, "Office private workspace"
    get finance_transactions_path(q: "Office", page: "99999")
    assert_response :success
  end
end
