require "test_helper"

class FinanceTransactionRevisionsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email_address: "transaction-revision-owner@example.test", password: "RevisionPass-2026!")
    @workspace = @owner.workspaces.create!(name: "Revision Test Workspace")
    @other = User.create!(email_address: "transaction-revision-stranger@example.test", password: "RevisionPass-2026!")
    @other.workspaces.create!(name: "Other Revision Workspace")
    @draft = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", entry_source: "manual", currency_code: "VND",
      created_by_id: @owner.id, transaction_date: Date.new(2026, 10, 29),
      amount: 30_000, description: "Original test transaction"
    )
    post session_path, params: { email_address: @owner.email_address, password: "RevisionPass-2026!" }
    assert_response :redirect
  end

  test "one unified intake page has radio switching targets, shared proof and manual forms in both languages" do
    %w[expense income].each do |kind|
      get new_finance_transaction_path(kind: kind, locale: "vi")
      assert_response :success
      assert_select "fieldset.finance-kind-radios input[name=intake_kind][type=radio]", count: 2
      assert_select "fieldset.finance-kind-radios input[value=#{kind}][checked]", count: 1
      assert_select "div.intake-layout", count: 1
      assert_select "form[action='#{from_receipt_finance_transactions_path}'] input[name='receipt[kind]'][value=#{kind}]"
      assert_select "form[action='#{finance_transactions_path}'] input[name='finance_transaction[kind]'][value=#{kind}]"
      assert_select "input[data-finance-kind-selector-target='kind']", count: 2
      assert_select "details.intake-manual", count: 1
      assert_select "div.income-intake-layout", count: 0
    end
    get new_finance_transaction_path(locale: "en")
    assert_response :success
    assert_select "h1", text: /Create an income or expense transaction/
  end

  test "editing a draft requires reason and commits before-after snapshots atomically" do
    old_attributes = @draft.attributes
    assert_no_difference "Finance::TransactionRevision.count" do
      patch finance_transaction_path(@draft), params: {finance_transaction: {
        amount: "42000", description: "Edited without reason" }}
      assert_response :unprocessable_entity
    end
    assert_equal old_attributes, @draft.reload.attributes
    assert_no_difference "Finance::TransactionRevision.count" do
      patch finance_transaction_path(@draft), params: {
        revision_reason: "short", finance_transaction: {amount: "48000"} }
      assert_response :unprocessable_entity
    end

    assert_difference "Finance::TransactionRevision.count", 1 do
      patch finance_transaction_path(@draft), params: {
        revision_reason: "Corrected payment amount after manual verification of bank statement.",
        finance_transaction: {transaction_date: "2026-10-30", amount: "45000",
          description: "Corrected transaction", context_attributes: {
          purchase_details: "Verified with document", occurred_time: "08:12",
          location_text: "Sample office" }}}
      assert_response :redirect
    end
    revision = @draft.revisions.sole
    assert_equal 1, revision.version_number
    assert_equal "draft_edited", revision.action
    assert_equal @owner.id, revision.actor_id
    assert_equal @workspace.id, revision.workspace_id
    assert_equal "30000.0", revision.before_state.dig("transaction", "amount")
    assert_equal "45000.0", revision.after_state.dig("transaction", "amount")
    assert_equal "2026-10-29", revision.change_set.dig("transaction", "before", "transaction_date")
    assert_equal "2026-10-30", revision.change_set.dig("transaction", "after", "transaction_date")
    assert_equal "Sample office", revision.after_state.dig("context", "location_text")
    assert_equal BigDecimal("45000"), @draft.reload.amount
    assert_equal 1, @draft.audit_events.where(event_type: "transaction_draft_edited").count

    get finance_transaction_path(@draft, locale: "vi")
    assert_response :success
    assert_select "#revision-history", count: 1
    assert_includes response.body, "Lịch sử phiên bản giao dịch"
    assert_includes response.body, "Corrected payment amount"
    assert_includes response.body, "30000.0"
    assert_includes response.body, "45000.0"
    assert_includes response.body, @owner.email_address

    assert_difference "Finance::TransactionRevision.count", 1 do
      patch finance_transaction_path(@draft), params: {
        revision_reason: "Update the verified purchase description and category.",
        finance_transaction: {description: "Second revision"}}
      assert_response :redirect
    end
    assert_equal [1,2], @draft.revisions.order(:version_number).pluck(:version_number)
    assert_equal 2, @draft.revisions.last.version_number
    assert_equal 2, @draft.audit_events.where(event_type: "transaction_draft_edited").count

    # No meaningful changes means no fake history entry.
    assert_no_difference "Finance::TransactionRevision.count" do
      patch finance_transaction_path(@draft), params: {
        revision_reason: "Rechecked all values and confirmed they remain correct.",
        finance_transaction: {description: "Second revision"}}
      assert_response :redirect
    end
  end

  test "stale edit rejects without changing financial rows or creating revision" do
    assert_no_difference "Finance::TransactionRevision.count" do
      patch finance_transaction_path(@draft), params: {
        revision_reason: "Correction on an outdated version should not apply.",
        finance_transaction: {lock_version: "999", amount: "999999"}}
      assert_response :unprocessable_entity
    end
    assert_equal BigDecimal("30000"), @draft.reload.amount
  end

  test "database prevents revision updates or deletes even through SQL" do
    patch finance_transaction_path(@draft), params: {
      revision_reason: "Original draft entry had the wrong amount.",
      finance_transaction: {amount: "35000"}}
    assert_response :redirect
    revision = @draft.revisions.sole
    assert revision.readonly?
    assert_raises(ActiveRecord::StatementInvalid) do
      Finance::TransactionRevision.transaction(requires_new: true) do
        Finance::TransactionRevision.connection.execute(
          "UPDATE finance_transaction_revisions SET reason='Tampered' WHERE id=#{revision.id}"
        )
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Finance::TransactionRevision.transaction(requires_new: true) do
        Finance::TransactionRevision.connection.execute(
          "DELETE FROM finance_transaction_revisions WHERE id=#{revision.id}"
        )
      end
    end
    assert_equal "Original draft entry had the wrong amount.", revision.reload.reason
  end

  test "confirmed edit uses a reasoned correction chain, not direct ledger mutation" do
    Finance::ConfirmTransaction.call(transaction: @draft, actor: @owner, reviewed: true)
    before = @draft.reload.attributes
    get finance_transaction_path(@draft, locale: "vi")
    assert_response :success
    assert_select "form[action='#{finance_transaction_correction_path(@draft)}'] textarea[name=reason][required]"
    get edit_finance_transaction_path(@draft)
    assert_response :not_found

    assert_difference "Finance::TransactionRevision.count", 1 do
      post finance_transaction_correction_path(@draft), params: {
        reason: "Wrong original date and amount; correcting after checking evidence."}
      assert_response :redirect
    end
    correction = @draft.reload.correction_as_original
    replacement = correction.replacement_transaction
    assert_equal before, @draft.reload.attributes
    assert_equal "correction_requested", @draft.revisions.last.action
    assert_equal replacement.id, @draft.revisions.last.after_state.dig("correction", "replacement_transaction_id")

    patch finance_transaction_path(replacement), params: {
      revision_reason: "The bank payment was entered at the wrong amount and date.",
      finance_transaction: {amount: "52000", transaction_date: "2026-10-30"}}
    assert_response :redirect
    assert_equal "draft_edited", replacement.revisions.sole.action
    assert_equal before, @draft.reload.attributes

    assert_difference "Finance::TransactionRevision.count", 1 do
      post confirm_finance_transaction_path(replacement), params: {human_confirmed: "1"}
      assert_response :redirect
    end
    assert correction.reload.confirmed?
    assert_equal before, @draft.reload.attributes
    assert_equal "correction_confirmed", @draft.revisions.last.action
    assert_equal "52000.0", @draft.revisions.last.after_state.dig("transaction", "amount")
    assert_equal [replacement.id], Finance::Transaction.for_workspace(@workspace.id).effective_confirmed.pluck(:id)
  end

  test "other workspace cannot see history or edit transaction" do
    patch finance_transaction_path(@draft), params: {
      revision_reason: "Verified financial details were inaccurate and need correction.",
      finance_transaction: {amount: "32000"}}
    assert_response :redirect
    delete session_path
    post session_path, params: { email_address: @other.email_address, password: "RevisionPass-2026!" }
    assert_response :redirect
    get finance_transaction_path(@draft)
    assert_response :not_found
    get edit_finance_transaction_path(@draft)
    assert_response :not_found
    patch finance_transaction_path(@draft), params: {revision_reason: "Unauthorized attempt.",
      finance_transaction: {amount: "999"}}
    assert_response :not_found
    assert_equal 1, @draft.revisions.count
  end
end
