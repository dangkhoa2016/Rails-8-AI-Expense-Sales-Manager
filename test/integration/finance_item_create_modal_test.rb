require "test_helper"

class FinanceItemCreateModalTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "item-create-modal@example.test", password: "ExampleSecure-2026!")
    @workspace = @user.workspaces.create!(name: "Item Create Modal")
    @outsider = User.create!(email_address: "modal-outsider@example.test", password: "ExampleSecure-2026!")
    @outsider.workspaces.create!(name: "Other Workspace")
    @transaction = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @user.id, description: "Draft with item modal",
      transaction_date: Date.new(2026, 10, 30), amount: 100_000
    )
    post session_path, params: { email_address: @user.email_address,
                                 password: "ExampleSecure-2026!" }
    assert_response :redirect
  end

  test "compact toolbar opens new item modal without always-visible form" do
    get finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_select "a[data-turbo-frame='line_item_modal'][href*='/line_items/new']", count: 1
    assert_select "details.item-import-details summary", count: 1
    assert_select "section.panel form[action='#{finance_transaction_line_items_path(@transaction)}'][method='post']", count: 0
    assert_select "section#line_item_list form.line-item-sort-controls", count: 0
    assert_select "aside.line-items-filter-rail form.line-item-filter-controls", count: 1
    assert_select "turbo-frame#line_item_modal", count: 1

    get new_finance_transaction_line_item_path(@transaction, page: 1),
      headers: { "Turbo-Frame" => "line_item_modal" }
    assert_response :success
    assert_select 'turbo-frame#line_item_modal dialog[data-controller="item-modal"]', count: 1
    assert_select 'dialog[data-action*="cancel->item-modal#preventImplicitClose"]', count: 1
    assert_select 'dialog[data-action*="click->item-modal#backdrop"]', count: 0
    assert_select 'button.item-modal-close svg', count: 1
    assert_select 'button.item-modal-cancel[type="button"]', count: 1
    assert_select "input[name='line_item[description]'][required]", count: 1
    assert_select "label[for='line_item_description']", text: "Lý do chi"

    assert_select "input[name='line_item[amount]'][required]", count: 1
    assert_select "input[name='line_item[occurred_on]']", count: 0
    assert_select "div.quick-item-inherited-date", text: /30\/10\/2026/
    assert_select "input[name='line_item[occurred_time]']", count: 1
    assert_select "input[name='line_item[location_text]']", count: 1
    assert_select "input[name='page'][value='1']", count: 1
  end

  test "successful modal create updates row, summary and draft transaction total" do
    assert_difference "Finance::LineItem.count", 1 do
      assert_difference "Finance::AuditEvent.where(event_type: 'finance_line_item_added').count", 1 do
        post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
          params: { page: 1, line_item: {
            description: "Bánh mì ngọt", amount: "30000", quantity: "2", unit_price: "15000", occurred_on: "2026-04-26", occurred_time: "08:12",
            location_text: "Tiệm bánh giả lập ở Đà Nẵng"
          } }
        assert_response :success
      end
    end
    item = @transaction.line_items.sole
    assert_equal BigDecimal("30000"), item.amount
    assert_equal "08:12", item.occurred_time.strftime("%H:%M")
    assert_equal "Tiệm bánh giả lập ở Đà Nẵng", item.location_text
    assert_equal BigDecimal("30000"), @transaction.reload.amount
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action='replace'][target='line_item_list']", count: 1
    assert_select "turbo-stream[action='replace'][target='line_items_summary']", count: 1
    assert_select "turbo-stream[action='replace'][target='line_items_summary'] #line_items_summary .kpi-card", count: 2
    assert_select "turbo-stream[action='update'][target='line_item_modal']", count: 1
    assert_select "turbo-stream[action='update'][target='line_item_feedback']", count: 1
    assert_includes response.body, "Bánh mì ngọt"
    assert_includes response.body, "Tiệm bánh giả lập"
    assert_includes response.body, "30,000"
    assert_select "tr#finance_line_item_#{item.id}", count: 1
  end

  test "invalid modal submission keeps form with errors and writes nothing" do
    assert_no_difference "Finance::AuditEvent.count" do
      assert_no_difference "Finance::LineItem.count" do
        post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
          params: { page: 1, line_item: {description: "", amount: "-4"} }
        assert_response :unprocessable_entity
      end
    end
    assert_select "turbo-stream[action='update'][target='line_item_modal']", count: 1
    assert_select "turbo-stream[action='replace'][target='line_item_list']", count: 0
    assert_select "turbo-stream[action='replace'][target='line_items_summary']", count: 0
    assert_includes response.body, 'role="alert"'
  end

  test "item added when current page full is saved on next page with explicit link" do
    25.times do |i|
      @transaction.line_items.create!(position: i, description: "Existing #{i + 1}",
                                      amount: 100, entry_source: "manual", occurred_on: Date.new(2026, 10, 30))
    end
    get finance_transaction_line_items_path(@transaction, page: 1)
    assert_response :success
    assert_select "tbody tr", count: 25

    post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
      params: {page: 1, line_item: {description: "New page item", amount: "900"}}
    assert_response :success
    assert_equal 26, @transaction.line_items.count
    assert_select "turbo-stream[action='replace'][target='line_item_list']", count: 1
    assert_select "tbody tr", count: 25
    assert_includes response.body, "View the newly added item"
    assert_includes response.body, "page=2"
    assert_includes response.body, "26"

    get finance_transaction_line_items_path(@transaction, page: 2)
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_includes response.body, "New page item"
  end

  test "last page updates in place, multiple workspaces isolated, confirmed cannot create" do
    25.times do |i|
      @transaction.line_items.create!(position: i, description: "Existing #{i + 1}",
                                      amount: 100, entry_source: "manual", occurred_on: Date.new(2026, 10, 30))
    end
    post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
      params: { page: 2, line_item: {description: "Visible on page 2", amount: 1000}}
    assert_response :success
    assert_includes response.body, "Visible on page 2"
    assert_select "tbody tr", count: 1
    assert_not_includes response.body, "View the newly added item"

    Finance::ConfirmTransaction.call(transaction: @transaction, actor: @user, reviewed: true)
    get new_finance_transaction_line_item_path(@transaction),
      headers: { "Turbo-Frame" => "line_item_modal" }
    assert_response :not_found
    assert_no_difference "Finance::LineItem.count" do
      post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
        params: {line_item: {description: "Forbidden", amount: "5"}}
      assert_response :not_found
    end

    delete session_path
    post session_path, params: { email_address: @outsider.email_address,
                                 password: "ExampleSecure-2026!" }
    get new_finance_transaction_line_item_path(@transaction)
    assert_response :not_found
  end
end
