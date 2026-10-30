require "test_helper"

class FinanceContextTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "context-owner@example.test", password: "ExamplePassword-2026!")
    @workspace = @user.workspaces.create!(name: "Context Test Workspace")
    @other = User.create!(email_address: "context-other@example.test", password: "ExamplePassword-2026!")
    @other_workspace = @other.workspaces.create!(name: "Other Workspace")
    post session_path, params: { email_address: @user.email_address, password: "ExamplePassword-2026!" }
    assert_response :redirect
  end

  test "optional time and place can accompany a manually entered expense" do
    assert_difference "Finance::TransactionContext.count", 1 do
      post finance_transactions_path, params: { finance_transaction: {
        kind: "expense", transaction_date: "2026-04-26", amount: "30000", description: "Sweet bread for breakfast",
        context_attributes: {
          purchase_details: "Bought sweet bread",
          occurred_time: "08:12", location_text: "Sample bakery near a police station in Da Nang",
          source: "demo_seed", recorded_by_id: @other.id
        }
      } }
      assert_response :redirect
    end
    tx = @workspace.finance_transactions.order(:id).last
    assert tx.draft?
    assert_equal "Bought sweet bread", tx.context.purchase_details
    assert_equal "08:12", tx.context.occurred_time.strftime("%H:%M")
    assert_equal "Sample bakery near a police station in Da Nang", tx.context.location_text
    assert_equal "manual", tx.context.source
    assert_equal @user.id, tx.context.recorded_by_id

    get finance_transaction_path(tx, locale: "vi")
    assert_response :success
    assert_includes response.body, "08:12"
    assert_includes response.body, "Da Nang"
    assert_includes response.body, "Chi tiết mua sắm và thanh toán"

    patch finance_transaction_path(tx), params: { revision_reason: "Correct the time and place on the draft.", finance_transaction: {
      context_attributes: { purchase_details: "Bread, for breakfast", occurred_time: "08:17",
                            location_text: "Another demo location" }
    } }
    assert_response :redirect
    assert_equal "08:17", tx.context.reload.occurred_time.strftime("%H:%M")
    post confirm_finance_transaction_path(tx), params: { human_confirmed: "1" }
    assert_response :redirect
    assert tx.reload.confirmed?

    assert_raises(ActiveRecord::RecordInvalid) do
      tx.context.update!(purchase_details: "Changed after confirmation")
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Finance::TransactionContext.transaction(requires_new: true) do
        Finance::TransactionContext.connection.execute(
          "UPDATE finance_transaction_contexts SET location_text = 'tampered' WHERE id = #{tx.context.id}"
        )
      end
    end
    assert_equal "Bread, for breakfast", tx.context.reload.purchase_details
    assert_equal BigDecimal("30000"), tx.reload.amount
  end

  test "time and location are optional even when a transaction is confirmed" do
    post finance_transactions_path, params: { finance_transaction: {
      kind: "income", transaction_date: "2026-10-26", amount: "60000",
      description: "Walk-in sale", context_attributes: { purchase_details: "Daily sale" }
    } }
    assert_response :redirect
    tx = @workspace.finance_transactions.order(:id).last
    assert_nil tx.context&.occurred_time
    assert_nil tx.context&.location_text
    post confirm_finance_transaction_path(tx), params: { human_confirmed: "1" }
    assert_response :redirect
    assert tx.reload.confirmed?

    post finance_transactions_path, params: { finance_transaction: {
      kind: "expense", transaction_date: "2026-10-27", amount: "15000",
      description: "Small purchase", context_attributes: {
        purchase_details: "", occurred_time: "", location_text: ""
      }
    } }
    assert_response :redirect
    blank_tx = @workspace.finance_transactions.order(:id).last
    assert_nil blank_tx.context
  end

  test "confirmed legacy transaction accepts one attributed context without changing its ledger" do
    tx = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @user.id, transaction_date: Date.new(2026, 9, 26),
      description: "Sample office supplies", amount: 1_170_000)
    Finance::ConfirmTransaction.call(transaction: tx, actor: @user, reviewed: true)
    before = tx.attributes
    context = tx.create_context!(
      recorded_by: @user, source: "demo_seed",
      purchase_details: "Sample: purchased A4 paper, pens and document folders",
      occurred_time: "09:25", location_text: "Fictional office supply counter, Da Nang")
    assert_equal before, tx.reload.attributes
    assert_equal "09:25", context.occurred_time.strftime("%H:%M")
    assert_raises(ActiveRecord::RecordNotUnique) do
      tx.create_context!(recorded_by: @user, source: "demo_seed", purchase_details: "Duplicate")
    end
    delete session_path
    post session_path, params: { email_address: @other.email_address, password: "ExamplePassword-2026!" }
    get finance_transaction_path(tx)
    assert_response :not_found
  end

  test "csv includes optional details but only confirmed user workspace rows" do
    tx = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @user.id, transaction_date: Date.new(2026, 10, 10),
      description: "Demo example", amount: 30_000)
    tx.create_context!(recorded_by: @user, purchase_details: "=SUM(A1:A2)", occurred_time: "08:12",
                       location_text: "Demo place")
    Finance::ConfirmTransaction.call(transaction: tx, actor: @user, reviewed: true)
    draft = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @user.id, transaction_date: Date.new(2026, 10, 11),
      description: "Draft secret", amount: 900_000)
    get finance_reports_export_path(month: "2026-10")
    assert_response :success
    assert_includes response.body, "PurchaseDetails,TransactionTime,Location"
    assert_includes response.body, "'=SUM(A1:A2)"
    assert_includes response.body, "08:12"
    assert_includes response.body, "Demo place"
    refute_includes response.body, "Draft secret"
  end
end
