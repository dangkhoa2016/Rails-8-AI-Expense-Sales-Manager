require "test_helper"

class FinanceLineItemsResponsiveTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "responsive-items@example.test", password: "ExampleSecure-2026!")
    @workspace = @user.workspaces.create!(name: "Responsive items")
    @transaction = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @user.id, description: "Responsive example",
      transaction_date: Date.new(2026, 10, 30), amount: 200_000
    )
    Finance::Tag.bootstrap!(@workspace.id)
    @food = @workspace.finance_tags.find_by!(key: "food")
    @office = @workspace.finance_tags.find_by!(key: "office")
    25.times do |i|
      item = @transaction.line_items.create!(
        position: i, description: "Item #{i + 1} — long purchase label",
        amount: 1000 + i, entry_source: "manual",
        occurred_on: Date.new(2026, 10, 29),
        occurred_time: (i.even? ? "08:12" : nil),
        location_text: (i.even? ? "A very long location with Vietnamese accents Đà Nẵng" : nil)
      )
      # Simulate grandfathered legacy items with no independently recorded date.
      item.update_columns(occurred_on: nil) if i.odd?
      if i == 0
        item.line_item_tags.create!(tag: @food)
        item.line_item_tags.create!(tag: @office)
      end
    end
    post session_path, params: {
      email_address: @user.email_address,
      password: "ExampleSecure-2026!"
    }
    assert_response :redirect
  end

  test "VI responsive item list keeps row identity, multiple tags, concise labels and full buttons" do
    get finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_select ".line-items-workbench", count: 1
    assert_select ".line-items-filter-rail form.line-item-filter-controls", count: 1
    assert_select ".line-items-primary > section#line_item_list", count: 1
    assert_select ".line-items-context-rail #line_items_summary", count: 1
    assert_select ".line-items-context-rail .item-list-actions", count: 1
    assert_select "section#line_item_list .line-item-filter-controls", count: 0
    assert_select ".line-item-table-scroll", count: 1
    assert_select "table.data-table.line-item-table", count: 1
    assert_select "table.line-item-table caption.line-item-table-caption", text: /Danh sách khoản chi/
    assert_select "table.line-item-table thead th", count: 6
    assert_select ".line-items-side-stack", count: 1
    assert_select ".line-items-side-stack > aside.line-items-filter-rail", count: 1
    assert_select ".line-items-side-stack > aside.line-items-context-rail", count: 1
    assert_select "details.line-item-filter-disclosure[open]", count: 1
    assert_select "table.line-item-table th a.line-item-sort-link > span:first-child", text: "Thời gian", count: 1
    assert_select "table.line-item-table th a.line-item-sort-link > span:first-child", text: "Địa điểm", count: 1
    assert_select "table.line-item-table th a.line-item-sort-link > span:first-child", text: /tùy chọn/, count: 0
    assert_select "table.line-item-table tbody tr", count: 25
    assert_select "tr#finance_line_item_#{@transaction.line_items.first.id}", count: 1
    assert_select "table.line-item-table tbody td.line-cell", count: 150
    assert_select ".line-items-context-rail .line-items-date-context time[datetime='2026-10-30']", text: "30/10/2026", count: 1
    assert_select "table.line-item-table th", text: /Ngày giao dịch/, count: 0
    assert_select "table.line-item-table td.line-cell-date", count: 0
    assert_select "td.line-cell-time[data-label='Giờ']", count: 25
    assert_select "td.line-cell-place[data-label='Địa điểm']", count: 25
    assert_select "td.line-cell-place.is-empty", count: 12
    assert_select "td.line-cell-amount", count: 25
    assert_select ".line-cell-name .inline-tag-pill", count: 2
    assert_select ".line-cell-actions .line-actions a[data-turbo-frame='line_item_modal']", count: 25
    assert_select ".line-cell-actions .line-actions form button", count: 25
    assert_select ".line-cell-actions .line-actions form button.btn-line-item-delete", count: 25
    assert_select ".line-cell-actions .line-actions form button.btn-minimal", count: 0
    assert_select ".table-pagination", count: 1
  end

  test "balanced line items show one total KPI without duplicated amount and no reconciliation notice" do
    total = @transaction.line_items.sum(:amount)
    @transaction.update!(amount: total)

    get finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_select "#line_items_summary .kpi-card", count: 2
    assert_select "#line_items_summary .kpi-label", text: /Chênh lệch/, count: 0
    assert_select "#line_items_summary .line-items-allocation-note", count: 0
    assert_select "#line_items_summary .kpi-card:first-child .kpi-value", text: "25", count: 1
    assert_select "#line_items_summary .kpi-card:nth-child(2) .kpi-value", text: /25[,.]300/, count: 1
    assert_select "#line_items_summary .kpi-label", text: "Tổng các dòng chi tiết", count: 0

    get finance_transaction_path(@transaction, locale: "vi")
    assert_response :success
    assert_select ".detail-hero-meta > div", count: 3
    assert_select ".detail-hero-meta", text: /Chênh lệch/, count: 0
    assert_select ".detail-item-preview .line-items-allocation-note", count: 0
    assert_select ".detail-primary .line-items-allocation-note", count: 0
    assert_equal total, @transaction.reload.amount
  end

  test "legacy itemized adjustment remains visible only as contextual notice" do
    total = @transaction.line_items.sum(:amount)
    expected = @transaction.amount - total
    assert expected.positive?

    get finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_select "#line_items_summary .kpi-card", count: 3
    assert_select "#line_items_summary .line-items-allocation-note[role='note']", count: 1
    assert_select "#line_items_summary .line-items-allocation-note", text: /Số tiền ngoài danh sách khoản chi tiết/

    get finance_transaction_path(@transaction, locale: "vi")
    assert_response :success
    assert_select ".detail-hero-meta > div", count: 3
    assert_select ".detail-primary .line-items-allocation-note[role='note']", count: 1

    get finance_transaction_line_items_path(@transaction, locale: "en")
    assert_response :success
    assert_select "#line_items_summary .kpi-card", count: 3
    assert_select "#line_items_summary .line-items-allocation-note", text: /Amount outside itemized list/
    assert_equal BigDecimal("200000"), @transaction.reload.amount
  end

  test "transactions without line items do not display misleading adjustment notices" do
    empty_transaction = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND",
      entry_source: "manual", created_by_id: @user.id,
      transaction_date: Date.new(2026, 10, 31),
      amount: 80_000, description: "Legacy transaction without item lines"
    )

    get finance_transaction_line_items_path(empty_transaction, locale: "vi")
    assert_response :success
    assert_select "#line_items_summary .kpi-card", count: 2
    assert_select "#line_items_summary .line-items-allocation-note", count: 0

    get finance_transaction_path(empty_transaction, locale: "vi")
    assert_response :success
    assert_select ".detail-hero-meta > div", count: 3
    assert_select ".detail-primary .line-items-allocation-note", count: 0
  end

  test "draft items expose both visible edit and delete controls" do
    get finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_select "#line_item_list .line-cell-actions .line-actions a[data-turbo-frame='line_item_modal']", count: 25
    assert_select "#line_item_list .line-cell-actions .line-actions form[action][method='post'] button", count: 25
    assert_select "#line_item_list .line-cell-actions .line-actions form button.btn-line-item-delete", count: 25
    assert_select "#line_item_list .line-item-confirmed-action-hint", count: 0
    assert_select "#line_items_summary .kpi-card", count: 3
  end

  test "confirmed items show edit-via-correction but never destructive delete" do
    Finance::ConfirmTransaction.call(transaction: @transaction, actor: @user, reviewed: true)
    assert @transaction.reload.confirmed?
    original_amounts = @transaction.line_items.order(:position).pluck(:id, :amount)

    get finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_select "#line_item_list .line-item-confirmed-action-hint", text: /không thể xóa trực tiếp/
    assert_select "#line_item_list .line-cell-actions .line-actions a[data-turbo-frame='line_item_modal']", count: 25
    assert_select "#line_item_list .line-cell-actions .line-actions form button", count: 0

    delete finance_transaction_line_item_path(@transaction, @transaction.line_items.first)
    assert_response :not_found
    assert_equal original_amounts, @transaction.line_items.order(:position).pluck(:id, :amount)
  end

  test "EN localized card labels and edit Turbo Stream replace the same table row" do
    item = @transaction.line_items.first
    get finance_transaction_line_items_path(@transaction, locale: "en")
    assert_response :success
    assert_select ".line-items-date-context time[datetime='2026-10-30']", count: 1
    assert_select ".line-items-date-context", text: /Shared transaction date/
    assert_select "#line_items_summary .kpi-card", count: 3
    assert_select "table.line-item-table th a.line-item-sort-link > span:first-child", text: "Time", count: 1
    assert_select "table.line-item-table th a.line-item-sort-link > span:first-child", text: "Location", count: 1
    assert_select "table.line-item-table td.line-cell-date", count: 0
    assert_select "td.line-cell-time[data-label='Time']", count: 25
    assert_select "td.line-cell-place[data-label='Location']", count: 25
    assert_select ".line-cell-name .inline-tag-pill", text: "Food & drinks"

    patch finance_transaction_line_item_path(@transaction, item, locale: "en"),
      as: :turbo_stream, params: {
        line_item: { description: "Updated label for a narrow screen", amount: "12500", tag_selection: "1",
                     tag_ids: [@food.id.to_s, @office.id.to_s] }
      }
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='finance_line_item_#{item.id}']", count: 1
    assert_select "tr#finance_line_item_#{item.id} .line-cell-amount", text: /12,500/
    assert_select "tr#finance_line_item_#{item.id} .line-cell-name", text: /Updated label/
    assert_select "tr#finance_line_item_#{item.id} .line-cell-actions .line-actions a", count: 1
    assert_select "turbo-stream[action='replace'][target='line_items_summary']", count: 1
    assert_select "turbo-stream[action='update'][target='line_item_modal']", count: 1
    assert_equal "Updated label for a narrow screen", item.reload.description
  end

  test "pagination stays capped at 25 and create Stream re-renders responsive list" do
    post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
      params: { page: 1, line_item: {
        description: "Item 26 on page two", amount: "3000", tag_selection: "1",
        tag_ids: [@food.id.to_s]
      } }
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='line_item_list']", count: 1
    assert_select "section#line_item_list table.line-item-table", count: 1
    assert_select "section#line_item_list tbody tr", count: 25
    assert_includes response.body, "page=2"
    get finance_transaction_line_items_path(@transaction, page: 2, locale: "vi")
    assert_response :success
    assert_select "table.line-item-table tbody tr", count: 1
    assert_select ".line-cell-name", text: /Item 26/
  end
end
