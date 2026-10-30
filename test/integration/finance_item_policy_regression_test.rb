require "test_helper"
require "csv"

class FinanceItemPolicyRegressionTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email_address: "item-policy-regression@example.test", password: "StrongTestPassword2026!")
    @workspace = @owner.workspaces.create!(name: "Item Policy Regression")
    @transaction = @workspace.finance_transactions.create!(
      created_by_id: @owner.id, kind: "expense", status: "draft", currency_code: "VND",
      entry_source: "manual", amount: 99_000,
      transaction_date: Date.new(2026, 10, 29), description: "Synthetic test transaction"
    )
    post session_path, params: {email_address: @owner.email_address, password: "StrongTestPassword2026!"}
    assert_response :redirect
  end

  test "item uses only parent transaction date, even for forged legacy date params" do
    get new_finance_transaction_line_item_path(@transaction, locale: "vi")
    assert_response :success
    assert_select "div.quick-item-inherited-date", text: /29\/10\/2026/
    assert_select "input[name='line_item[occurred_on]']", count: 0

    post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
      params: {line_item: {description: "First item", amount: "1000",
                           occurred_on: "2026-10-28"}}
    assert_response :success
    item = @transaction.line_items.sole
    assert_nil item.occurred_on # Deprecated storage stays NULL for newly entered items
    assert_equal Date.new(2026, 10, 29), item.effective_date
    assert_equal BigDecimal("1000"), @transaction.reload.amount
    assert_select "turbo-stream[action='replace'][target='line_items_summary']", count: 1

    @transaction.update!(transaction_date: Date.new(2026, 10, 30))
    assert_equal Date.new(2026, 10, 30), item.reload.effective_date
    get finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_select "tr#finance_line_item_#{item.id} td.line-cell-date", text: /30\/10\/2026/
  end

  test "time is optional, not auto-guessed, and amount synchronization zeroes the draft after removing the final line" do
    post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
      params: {line_item: {description: "No specific time", amount: "1000", occurred_on: ""}}
    assert_response :success
    item = @transaction.line_items.sole
    assert_nil item.occurred_time
    assert_nil item.occurred_on
    assert_equal BigDecimal("1000"), @transaction.reload.amount

    patch finance_transaction_line_item_path(@transaction, item), as: :turbo_stream,
      params: {line_item: {amount: "2500", occurred_on: "2040-01-02", occurred_time: "09:15"}}
    assert_response :success
    assert_nil item.reload.occurred_on
    assert_equal "09:15", item.occurred_time.strftime("%H:%M")
    assert_equal BigDecimal("2500"), @transaction.reload.amount
    assert_equal 2, @transaction.audit_events.where(event_type: "finance_draft_amount_synced").count

    delete finance_transaction_line_item_path(@transaction, item)
    assert_response :redirect
    assert_equal 0, @transaction.line_items.count
    assert_equal BigDecimal("0"), @transaction.reload.amount
  end

  test "CSV without dates imports and replays once; conflicting legacy item dates roll back" do
    conflicting = "description,amount,occurred_on\nCoffee,1000,2026-10-29\nPaper,2000,2026-10-28\n"
    assert_no_difference "Finance::LineItem.count" do
      post import_finance_transaction_line_items_path(@transaction),
        params: {file: csv_upload(conflicting)}
      assert_response :redirect
    end
    assert_equal BigDecimal("99000"), @transaction.reload.amount
    assert_equal 0, @transaction.line_import_batches.count

    valid = "description,amount,occurred_time\nCoffee,1000,08:12\nPaper,2000,\n"
    post import_finance_transaction_line_items_path(@transaction), params: {file: csv_upload(valid)}
    assert_response :redirect
    assert_equal 2, @transaction.line_items.count
    assert @transaction.line_items.all? { |item| item.occurred_on.nil? && item.effective_date == Date.new(2026, 10, 29) }
    assert_equal BigDecimal("3000"), @transaction.reload.amount
    assert_equal 1, @transaction.line_import_batches.count
    post import_finance_transaction_line_items_path(@transaction), params: {file: csv_upload(valid)}
    assert_response :redirect
    assert_equal 2, @transaction.line_items.count

    matching_legacy = "description,amount,occurred_on\nNotebook,500,2026-10-29\n"
    post import_finance_transaction_line_items_path(@transaction), params: {file: csv_upload(matching_legacy)}
    assert_response :redirect
    assert_nil @transaction.line_items.order(:position).last.occurred_on
    assert_equal BigDecimal("3500"), @transaction.reload.amount
  end

  test "confirmed legacy item date stays stored while display and correction inherit parent date" do
    item = @transaction.line_items.create!(position: 0, description: "Historical item", amount: 1000,
      occurred_on: Date.new(2026, 10, 28), entry_source: "manual")
    Finance::ConfirmTransaction.call(transaction: @transaction, actor: @owner, reviewed: true)
    assert_equal Date.new(2026, 10, 28), item.reload.occurred_on
    assert_equal Date.new(2026, 10, 29), item.effective_date
    correction = Finance::BeginCorrection.call(original: @transaction, actor: @owner,
      reason: "Correct old item while preserving immutable source values.")
    assert_equal Date.new(2026, 10, 28), item.reload.occurred_on
    copy = correction.replacement_transaction.line_items.sole
    assert_equal Date.new(2026, 10, 28), copy.occurred_on
    assert_equal Date.new(2026, 10, 29), copy.effective_date
    assert_equal BigDecimal("99000"), @transaction.reload.amount
  end

  test "tag duplicate key displays friendly translated validation in Vietnamese and English" do
    Finance::Tag.bootstrap!(@workspace.id)
    count = Finance::Tag.count
    {vi: "Mã Tag đã tồn tại", en: "Tag key has already been used"}.each do |locale, expected|
      post finance_tags_path(locale: locale), params: {finance_tag: {
        key: "food", name_vi: "Trùng", name_en: "Duplicate"
      }}
      assert_response :unprocessable_entity
      assert_includes response.body, expected
      assert_not_includes response.body, "Translation missing"
      assert_equal count, Finance::Tag.count
    end
  end

  test "tag management uses canonical URL while legacy category route remains available" do
    get finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_select "a[href='#{finance_tags_path}']", text: /Quản lý Tags/
    get finance_tags_path(locale: "vi")
    assert_response :success
    assert_select "h1", text: /Quản lý Tags/
    assert_select "table.tag-list-table tbody tr", minimum: 1
    assert_select "table.tag-list-table tbody tr td[data-label]", minimum: 5
    get finance_tags_path(locale: "vi")
    assert_response :success
    assert_select "h1", text: /Quản lý Tags/
  end

  private

  def csv_upload(csv)
    file = Tempfile.new(["finance-transaction-date", ".csv"])
    file.write(csv)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/csv", false, original_filename: "items.csv")
  end
end
