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
    assert_select ".line-item-table-scroll", count: 1
    assert_select "table.data-table.line-item-table", count: 1
    assert_select "table.line-item-table caption.line-item-table-caption", text: /Danh sách khoản chi/
    assert_select "table.line-item-table thead th", count: 6
    assert_select "table.line-item-table tbody tr", count: 25
    assert_select "tr#finance_line_item_#{@transaction.line_items.first.id}", count: 1
    assert_select "table.line-item-table tbody td.line-cell", count: 150
    assert_select ".page-heading + .line-items-date-context time[datetime='2026-10-30']", text: "30/10/2026", count: 1
    assert_select "table.line-item-table th", text: /Ngày giao dịch/, count: 0
    assert_select "table.line-item-table td.line-cell-date", count: 0
    assert_select "td.line-cell-time[data-label='Giờ']", count: 25
    assert_select "td.line-cell-place[data-label='Địa điểm']", count: 25
    assert_select "td.line-cell-place.is-empty", count: 12
    assert_select "td.line-cell-amount", count: 25
    assert_select ".line-cell-name .inline-tag-pill", count: 2
    assert_select ".line-cell-actions .line-actions a[data-turbo-frame='line_item_modal']", count: 25
    assert_select ".line-cell-actions .line-actions form button", count: 25
    assert_select ".table-pagination", count: 1
  end

  test "EN localized card labels and edit Turbo Stream replace the same table row" do
    item = @transaction.line_items.first
    get finance_transaction_line_items_path(@transaction, locale: "en")
    assert_response :success
    assert_select ".line-items-date-context time[datetime='2026-10-30']", count: 1
    assert_select ".line-items-date-context", text: /Shared transaction date/
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
