require "test_helper"
require "csv"

class FinanceCorrectionFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email_address: "correction-owner@example.test", password: "SecurePassword-2026!")
    @workspace = @owner.workspaces.create!(name: "Correction Workspace")
    @other = User.create!(email_address: "correction-stranger@example.test", password: "SecurePassword-2026!")
    @other.workspaces.create!(name: "Other Private Workspace")
    @original = @workspace.finance_transactions.create!(
      created_by_id: @owner.id, kind: "expense", status: "draft",
      currency_code: "VND", entry_source: "manual",
      transaction_date: Date.new(2026, 10, 26), description: "Original purchase", amount: 100_000
    )
    3.times do |i|
      @original.line_items.create!(
        position: i, description: "Original item #{i+1}",
        amount: 20_000, entry_source: "manual", occurred_on: Date.new(2026, 10, 26)
      )
    end
    @original.create_context!(
      recorded_by: @owner, source: "manual",
      purchase_details: "Bought office supplies",
      occurred_time: "08:12", location_text: "Example location in Da Nang"
    )
    Finance::ConfirmTransaction.call(transaction: @original, actor: @owner, reviewed: true)
    post session_path, params: {email_address: @owner.email_address, password: "SecurePassword-2026!"}
    assert_response :redirect
  end

  test "creating and confirming correction replaces effective totals without changing original ledger" do
    prior = @original.attributes
    get edit_finance_transaction_line_item_path(@original, @original.line_items.first, locale: "vi")
    assert_response :success
    assert_select 'turbo-frame[id="line_item_modal"]'
    assert_includes response.body, "Lý do điều chỉnh"

    assert_difference "Finance::Transaction.count", 1 do
      post finance_transaction_correction_path(@original),
        params: {reason: "Incorrect amount on original receipt; please correct."}
      assert_response :redirect
    end
    correction = Finance::Correction.find_by!(original_transaction_id: @original.id)
    replacement = correction.replacement_transaction
    assert replacement.draft?
    assert_equal @original.workspace_id, replacement.workspace_id
    assert_equal 3, replacement.line_items.count
    assert_equal "08:12", replacement.context.occurred_time.strftime("%H:%M")
    assert_equal "Example location in Da Nang", replacement.context.location_text
    assert_equal prior, @original.reload.attributes

    get finance_reports_path(month: "2026-10")
    assert_response :success
    assert_includes response.body, "100.000" # Vietnamese locale saved

    patch finance_transaction_path(replacement), params: {revision_reason: "Correct amount, date and details after review.",finance_transaction: {
      amount: "120000", transaction_date: "2026-10-27",
      description: "Corrected office purchase"
    }}
    assert_response :redirect
    item = replacement.line_items.order(:position).first
    patch finance_transaction_line_item_path(replacement, item), params: {
      line_item: {description: "Corrected line item", amount: "40000"}
    }
    assert_response :redirect
    assert_equal "Original item 1", @original.line_items.order(:position).first.description
    assert_equal BigDecimal("20000"), @original.line_items.order(:position).first.amount

    post confirm_finance_transaction_path(replacement), params: {human_confirmed: "1"}
    assert_response :redirect
    assert correction.reload.confirmed?
    assert replacement.reload.confirmed?
    assert_equal prior, @original.reload.attributes
    assert_equal BigDecimal("100000"), @original.amount

    effective = Finance::Transaction.for_workspace(@workspace.id).effective_confirmed
    assert_equal [replacement.id], effective.pluck(:id)
    assert_equal BigDecimal("80000"), effective.sum(:amount)
    assert_equal 1, @workspace.finance_transactions.confirmed.count - 1

    get finance_reports_path(month: "2026-10", locale: "en")
    assert_response :success
    assert_includes response.body, "80,000"
    assert_not_includes response.body, "100,000"
    get finance_reports_export_path(month: "2026-10")
    parsed = CSV.parse(response.body, headers: true)
    assert_equal 1, parsed.length
    assert_equal replacement.id.to_s, parsed[0]["ID"]
    assert_equal "80000.0", parsed[0]["Amount"]

    get finance_transaction_path(@original)
    assert_response :success
    assert_includes response.body, "This record has been superseded"
    assert_includes response.body, replacement.id.to_s
    get finance_transaction_path(replacement)
    assert_response :success
    assert_includes response.body, "Original transaction"

    assert_equal 1, Finance::AuditEvent.where(transaction_id: @original.id,
      event_type: "financial_correction_superseded").count
    assert_raises(ActiveRecord::RecordInvalid) { @original.update!(amount: 9) }
    assert_raises(ActiveRecord::RecordInvalid) { replacement.update!(amount: 9) }
  end

  test "correction prevents duplicates and does not become effective while draft" do
    post finance_transaction_correction_path(@original),
      params: {reason: "User needs to correct a purchase line item."}
    assert_response :redirect
    correction = @original.reload.correction_as_original
    assert correction.draft?

    assert_no_difference "Finance::Transaction.count" do
      post finance_transaction_correction_path(@original),
        params: {reason: "Attempt to create another correction."}
      assert_response :redirect
    end
    assert_equal [@original.id], Finance::Transaction.for_workspace(@workspace.id)
      .effective_confirmed.pluck(:id)
    assert_equal BigDecimal("100000"), Finance::Transaction.for_workspace(@workspace.id)
      .effective_confirmed.sum(:amount)
    get finance_transaction_path(@original)
    assert_includes response.body, "Correction draft"
    get finance_transaction_path(correction.replacement_transaction)
    assert_includes response.body, "Original transaction"
  end

  test "correction keeps separate tenant authorization" do
    delete session_path
    post session_path, params: {email_address: @other.email_address, password: "SecurePassword-2026!"}
    get edit_finance_transaction_line_item_path(@original, @original.line_items.first)
    assert_response :not_found
    assert_no_difference "Finance::Correction.count" do
      post finance_transaction_correction_path(@original),
        params: {reason: "I should not access another tenant's transaction."}
      assert_response :not_found
    end
  end

  test "100 line item correction clones without altering parent original items" do
    tx = @workspace.finance_transactions.create!(
      created_by_id: @owner.id, kind: "expense", status: "draft",
      currency_code: "VND", entry_source: "manual", transaction_date: Date.new(2026, 10, 27),
      amount: 100_000, description: "Synthetic bulk purchase"
    )
    100.times do |i|
      tx.line_items.create!(position: i, description: "Item #{i+1}", amount: 1_000, entry_source: "manual", occurred_on: Date.new(2026, 10, 26))
    end
    Finance::ConfirmTransaction.call(transaction: tx, actor: @owner, reviewed: true)
    correction = Finance::BeginCorrection.call(original: tx, actor: @owner, reason: "Correct multiple purchased items.")
    assert_equal 100, correction.replacement_transaction.line_items.count
    assert_equal 100, tx.line_items.count
    get finance_transaction_line_items_path(correction.replacement_transaction, page: 4)
    assert_response :success
    assert_select "tbody tr", count: 25
  end
end
