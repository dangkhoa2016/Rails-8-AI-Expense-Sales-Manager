require "test_helper"

class FinanceCorrectionCancelTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "correction-cancel-test@example.test", password: "StrongPassword2026!")
    @ws = @user.workspaces.create!(name: "Cancel Test Workspace")
    Finance::Category.bootstrap!(@ws.id)
    @food = @ws.finance_categories.find_by!(key: "food")
    @office = @ws.finance_categories.find_by!(key: "office")
    @source = @ws.finance_transactions.create!(
      created_by_id: @user.id, kind: "expense", status: "draft",
      currency_code: "VND", entry_source: "manual",
      line_total_managed: true, amount: 3_000, transaction_date: Date.new(2026,10,30),
      description: "Confirmed source transaction"
    )
    @source.line_items.create!(position: 0, description: "Bread", amount: 1000, entry_source: "manual")
    @source.line_items.create!(position: 1, description: "Paper", amount: 2000, entry_source: "manual")
    Finance::TransactionTagging.apply!(transaction: @source, actor: @user,
      tag_ids: [@food.id, @office.id], new_names: "")
    Finance::ConfirmTransaction.call(transaction: @source, actor: @user, reviewed: true)
    post session_path, params: {email_address: @user.email_address, password: "StrongPassword2026!"}
    assert_response :redirect
  end

  test "reasoned cancellation retains original, hides draft and permits a new correction" do
    before = @source.reload.attributes
    post finance_transaction_correction_path(@source),
      params: {reason: "Start a correction because the original transaction needs review."}
    assert_response :redirect
    correction = @source.reload.correction_as_original
    copy = correction.replacement_transaction
    assert_equal 2, copy.line_items.count
    assert_equal @source.tags.pluck(:id).sort, copy.tags.pluck(:id).sort
    assert copy.line_total_managed?
    get edit_finance_transaction_path(copy, locale:"vi")
    assert_response :success
    assert_select "#correction-origin", count: 1
    assert_select "form[action='#{cancel_finance_transaction_correction_path(@source)}']", count: 1
    assert_includes response.body, "Đây là bản sao của giao dịch đã xác nhận"
    get finance_transaction_path(copy, locale:"vi")
    assert_response :success
    assert_select "form[action='#{cancel_finance_transaction_correction_path(@source)}']", count: 1

    assert_no_difference "Finance::Correction.count" do
      post cancel_finance_transaction_correction_path(@source),
        params: {reason: "This adjustment is no longer needed and should be discarded."}
      assert_response :redirect
    end
    assert correction.reload.cancelled?
    assert copy.reload.cancelled?
    assert_nil @source.reload.correction_as_original
    assert_equal before, @source.reload.attributes
    assert_equal "correction_cancelled", @source.revisions.last.action
    assert_equal 1, @source.audit_events.where(event_type:"financial_correction_cancelled").count
    get edit_finance_transaction_path(copy)
    assert_response :not_found
    get finance_transactions_path
    assert_response :success
    assert_select "a[href='#{finance_transaction_path(copy)}']", count: 0
    get finance_transaction_path(copy, locale:"vi")
    assert_response :success
    assert_includes response.body, "Bản nháp điều chỉnh đã hủy"

    assert_difference "Finance::Correction.count", 1 do
      post finance_transaction_correction_path(@source),
        params: {reason: "Start a new correction now that the prior draft was cancelled."}
      assert_response :redirect
    end
    assert_equal 2, @source.correction_history.count
    assert_equal before, @source.reload.attributes
  end

  test "workspace boundary prevents unauthorized cancellation" do
    post finance_transaction_correction_path(@source),
      params: {reason: "Correct an error found after reviewing the original invoice."}
    assert_response :redirect
    correction=@source.reload.correction_as_original
    outsider=User.create!(email_address:"cancel-outsider@example.test",password:"StrongPassword2026!")
    outsider.workspaces.create!(name:"Other workspace")
    delete session_path
    post session_path,params:{email_address:outsider.email_address,password:"StrongPassword2026!"}
    post cancel_finance_transaction_correction_path(@source),
      params:{reason:"This workspace is not permitted to cancel another transaction."}
    assert_response :not_found
    assert correction.reload.draft?
  end

  test "comparison highlights modified item and preserves original values" do
    original_amount=@source.reload.amount
    post finance_transaction_correction_path(@source),
      params:{reason:"Receipt item description needs correction after verification."}
    assert_response :redirect
    draft=@source.reload.correction_as_original.replacement_transaction
    get edit_finance_transaction_path(draft,locale:"vi")
    assert_response :success
    assert_select "#correction-origin a[href='#{finance_transaction_path(@source)}']"
    assert_includes response.body, "Chưa có khác biệt"
    item=draft.line_items.order(:position).first
    patch finance_transaction_line_item_path(draft,item),params:{line_item:{
      description:"Corrected bread item",amount:"1500"}}
    assert_response :redirect
    get finance_transaction_path(draft,locale:"vi")
    assert_response :success
    assert_includes response.body, "Corrected bread item"
    assert_includes response.body, "So sánh với giao dịch gốc"
    assert_equal original_amount,@source.reload.amount
    assert_equal "Bread",@source.line_items.order(:position).first.description
    assert_equal BigDecimal("3500"),draft.reload.amount
  end

  test "active Tags are multiple; managed total ignores transaction amount form edits" do
    post finance_transactions_path, params: {finance_transaction:{
      kind:"income",transaction_date:"2026-10-30",amount:"15000",
      description:"Test customer income"
    },transaction_tag_selection:"1",transaction_tag_ids:[@food.id,@office.id],
      transaction_new_tags:"Project Orange"}
    assert_response :redirect
    tx=@ws.finance_transactions.order(:id).last
    assert tx.line_total_managed?
    assert_equal 1, tx.line_items.count
    assert_equal BigDecimal("15000"),tx.amount
    assert_equal 3,tx.tags.count
    get edit_finance_transaction_path(tx,locale:"vi")
    assert_response :success
    assert_select "fieldset.transaction-tag-picker input[name='transaction_tag_ids[]'][checked]",count:3
    assert_select "select[name='finance_transaction[category]']",count:0
    assert_select "input[name='finance_transaction[amount]']",count:0
    patch finance_transaction_path(tx),params:{
      revision_reason:"Update the selected labels after checking the invoice.",
      transaction_tag_selection:"1",transaction_tag_ids:[@office.id],
      finance_transaction:{description:"Edited income",amount:"999999"}}
    assert_response :redirect
    assert_equal ["office"],tx.reload.tags.pluck(:key)
    assert_equal BigDecimal("15000"),tx.amount
    assert_equal BigDecimal("15000"),tx.line_items.sum(:amount)
    assert_equal ["office"],tx.revisions.last.after_state["tags"]
    item=tx.line_items.sole
    patch finance_transaction_line_item_path(tx,item),
      params:{line_item:{description:"Updated line",amount:"17000"}}
    assert_response :redirect
    assert_equal BigDecimal("17000"),tx.reload.amount
    delete finance_transaction_line_item_path(tx,item)
    assert_response :redirect
    assert_equal BigDecimal("0"),tx.reload.amount
    post confirm_finance_transaction_path(tx),params:{human_confirmed:"1"}
    assert_response :redirect
    assert tx.reload.draft?
  end
end
