require "test_helper"
require "csv"

class FinanceMultiTagFilterTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email_address: "multi-tag-owner@example.test", password: "ExamplePass-2026!")
    @workspace = @owner.workspaces.create!(name: "Multi Tag Workspace")
    outsider = User.create!(email_address: "multi-tag-outsider@example.test", password: "ExamplePass-2026!")
    @outside = outsider.workspaces.create!(name: "Outside Tag Workspace")
    @food = @workspace.finance_tags.create!(key: "food", name_en: "Food", name_vi: "Ăn uống")
    @office = @workspace.finance_tags.create!(key: "office", name_en: "Office", name_vi: "Văn phòng")
    @maintenance = @workspace.finance_tags.create!(key: "maint", name_en: "Maintenance", name_vi: "Bảo trì")
    @other = @outside.finance_tags.create!(key: "private", name_en: "Private", name_vi: "Riêng tư")
    post session_path, params: {email_address: @owner.email_address, password: "ExamplePass-2026!"}
    assert_response :redirect
  end

  def transaction(date:, amount:, description:, tags: [], line_tags: [], status: "confirmed", workspace: @workspace)
    actor = User.find(workspace.owner_id)
    tx = workspace.finance_transactions.create!(
      kind: "expense", status: "draft", transaction_date: date, amount: amount,
      description: description, currency_code: "VND", entry_source: "manual",
      created_by_id: actor.id
    )
    tx.tags << tags if tags.any?
    if line_tags.any?
      item = tx.line_items.create!(description: "Item of #{description}",
        amount: amount, position: 0, entry_source: "manual")
      item.tags << line_tags
    end
    Finance::ConfirmTransaction.call(transaction: tx, actor: actor, reviewed: true) if status == "confirmed"
    tx
  end

  test "history OR matching includes transaction and item Tags without duplicates" do
    date = Date.new(2026, 10, 22)
    transaction(date: date, amount: 1000, description: "Direct Tag", tags: [@food, @office])
    transaction(date: date, amount: 2000, description: "Line Tag", line_tags: [@office])
    transaction(date: date, amount: 3000, description: "Both types", tags: [@food], line_tags: [@office, @food])
    transaction(date: date, amount: 4000, description: "Different tag", tags: [@maintenance])
    transaction(date: Date.new(2026, 9, 1), amount: 5000, description: "Wrong date", tags: [@food])
    transaction(date: date, amount: 6000, description: "Unconfirmed", tags: [@food], status: "draft")
    transaction(date: date, amount: 7000, description: "Cross tenant", tags: [@other], workspace: @outside)

    get finance_transactions_path(locale: "vi", preset: "custom", from: "2026-10-18",
      to: "2026-10-31", tag_ids: [@food.id, @office.id], status: "confirmed")
    assert_response :success
    assert_select "input[name='tag_ids[]'][value='#{@food.id}'][checked]", count: 1
    assert_select "input[name='tag_ids[]'][value='#{@office.id}'][checked]", count: 1
    assert_select "details.finance-tags-disclosure[open]", count: 1
    assert_select ".transactions-panel .data-table tbody tr", count: 3
    assert_select ".table-pagination", text: /3 giao dịch/
    assert_select ".kpi-expense .kpi-value", text: /6.000/
  end

  test "reports and CSV share multi-Tag filter and avoid double counting" do
    date = Date.new(2026, 10, 22)
    a = transaction(date: date, amount: 1000, description: "Tagged direct", tags: [@food, @office])
    b = transaction(date: date, amount: 2000, description: "Tagged line", line_tags: [@office])
    c = transaction(date: date, amount: 3000, description: "Tagged both", tags: [@food], line_tags: [@office])
    transaction(date: date, amount: 4000, description: "Other", tags: [@maintenance])
    transaction(date: Date.new(2026, 9, 5), amount: 7000, description: "Out of range", tags: [@food])
    options = {locale: "vi", preset: "custom", from: "2026-10-01", to: "2026-10-31", tag_ids: [@food.id, @office.id]}
    get finance_reports_path(options)
    assert_response :success
    assert_select ".report-kpis .kpi-expense .kpi-value", text: /6.000/
    assert_select ".report-kpis .kpi-drafts .kpi-value", text: "3"
    assert_select ".daily-panel tbody tr", count: 1
    assert_select ".recent-panel .recent-entry", count: 3
    assert_select ".finance-tag-filter-choice input[checked]", count: 2
    assert_select ".report-history-link[href*='tag_ids']", count: 1
    assert_select "a[href*='/finance/reports/export'][href*='tag_ids']", count: 1
    get finance_reports_export_path(options)
    assert_response :success
    rows = CSV.parse(response.body, headers: true)
    assert_equal [a.id, b.id, c.id].sort, rows.map { |row| row.fetch("ID").to_i }.sort
    assert_equal BigDecimal("6000"), rows.sum { |row| BigDecimal(row.fetch("Amount")) }
  end

  test "date, Tag, status, type and search survive history pagination" do
    date = Date.new(2026, 10, 23)
    (1..23).each do |n|
      transaction(date: date, amount: 1000,
        description: "Matching filter #{n}", tags: [@office], status: "draft")
    end
    transaction(date: date, amount: 6000, description: "Wrong tag", tags: [@food], status: "draft")
    options = {locale: "en", preset: "custom", from: "2026-10-01", to: "2026-10-31",
      tag_ids: [@office.id], status: "draft", kind: "expense", q: "Matching"}
    get finance_transactions_path(options)
    assert_response :success
    assert_select ".transactions-panel tbody tr", count: 20
    assert_select ".table-pagination", text: /23 entries/
    assert_select ".pagination-links a[href*='tag_ids'][href*='status=draft'][href*='kind=expense'][href*='q=Matching']", count: 1
    get finance_transactions_path(options.merge(page: 2))
    assert_response :success
    assert_select ".transactions-panel tbody tr", count: 3
    assert_select "input[name='tag_ids[]'][value='#{@office.id}'][checked]", count: 1
  end

  test "comparison period uses same Tag scope while confirmed totals exclude drafts" do
    transaction(date: Date.new(2026, 10, 18), amount: 2000, description: "Current period", tags: [@food])
    transaction(date: Date.new(2026, 9, 20), amount: 5000, description: "Previous period", tags: [@food])
    transaction(date: Date.new(2026, 9, 22), amount: 9000, description: "Other previous Tag", tags: [@maintenance])
    transaction(date: Date.new(2026, 10, 18), amount: 10000, description: "Unconfirmed", tags: [@food], status: "draft")
    get finance_reports_path(preset: "custom", from: "2026-10-01", to: "2026-10-31", tag_ids: [@food.id])
    assert_response :success
    assert_select ".report-kpis .kpi-expense .kpi-value", text: /2.000/
    assert_select ".report-kpis .kpi-expense .kpi-foot", text: /5.000/
  end

  test "archived Tags are selectable and unknown or cross-workspace IDs are rejected" do
    @food.update!(active: false)
    transaction(date: Date.new(2026, 10, 25), amount: 8000, description: "Archived Tag", tags: [@food])
    get finance_reports_path(month: "2026-10", tag_ids: [@food.id], locale: "en")
    assert_response :success
    assert_select ".finance-tag-filter-choice input[checked][value='#{@food.id}']", count: 1
    assert_includes response.body, "Archived"
    get finance_transactions_path(tag_ids: [@other.id])
    assert_response :bad_request
    get finance_reports_path(tag_ids: [@other.id])
    assert_response :bad_request
    get finance_reports_export_path(tag_ids: [@other.id])
    assert_response :bad_request
    get finance_reports_path(tag_ids: ["bad"])
    assert_response :bad_request
    get finance_transactions_path(tag_ids: @food.id)
    assert_response :bad_request
  end
end
