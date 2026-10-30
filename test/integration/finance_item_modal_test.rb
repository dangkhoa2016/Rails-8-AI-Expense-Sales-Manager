require "test_helper"

class FinanceItemModalTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "modal-owner@example.test", password: "SecurePass-2026!")
    @workspace = @user.workspaces.create!(name: "Modal Workspace")
    @other = User.create!(email_address: "modal-other@example.test", password: "SecurePass-2026!")
    @other.workspaces.create!(name: "Other Workspace")
    @transaction = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND",
      entry_source: "manual", created_by_id: @user.id,
      description: "Editable invoice", transaction_date: Date.new(2026, 10, 28),
      amount: 90_000
    )
    @item = @transaction.line_items.create!(
      position: 0, description: "Sweet bread", amount: 30_000,
      entry_source: "manual", category: "food", occurred_on: Date.new(2026, 10, 28), occurred_time: "08:12"
    )
    @other_item = @transaction.line_items.create!(
      position: 1, description: "Milk", amount: 42_000, entry_source: "manual", occurred_on: Date.new(2026, 10, 28)
    )
    post session_path, params: {email_address: @user.email_address, password: "SecurePass-2026!"}
    assert_response :redirect
  end

  test "item editor opens as a Turbo Frame modal and the index remains paginated" do
    get finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_select 'turbo-frame#line_item_modal'
    assert_select "tr#finance_line_item_#{@item.id}", count: 1
    assert_select "a[data-turbo-frame='line_item_modal'][href$='/line_items/#{@item.id}/edit']", count: 1
    assert_select "tr#finance_line_item_#{@other_item.id}", count: 1

    get edit_finance_transaction_line_item_path(@transaction, @item),
      headers: {"Turbo-Frame" => "line_item_modal"}
    assert_response :success
    assert_select 'turbo-frame#line_item_modal dialog[data-controller="item-modal"]', count: 1
    assert_select "form[action='/finance/transactions/#{@transaction.id}/line_items/#{@item.id}']"
    assert_select "input[name='line_item[amount]']"
    assert_select "input[name='line_item[location_text]']"
    assert_select 'dialog[data-action*="cancel->item-modal#preventImplicitClose"]', count: 1
    assert_select 'dialog[data-action*="click->item-modal#backdrop"]', count: 0
    assert_select 'button.item-modal-close svg[aria-hidden="true"]', count: 1
    assert_select 'button.item-modal-cancel[type="button"][data-action="item-modal#close"]', count: 1
    assert_select 'textarea[name="correction_reason"]', count: 0
  end

  test "successful Turbo update rerenders only edited item and reconciliation then closes modal" do
    assert_difference "Finance::AuditEvent.where(event_type: 'finance_line_item_updated').count", 1 do
      patch finance_transaction_line_item_path(@transaction, @item), as: :turbo_stream,
        params: {line_item: {
          description: "Sweet bread and coffee", amount: "45000", category: "food",
          occurred_on: "2026-10-28", occurred_time: "08:43", location_text: "Demo bakery"
        }}
      assert_response :success
    end
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action='replace'][target='finance_line_item_#{@item.id}']", count: 1
    assert_select "turbo-stream[action='replace'][target='line_items_summary']", count: 1
    assert_select "turbo-stream[action='update'][target='line_item_modal']", count: 1
    assert_select "turbo-stream[action='update'][target='line_item_feedback']", count: 1
    assert_includes response.body, "Sweet bread and coffee"
    assert_includes response.body, "Demo bakery"
    refute_includes response.body, "Milk</strong>"
    assert_equal BigDecimal("45000"), @item.reload.amount
    assert_equal BigDecimal("87000"), @transaction.reload.amount
    assert_equal Date.new(2026,10,28), @item.occurred_on
    assert_equal "08:43", @item.occurred_time.strftime("%H:%M")
    assert_equal "Demo bakery", @item.location_text
    assert_includes response.body, "87,000" # Parent draft is synchronized to line sum.
  end

  test "invalid item modal stays open with errors; DB and audit unchanged" do
    before = @item.reload.attributes
    assert_no_difference "Finance::AuditEvent.count" do
      patch finance_transaction_line_item_path(@transaction, @item), as: :turbo_stream,
        params: {line_item: {description: "", amount: "-2"}}
      assert_response :unprocessable_entity
    end
    assert_select "turbo-stream[action='update'][target='line_item_modal']", count: 1
    assert_select "turbo-stream[action='replace'][target='finance_line_item_#{@item.id}']", count: 0
    assert_includes response.body, "role=\"alert\""
    assert_equal before, @item.reload.attributes
  end

  test "confirmed item modal creates unconfirmed replacement and rerenders locked row without modifying source" do
    Finance::ConfirmTransaction.call(transaction: @transaction, actor: @user, reviewed: true)
    before = @item.reload.attributes
    get finance_transaction_line_items_path(@transaction, locale: "en")
    assert_response :success
    assert_select "a[data-turbo-frame='line_item_modal'][href$='/line_items/#{@item.id}/edit']", count: 1
    get edit_finance_transaction_line_item_path(@transaction, @item),
      headers: {"Turbo-Frame" => "line_item_modal"}
    assert_response :success
    assert_select "textarea[name='correction_reason'][required]", count: 1

    assert_no_difference "Finance::Correction.count" do
      patch finance_transaction_line_item_path(@transaction, @item), as: :turbo_stream,
        params: {line_item: {description: "Adjusted bread", amount: "35000"}, correction_reason: "short"}
      assert_response :unprocessable_entity
    end

    assert_difference "Finance::Correction.count", 1 do
      patch finance_transaction_line_item_path(@transaction, @item), as: :turbo_stream,
        params: {line_item: {
          description: "Adjusted bread", amount: "35000",
          occurred_on: "2026-10-29", occurred_time: "09:15",
          location_text: "Updated demo bakery"
        }, correction_reason: "The price was entered incorrectly on the original receipt."}
      assert_response :success
    end
    assert_select "turbo-stream[action='replace'][target='finance_line_item_#{@item.id}']", count: 1
    assert_select "turbo-stream[action='update'][target='line_item_modal']", count: 1
    assert_select "turbo-stream[action='replace'][target='line_items_summary']", count: 1
    assert_includes response.body, "Open corrected transaction"
    assert_equal before, @item.reload.attributes
    correction = @transaction.reload.correction_as_original
    assert correction.draft?
    replacement = correction.replacement_transaction
    assert replacement.draft?
    copied = replacement.line_items.find_by!(position: @item.position)
    assert_equal "Adjusted bread", copied.description
    assert_equal BigDecimal("35000"), copied.amount
    assert_equal "Updated demo bakery", copied.location_text
    assert_equal [@transaction.id], Finance::Transaction.for_workspace(@workspace.id)
      .effective_confirmed.pluck(:id)
    assert_equal BigDecimal("90000"), Finance::Transaction.for_workspace(@workspace.id)
      .effective_confirmed.sum(:amount)
    assert_equal 1, Finance::AuditEvent.where(transaction_id: replacement.id,
      event_type: "correction_item_draft_edited").count
    assert_no_difference "Finance::Correction.count" do
      patch finance_transaction_line_item_path(@transaction, @item), as: :turbo_stream,
        params: {line_item: {amount: "1"}, correction_reason: "Trying to correct twice now"}
      assert_response :unprocessable_entity
    end
  end

  test "obsolete correction new page is unavailable; tenant isolation remains" do
    get "/finance/transactions/#{@transaction.id}/correction/new"
    assert_response :not_found

    delete session_path
    post session_path, params: {email_address: @other.email_address, password: "SecurePass-2026!"}
    get edit_finance_transaction_line_item_path(@transaction, @item),
      headers: {"Turbo-Frame" => "line_item_modal"}
    assert_response :not_found
    assert_no_difference "Finance::Correction.count" do
      patch finance_transaction_line_item_path(@transaction, @item), as: :turbo_stream,
        params: {line_item: {description: "Illegal"}, correction_reason: "Unauthorized correction attempt"}
      assert_response :not_found
    end
  end
end
