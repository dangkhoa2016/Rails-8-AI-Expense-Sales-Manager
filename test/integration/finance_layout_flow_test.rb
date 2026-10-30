require "test_helper"

class FinanceLayoutFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "layout-owner@example.test", password: "ExampleStrong-2026!")
    @workspace = @user.workspaces.create!(name: "Layout Workspace")
    post session_path, params: {email_address: @user.email_address, password: "ExampleStrong-2026!"}
    assert_response :redirect
  end

  test "new entry prioritizes receipt upload and keeps manual fallback available" do
    get new_finance_transaction_path(locale: "vi", kind: "expense")
    assert_response :success
    assert_select "div.intake-layout", count: 1
    assert_select "form[action='#{from_receipt_finance_transactions_path}']", count: 1
    assert_select "input[name='receipt[image]']", count: 1
    assert_select "details.intake-manual", count: 1
    assert_select "input[name='finance_transaction[amount]']", count: 1
    assert_select "input[name*='line_items_attributes']", count: 0
    assert_includes response.body, "Tải ảnh chứng từ thu hoặc chi"
  end

  test "save draft then detail shows compact item preview and expandable audit" do
    post finance_transactions_path, params: {finance_transaction: {
      kind: "expense", transaction_date: "2026-10-30", amount: "87000",
      description: "Test quick expense", category: "food"
    }}
    assert_response :redirect
    tx = @workspace.finance_transactions.order(:id).last
    assert tx.draft?
    6.times do |i|
      tx.line_items.create!(position: i + 1, description: "Item #{i + 1}",
        entry_source: "manual", amount: 1000, occurred_on: Date.new(2026, 10, 30))
    end
    get finance_transaction_path(tx, locale: "en")
    assert_response :success
    assert_select ".detail-hero-amount", text: /87,000/
    assert_select ".detail-item-preview .recent-entry", count: 5
    assert_select "details#documents", count: 1
    assert_select "details.detail-disclosure", minimum: 2
    assert_select "a[href='#{finance_transaction_line_items_path(tx)}']", minimum: 1
    assert_select "form[action='#{confirm_finance_transaction_path(tx)}']", count: 1
    assert_includes response.body, "View all items"
  end

  test "edit preserved as a draft and item editing still uses modal" do
    tx = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", entry_source: "manual", currency_code: "VND",
      created_by_id: @user.id, transaction_date: Date.new(2026,10,30),
      amount: 30000, category: "food", description: "Initial")
    get edit_finance_transaction_path(tx,locale:"vi")
    assert_response :success
    assert_select "fieldset.transaction-tag-picker input[name='transaction_tag_ids[]'][checked]", count: 1
    patch finance_transaction_path(tx), params:{revision_reason: "The amount and transaction day need correction.",finance_transaction:{
      amount: "45000", description: "Updated", category:"food",
      transaction_date:"2026-10-29"
    }}
    assert_response :redirect
    assert_equal BigDecimal("45000"), tx.reload.amount
    get finance_transaction_path(tx)
    assert_response :success
    assert_includes response.body, "Updated"
  end
end
